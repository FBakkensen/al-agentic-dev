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

    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $env:ComSpec
    $psi.Arguments = "/c al-runner --server --package-cache `"$($depDir.OutputDirectory)`" 2>>`"$logPath`""
    $psi.WorkingDirectory = $RepoRoot
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $script:child = [Diagnostics.Process]::Start($psi)
    $ready = $script:child.StandardOutput.ReadLine()
    if ($ready -notmatch '"ready":true') {
        throw "al-runner --server did not signal ready: $ready"
    }
    $script:fingerprint = Get-ALRunnerServerFingerprint -RepoRoot $RepoRoot
    $script:runCount = 0
}

function Stop-Child {
    if ($script:child -and -not $script:child.HasExited) {
        try {
            $script:child.StandardInput.WriteLine('{"command":"shutdown"}')
            $null = $script:child.WaitForExit(5000)
        }
        catch {
            # Child's stdin/stdout may already be broken; fall through to Kill.
        }
    }
    if ($script:child -and -not $script:child.HasExited) {
        # $script:child is the cmd.exe wrapper; a plain Kill() only kills the
        # wrapper and orphans al-runner.exe underneath it. Kill(true) takes
        # the whole process tree.
        $script:child.Kill($true)
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
