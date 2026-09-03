#Requires -Version 7.2

<#
.SYNOPSIS
    Owns one cached al-runner --server child process per repo and bridges it to a
    named pipe so repeated test runs skip BC dependency reloading.

.DESCRIPTION
    A named Mutex (not a pipe connect probe) enforces one manager per repo: a
    connect probe cannot distinguish "no manager" from "a live manager mid-relay,
    pipe momentarily busy", so a losing instance could fall through, spend the
    time starting a redundant al-runner child, and only then fail creating its
    own NamedPipeServerStream (maxInstances 1) - an orphaned child with nothing
    logged. The Mutex is acquired before Start-Child and held for the process's
    lifetime; a losing instance logs one line and exits 0 without ever starting a
    child. The winning instance starts al-runner --server, waits for its ready
    signal, then serves one pipe connection at a time: read one request line,
    recompute the repo fingerprint, restart the child on a fingerprint change, a
    run-count ceiling of MaxRunsPerChild, or a dead child, forward the request to the child's
    stdin, and relay its stdout lines back to the pipe through (and including)
    the summary or error line. Any fatal error in that loop - including a failed
    (re)start or a NamedPipeServerStream failure - is logged, shuts the child
    down (graceful shutdown, then a whole-process-tree Kill so al-runner.exe
    itself is not orphaned under the cmd.exe wrapper), and exits non-zero; no
    exit path here leaves a child running.

.EXAMPLE
    pwsh -File alrunner-server-manager.ps1 -RepoRoot C:\Repo\MyApp
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The symbol-cache root the dependency builder resolves through
# (Get-SymbolCacheRoot -> Get-CheckoutFingerprint -> Get-GitRepoRoot) is
# derived from the current process's git checkout, not from -RepoRoot
# directly — set it as cwd before anything below runs.
Set-Location -LiteralPath $RepoRoot

Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'build-operations.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'alrunner-server.psm1') -Force -DisableNameChecking

$pipeName = Get-ALRunnerPipeName -RepoRoot $RepoRoot
$logPath = Join-Path $RepoRoot '.output' 'logs' 'al-runner-server.log'
$managerLogPath = Join-Path $RepoRoot '.output' 'logs' 'al-runner-server-manager.log'
New-Item -ItemType Directory -Path (Split-Path -Parent $logPath) -Force | Out-Null

# The child's stderr is redirected into $logPath via cmd.exe's own `2>>`, which
# holds that file open with no sharing for the child's whole lifetime, so a
# manager writing its own diagnostics there could hit a sharing violation
# whenever a child is alive. The manager owns a separate file instead
# ($managerLogPath); a genuine write failure there is a real, loud failure
# and is allowed to propagate. Each line is also mirrored to stderr so a
# console-attached run sees it immediately.
function Write-ManagerLog {
    param([Parameter(Mandatory)][string]$Message)
    Add-Content -LiteralPath $managerLogPath -Value $Message
    [Console]::Error.WriteLine($Message)
}

# Single-instance guard: a named Mutex held for this process's lifetime. An
# AbandonedMutexException (the prior manager for this repo died without
# releasing the lock) still counts as acquiring it.
$mutex = [System.Threading.Mutex]::new($false, "Global\$pipeName")
$acquired = $false
try {
    $acquired = $mutex.WaitOne(0)
}
catch [System.Threading.AbandonedMutexException] {
    $acquired = $true
}
if (-not $acquired) {
    Write-ManagerLog '[manager] another manager instance already holds the lock for this repo; exiting.'
    exit 0
}

$script:child = $null
$script:runCount = 0
$script:fingerprint = ''

# WORKAROUND — al-runner --server request drift (v2.10.0.0, incl. main @ 2026-09-03).
# The second and every later runTests request on one server process fails ~380
# extra tests through No. Series platform code (NavDateTime vs NavGuid compare in
# "Library - Inventory".ItemNoSeriesSetup); the first request and a fresh process
# agree. Until upstream fixes it, every request runs on a fresh child, which
# forfeits the warm-cache speedup this manager exists for. To revert once fixed:
# set MaxRunsPerChild back to 50 (the assembly-growth ceiling measured at
# 7.9→10.5s over 20 reloads), restore the "every 50 runs" wording in
# skills/al-build/SKILL.md, and delete this comment.
$script:MaxRunsPerChild = 1

function Start-Child {
    # Dependencies are self-contained (design decision 3): every non-Microsoft,
    # non-bundle dependency is staged from the checkout symbol cache into
    # .output/al-runner-deps before the child starts. A missing package is a
    # hard failure here — the gate must not start a server that only fails
    # later, mid-run, with al-runner's own "Missing" message.
    $depDir = New-ALRunnerDependencyDirectory -RepoRoot $RepoRoot
    foreach ($package in $depDir.Packages) {
        Write-ManagerLog "[deps] $($package.Publisher)/$($package.Name) $($package.Version) <- $($package.Source)"
    }
    Write-ManagerLog "[deps] package-cache: $($depDir.OutputDirectory)"

    # Observed flake (al-runner v2.10.0.0, Windows): a child started seconds
    # after its predecessor's shutdown occasionally closes stdout before the
    # ready line, writing nothing to stderr; the next start succeeds. One
    # logged retry keeps the gate green while the flake stays visible in
    # the manager log for the upstream report.
    $ready = Start-ChildProcess -PackageCache $depDir.OutputDirectory
    if ($null -eq $ready -and $script:child.HasExited) {
        Write-ManagerLog "[manager] retry: al-runner --server exited before its ready line ($(Get-ChildExitDiagnostics)); starting once more"
        $ready = Start-ChildProcess -PackageCache $depDir.OutputDirectory
    }
    if ($ready -notmatch '"ready":true') {
        throw "al-runner --server did not signal ready: '$ready' ($(Get-ChildExitDiagnostics))`n$(Get-ChildLogTail)"
    }
    $script:fingerprint = Get-ALRunnerServerFingerprint -RepoRoot $RepoRoot
    $script:runCount = 0
}

