#Requires -Version 7.2

BeforeAll {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:IssueScript = Join-Path (Join-Path $repoRoot 'scripts') 'Update-BcContainerHelperCanaryIssue.ps1'
    $script:CompatibilityScript = Join-Path (Join-Path $repoRoot 'scripts') 'Test-BcContainerHelperCompatibility.ps1'
    $workflowsRoot = Join-Path (Join-Path $repoRoot '.github') 'workflows'
    $script:WorkflowPath = Join-Path $workflowsRoot 'bccontainerhelper-canary.yml'

    function New-GhRecorder {
        param([object[]]$OpenIssues = @())

        $calls = [System.Collections.Generic.List[object]]::new()
        $handler = {
            param([string[]]$Arguments)
            $calls.Add([string[]]$Arguments)
            if ($Arguments[0] -eq 'issue' -and $Arguments[1] -eq 'list') {
                return @($OpenIssues) | ConvertTo-Json -Compress -AsArray
            }
            ''
        }.GetNewClosure()

        [pscustomobject]@{
            Calls   = $calls
            Handler = $handler
        }
    }

    function Get-SyntheticPsTestFunctions {
        @'
param(
    [string]$clientDllPath,
    [string]$newtonSoftDllPath,
    [string]$clientContextScriptPath
)
function New-ClientContext {
    param($serviceUrl, $auth, $credential)
}
function Disable-SslVerification {}
'@
    }

    function Get-SyntheticClientContext {
        @'
param([string]$clientDllPath)
class ClientContext {
    [void] OpenSession() {}
    [void] Dispose() {}
    [object] OpenForm([int]$page) { return $null }
    [void] CloseForm([object]$form) {}
    [object] GetControlByName([object]$control, [string]$name) { return $null }
    [void] SaveValue([object]$control, [object]$newValue) {}
    [object] GetActionByName([object]$control, [string]$name) { return $null }
    [void] InvokeAction([object]$action) {}
}
'@
    }

    function New-SyntheticBcContainerHelper {
        param(
            [string]$PsTestFunctions = (Get-SyntheticPsTestFunctions),
            [string]$ClientContext = (Get-SyntheticClientContext),
            [switch]$OmitPsTestFunctions,
            [switch]$OmitClientContext
        )

        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $moduleRoot = Join-Path $root 'BcContainerHelper'
        $appHandlingRoot = Join-Path $moduleRoot 'AppHandling'
        $adapterRoot = Join-Path $root 'adapter'
        $null = New-Item -ItemType Directory -Path $appHandlingRoot -Force
        $null = New-Item -ItemType Directory -Path $adapterRoot -Force

        $moduleFile = Join-Path $moduleRoot 'BcContainerHelper.psm1'
        $manifestFile = Join-Path $moduleRoot 'BcContainerHelper.psd1'
        Set-Content -LiteralPath $moduleFile -Value ''
        Set-Content -LiteralPath $manifestFile -Value @'
@{
    RootModule = 'BcContainerHelper.psm1'
    ModuleVersion = '9.9.9'
    GUID = 'a5cf5777-1727-48dd-852f-5fc150efea29'
    FunctionsToExport = @()
    CmdletsToExport = @()
    AliasesToExport = @()
}
'@
        Set-Content -LiteralPath (Join-Path $adapterRoot 'adapter.ps1') -Value '# synthetic adapter'

        if (-not $OmitPsTestFunctions) {
            Set-Content `
                -LiteralPath (Join-Path $appHandlingRoot 'PsTestFunctions.ps1') `
                -Value $PsTestFunctions
        }
        if (-not $OmitClientContext) {
            Set-Content `
                -LiteralPath (Join-Path $appHandlingRoot 'ClientContext.ps1') `
                -Value $ClientContext
        }

        [pscustomobject]@{
            ManifestPath = $manifestFile
            ScriptsPath  = $adapterRoot
        }
    }
}

Describe 'BcContainerHelper canary issue lifecycle' {
    It 'creates one issue with version, failure, and workflow link' {
        $recorder = New-GhRecorder

        & $script:IssueScript `
            -Conclusion Failure `
            -Version '6.2.3' `
            -Failure 'Run-TestsInBcContainer lost parameter foo' `
            -WorkflowUrl 'https://github.example/runs/42' `
            -Repository 'owner/repo' `
            -GhCommand $recorder.Handler

        $create = @($recorder.Calls | Where-Object { $_[0] -eq 'issue' -and $_[1] -eq 'create' })
        $create | Should -HaveCount 1
        $body = $create[0][[array]::IndexOf($create[0], '--body') + 1]
        $body | Should -Match '6\.2\.3'
        $body | Should -Match 'Run-TestsInBcContainer lost parameter foo'
        $body | Should -Match 'https://github\.example/runs/42'
    }

    It 'updates the primary issue and closes duplicate open issues' {
        $recorder = New-GhRecorder -OpenIssues @(
            [pscustomobject]@{
                number = 12
                title  = '[Canary] BcContainerHelper compatibility'
                state  = 'OPEN'
            }
            [pscustomobject]@{
                number = 18
                title  = '[Canary] BcContainerHelper compatibility'
                state  = 'OPEN'
            }
            [pscustomobject]@{ number = 20; title = 'Unrelated issue'; state = 'OPEN' }
        )

        & $script:IssueScript `
            -Conclusion Failure `
            -Version '6.2.4' `
            -Failure 'missing command' `
            -WorkflowUrl 'https://github.example/runs/43' `
            -Repository 'owner/repo' `
            -GhCommand $recorder.Handler

        $comment = @($recorder.Calls | Where-Object {
            $_[0] -eq 'issue' -and $_[1] -eq 'comment' -and $_[2] -eq '12'
        })
        $comment | Should -HaveCount 1
        $body = $comment[0][[array]::IndexOf($comment[0], '--body') + 1]
        $body | Should -Match '6\.2\.4'
        $body | Should -Match 'missing command'
        $body | Should -Match 'https://github\.example/runs/43'

        $calls = @($recorder.Calls | ForEach-Object { $_ -join ' ' })
        $calls | Should -Contain 'issue close 18 --repo owner/repo --reason not planned'
        @($calls | Where-Object { $_ -match '^issue create ' }) | Should -HaveCount 0
        @($calls | Where-Object { $_ -match '^issue close 20 ' }) | Should -HaveCount 0
    }

    It 'reopens the canonical issue when a later canary fails' {
        $recorder = New-GhRecorder -OpenIssues @(
            [pscustomobject]@{
                number = 12
                title  = '[Canary] BcContainerHelper compatibility'
                state  = 'CLOSED'
            }
        )

        & $script:IssueScript `
            -Conclusion Failure `
            -Version '6.2.5' `
            -Failure 'regression returned' `
            -WorkflowUrl 'https://github.example/runs/44' `
            -Repository 'owner/repo' `
            -GhCommand $recorder.Handler

        $calls = @($recorder.Calls | ForEach-Object { $_ -join ' ' })
        $calls | Should -Contain 'issue reopen 12 --repo owner/repo'
        @($calls | Where-Object { $_ -match '^issue create ' }) | Should -HaveCount 0
    }

    It 'comments on and closes the compatibility issue after a green run' {
        $recorder = New-GhRecorder -OpenIssues @(
            [pscustomobject]@{
                number = 12
                title  = '[Canary] BcContainerHelper compatibility'
                state  = 'OPEN'
            }
        )

        & $script:IssueScript `
            -Conclusion Success `
            -Version '6.2.5' `
            -WorkflowUrl 'https://github.example/runs/44' `
            -Repository 'owner/repo' `
            -GhCommand $recorder.Handler

        $calls = @($recorder.Calls | ForEach-Object { $_ -join ' ' })
        @($calls | Where-Object { $_ -match '^issue comment 12 ' -and $_ -match '6\.2\.5' }) |
            Should -HaveCount 1
        $calls | Should -Contain 'issue close 12 --repo owner/repo --reason completed'
    }
}

Describe 'BcContainerHelper canary workflow contract' {
    It 'is weekly, manually dispatchable, Windows-only, and outside pull-request CI' {
        $workflow = Get-Content -LiteralPath $script:WorkflowPath -Raw

        $workflow | Should -Match "cron:\s*'0 5 \* \* 1'"
        $workflow | Should -Match 'workflow_dispatch:'
        $workflow | Should -Match 'runs-on:\s*windows-latest'
        $workflow | Should -Not -Match 'pull_request:'
    }

    It 'runs compatibility checks without starting a BC container' {
        $workflow = Get-Content -LiteralPath $script:WorkflowPath -Raw

        $workflow | Should -Match 'Test-BcContainerHelperCompatibility\.ps1'
        $workflow | Should -Match 'Invoke-Pester -Path tests\\al-build'
        $workflow | Should -Match 'continue-on-error:\s*true'
        $workflow | Should -Not -Match '(?i)New-BcContainer'
    }
}

Describe 'BcContainerHelper private runtime compatibility' {
    AfterEach {
        Remove-Module BcContainerHelper -Force -ErrorAction SilentlyContinue
    }

    It 'accepts the private files and contracts consumed by coverage runtime' {
        $layout = New-SyntheticBcContainerHelper

        {
            & $script:CompatibilityScript `
                -ModulePath $layout.ManifestPath `
                -ScriptsPath $layout.ScriptsPath
        } | Should -Not -Throw
    }

    It 'fails when <File> is missing' -TestCases @(
        @{ File = 'AppHandling\PsTestFunctions.ps1'; OmitPsTestFunctions = $true; OmitClientContext = $false }
        @{ File = 'AppHandling\ClientContext.ps1'; OmitPsTestFunctions = $false; OmitClientContext = $true }
    ) {
        param($File, $OmitPsTestFunctions, $OmitClientContext)
        $layout = New-SyntheticBcContainerHelper `
            -OmitPsTestFunctions:$OmitPsTestFunctions `
            -OmitClientContext:$OmitClientContext

        {
            & $script:CompatibilityScript `
                -ModulePath $layout.ManifestPath `
                -ScriptsPath $layout.ScriptsPath
        } | Should -Throw -ExpectedMessage "*Missing required private BcContainerHelper file '$File'*"
    }

    It 'fails when the dot-sourced helper entry parameters drift' {
        $psTestFunctions = (Get-SyntheticPsTestFunctions).Replace(
            'param($serviceUrl, $auth, $credential)',
            'param($serviceUrl, $auth)'
        )
        $layout = New-SyntheticBcContainerHelper -PsTestFunctions $psTestFunctions

        {
            & $script:CompatibilityScript `
                -ModulePath $layout.ManifestPath `
                -ScriptsPath $layout.ScriptsPath
        } | Should -Throw -ExpectedMessage "*New-ClientContext*credential*"
    }

    It 'allows optional additions but fails on an unsupplied mandatory helper parameter' {
        $optionalAddition = (Get-SyntheticPsTestFunctions).Replace(
            'param($serviceUrl, $auth, $credential)',
            'param($serviceUrl, $auth, $credential, $culture)'
        )
        $optionalLayout = New-SyntheticBcContainerHelper -PsTestFunctions $optionalAddition
        {
            & $script:CompatibilityScript `
                -ModulePath $optionalLayout.ManifestPath `
                -ScriptsPath $optionalLayout.ScriptsPath
        } | Should -Not -Throw

        Remove-Module BcContainerHelper -Force -ErrorAction SilentlyContinue
        $mandatoryAddition = (Get-SyntheticPsTestFunctions).Replace(
            'param($serviceUrl, $auth, $credential)',
            'param($serviceUrl, $auth, $credential, [Parameter(Mandatory)]$culture)'
        )
        $mandatoryLayout = New-SyntheticBcContainerHelper -PsTestFunctions $mandatoryAddition
        {
            & $script:CompatibilityScript `
                -ModulePath $mandatoryLayout.ManifestPath `
                -ScriptsPath $mandatoryLayout.ScriptsPath
        } | Should -Throw -ExpectedMessage "*New-ClientContext*runtime call*"
    }

    It 'fails when a no-argument private function gains a mandatory parameter' {
        $psTestFunctions = (Get-SyntheticPsTestFunctions).Replace(
            'function Disable-SslVerification {}',
            'function Disable-SslVerification { param([Parameter(Mandatory)]$mode) }'
        )
        $layout = New-SyntheticBcContainerHelper -PsTestFunctions $psTestFunctions

        {
            & $script:CompatibilityScript `
                -ModulePath $layout.ManifestPath `
                -ScriptsPath $layout.ScriptsPath
        } | Should -Throw -ExpectedMessage "*Disable-SslVerification*runtime call*"
    }

    It 'fails when the private ClientContext script entry parameter drifts' {
        $clientContext = (Get-SyntheticClientContext).Replace(
            'param([string]$clientDllPath)',
            'param([string]$assemblyPath)'
        )
        $layout = New-SyntheticBcContainerHelper -ClientContext $clientContext

        {
            & $script:CompatibilityScript `
                -ModulePath $layout.ManifestPath `
                -ScriptsPath $layout.ScriptsPath
        } | Should -Throw -ExpectedMessage "*ClientContext.ps1 is missing script parameter '-clientDllPath'*"
    }

    It 'fails when private method <Method> changes its runtime arity' -TestCases @(
        @{
            Method = 'OpenSession'
            Original = '[void] OpenSession() {}'
            Replacement = '[void] OpenSession([object]$session) {}'
        }
        @{
            Method = 'Dispose'
            Original = '[void] Dispose() {}'
            Replacement = '[void] Dispose([switch]$force) {}'
        }
        @{
            Method = 'OpenForm'
            Original = '[object] OpenForm([int]$page) { return $null }'
            Replacement = '[object] OpenForm() { return $null }'
        }
        @{
            Method = 'CloseForm'
            Original = '[void] CloseForm([object]$form) {}'
            Replacement = '[void] CloseForm() {}'
        }
        @{
            Method = 'GetControlByName'
            Original = '[object] GetControlByName([object]$control, [string]$name) { return $null }'
            Replacement = '[object] GetControlByName([object]$control) { return $null }'
        }
        @{
            Method = 'SaveValue'
            Original = '[void] SaveValue([object]$control, [object]$newValue) {}'
            Replacement = '[void] SaveValue([object]$control) {}'
        }
        @{
            Method = 'GetActionByName'
            Original = '[object] GetActionByName([object]$control, [string]$name) { return $null }'
            Replacement = '[object] GetActionByName([object]$control) { return $null }'
        }
        @{
            Method = 'InvokeAction'
            Original = '[void] InvokeAction([object]$action) {}'
            Replacement = '[void] InvokeAction() {}'
        }
    ) {
        param($Method, $Original, $Replacement)
        $clientContext = (Get-SyntheticClientContext).Replace($Original, $Replacement)
        $layout = New-SyntheticBcContainerHelper -ClientContext $clientContext

        {
            & $script:CompatibilityScript `
                -ModulePath $layout.ManifestPath `
                -ScriptsPath $layout.ScriptsPath
        } | Should -Throw -ExpectedMessage "*private method '$Method'*"
    }
}