# One start attempt: returns the first stdout line ($null on EOF) and leaves
# the process in $script:child.
function Start-ChildProcess {
    param([Parameter(Mandatory)][string]$PackageCache)
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $env:ComSpec
    $psi.Arguments = "/c al-runner --server --package-cache `"$PackageCache`" 2>>`"$logPath`""
    $psi.WorkingDirectory = $RepoRoot
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $script:child = [Diagnostics.Process]::Start($psi)
    return $script:child.StandardOutput.ReadLine()
}

# Distinguishes "exited early" from "alive but wrong first line" in the
# fatal message; a brief wait lets an exit that already closed stdout land.
function Get-ChildExitDiagnostics {
    if ($null -eq $script:child) { return 'no child process' }
    $null = $script:child.WaitForExit(2000)
    if ($script:child.HasExited) {
        return "HasExited=True ExitCode=$($script:child.ExitCode)"
    }
    return "HasExited=False PID=$($script:child.Id)"
}

# Last lines of the child's stderr log. cmd.exe's 2>> holds the file open
# without sharing while a child is alive, so open with ReadWrite sharing and
# treat an unreadable file as a diagnostic gap, not a second failure.
function Get-ChildLogTail {
    param([int]$Lines = 20)
    if (-not (Test-Path -LiteralPath $logPath)) { return "[manager] $logPath does not exist" }
    try {
        $stream = [IO.FileStream]::new($logPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $reader = [IO.StreamReader]::new($stream)
            $all = $reader.ReadToEnd() -split "`r?`n" | Where-Object { $_ -ne '' }
        }
        finally { $stream.Dispose() }
        $tail = @($all | Select-Object -Last $Lines)
        return "[manager] last $($tail.Count) line(s) of $logPath`:`n" + ($tail -join "`n")
    }
    catch {
        return "[manager] could not read $logPath`: $($_.Exception.Message)"
    }
}

# Processes below the cmd.exe wrapper: al-runner itself and the copy it
# re-executes from. Windows keeps a dead parent's PID on its children, so
# the walk is valid before and after cmd.exe exits.
function Get-ChildDescendantIds {
    if (-not $IsWindows -or $null -eq $script:child) { return @() }
    $all = Get-CimInstance -ClassName Win32_Process -Property ProcessId, ParentProcessId -ErrorAction SilentlyContinue
    if (-not $all) { return @() }
    $found = [Collections.Generic.List[int]]::new()
    $queue = [Collections.Generic.Queue[int]]::new()
    $queue.Enqueue($script:child.Id)
    while ($queue.Count -gt 0) {
        $parent = $queue.Dequeue()
        foreach ($p in $all) {
            if ($p.ParentProcessId -eq $parent -and $p.ProcessId -ne $parent -and -not $found.Contains([int]$p.ProcessId)) {
                $found.Add([int]$p.ProcessId)
                $queue.Enqueue([int]$p.ProcessId)
            }
        }
    }
    return $found.ToArray()
}

function Stop-Child {
    if ($null -eq $script:child) { return }
    # Snapshot the tree while it is alive: WaitForExit below observes only the
    # cmd.exe wrapper, and al-runner's re-executed copy can outlive it.
    $descendants = @(Get-ChildDescendantIds)
    if (-not $script:child.HasExited) {
        try {
            $script:child.StandardInput.WriteLine('{"command":"shutdown"}')
            $null = $script:child.WaitForExit(5000)
        }
        catch {
            # Child's stdin/stdout may already be broken; fall through to Kill.
        }
    }
    if (-not $script:child.HasExited) {
        # $script:child is the cmd.exe wrapper; a plain Kill() only kills the
        # wrapper and orphans al-runner.exe underneath it. Kill(true) takes
        # the whole process tree.
        $script:child.Kill($true)
    }
    # The next Start-Child shares the package cache and al-runner's reexec
    # directory with this tree; a still-exiting predecessor is the suspect
    # for the missing-ready flake, so wait for every descendant before
    # returning, then stop what remains.
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    $alive = @($descendants | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
    while ($alive.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 100
        $alive = @($alive | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
    }
    foreach ($id in $alive) {
        Write-ManagerLog "[manager] descendant PID $id still alive 5 s after shutdown; stopping it"
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
    }
}

$exitCode = 0
try {
    Start-Child

    while ($true) {
        $pipe = [IO.Pipes.NamedPipeServerStream]::new($pipeName, [IO.Pipes.PipeDirection]::InOut, 1)
        try {
            $pipe.WaitForConnection()
            $reader = [IO.StreamReader]::new($pipe); $writer = [IO.StreamWriter]::new($pipe); $writer.AutoFlush = $true
            $request = $reader.ReadLine()
            if ($null -eq $request) { continue }
            $current = Get-ALRunnerServerFingerprint -RepoRoot $RepoRoot
            if ($current -ne $script:fingerprint -or $script:runCount -ge $script:MaxRunsPerChild -or $script:child.HasExited) {
                Stop-Child
                Start-Child
            }
            $script:child.StandardInput.WriteLine($request)
            while ($null -ne ($line = $script:child.StandardOutput.ReadLine())) {
                $writer.WriteLine($line)
                if ($line.StartsWith('{"type":"summary"') -or $line.StartsWith('{"error"')) { break }
            }
            $script:runCount++
        }
        finally { $pipe.Dispose() }
    }
}
catch {
    Write-ManagerLog "[manager] fatal error: $($_.Exception.Message)"
    Stop-Child
    $exitCode = 1
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}

exit $exitCode
