#Requires -Version 7.2

# The agent container's hosts lines and its PublicWebBaseUrl host. Every hosts
# helper call goes through -HostsFile onto a TestDrive file, so no test touches
# the real hosts file. BcContainerHelper is not installed on the CI runner, so
# the commands the code under test calls get global stubs when they are absent.

BeforeAll {
    $script:CommonModule = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1')
    Import-Module $script:CommonModule -Force
    $script:AgentScriptPath = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'new-agent-container.ps1')

    $script:StubbedCommands = @()
    foreach ($name in 'Get-BcContainerServerConfiguration', 'Set-BcContainerServerConfiguration', 'Restart-BcContainerServiceTier') {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
            $script:StubbedCommands += $name
            Set-Item -Path "function:global:$name" -Value { param([string]$containerName, [string]$keyName, [string]$keyValue) }
        }
    }

    function script:New-HostsFile {
        param([string]$Name = 'hosts')
        $path = Join-Path $TestDrive $Name
        Set-Content -LiteralPath $path -Value @(
            '# Copyright (c) Microsoft Corp.'
            '127.0.0.1       localhost'
            ''
            '# my comment line'
            '10.0.0.9        unrelated-host'
        ) -Encoding ascii
        return $path
    }

    # Lines that name the host, so a stray blank line never changes a count.
    function script:Get-HostLines {
        param([string]$Path, [string]$Hostname)
        @(Get-Content -LiteralPath $Path | Where-Object { $_ -match "^\s*\S+\s+$([regex]::Escape($Hostname))(\s|#|$)" })
    }

    function script:Get-ScriptAst {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:AgentScriptPath, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) { throw "new-agent-container.ps1 has parse errors: $($parseErrors.Message -join '; ')" }
        return $ast
    }
}

AfterAll {
    foreach ($name in $script:StubbedCommands) {
        Remove-Item "function:global:$name" -ErrorAction SilentlyContinue
    }
}

Describe 'Add-HostsEntry and Remove-HostsEntry against a hosts file seam' {
    It 'adds the bare name and the .test name as two lines with the same IP' {
        $hosts = New-HostsFile
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.5'
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x.test' -IPAddress '172.28.0.5'

        $bare = @(Get-HostLines -Path $hosts -Hostname 'feat-x')
        $test = @(Get-HostLines -Path $hosts -Hostname 'feat-x.test')
        $bare | Should -HaveCount 1
        $test | Should -HaveCount 1
        ($bare[0] -split '\s+')[0] | Should -Be '172.28.0.5'
        ($test[0] -split '\s+')[0] | Should -Be '172.28.0.5'
        $bare[0] | Should -Not -Match 'feat-x\.test'
    }

    It 'leaves one line when a name is added twice and replaces the line on a changed IP' {
        $hosts = New-HostsFile
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.5'
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.5'
        Get-HostLines -Path $hosts -Hostname 'feat-x' | Should -HaveCount 1

        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.9'
        $lines = @(Get-HostLines -Path $hosts -Hostname 'feat-x')
        $lines | Should -HaveCount 1
        ($lines[0] -split '\s+')[0] | Should -Be '172.28.0.9'
    }

    It 'keeps unrelated lines and comments through every add and remove' {
        $hosts = New-HostsFile
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.5'
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x.test' -IPAddress '172.28.0.5'
        Remove-HostsEntry -HostsFile $hosts -Hostname 'feat-x'
        Remove-HostsEntry -HostsFile $hosts -Hostname 'feat-x.test'

        $content = Get-Content -LiteralPath $hosts
        $content | Should -Contain '# Copyright (c) Microsoft Corp.'
        $content | Should -Contain '127.0.0.1       localhost'
        $content | Should -Contain '# my comment line'
        $content | Should -Contain '10.0.0.9        unrelated-host'
        Get-HostLines -Path $hosts -Hostname 'feat-x' | Should -HaveCount 0
        Get-HostLines -Path $hosts -Hostname 'feat-x.test' | Should -HaveCount 0
    }

    It 'removes the bare name and leaves the .test line' {
        $hosts = New-HostsFile
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.5'
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x.test' -IPAddress '172.28.0.5'
        Remove-HostsEntry -HostsFile $hosts -Hostname 'feat-x'

        Get-HostLines -Path $hosts -Hostname 'feat-x' | Should -HaveCount 0
        Get-HostLines -Path $hosts -Hostname 'feat-x.test' | Should -HaveCount 1
    }

    It 'removes the .test name and leaves the bare line' {
        $hosts = New-HostsFile
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.5'
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x.test' -IPAddress '172.28.0.5'
        Remove-HostsEntry -HostsFile $hosts -Hostname 'feat-x.test'

        Get-HostLines -Path $hosts -Hostname 'feat-x' | Should -HaveCount 1
        Get-HostLines -Path $hosts -Hostname 'feat-x.test' | Should -HaveCount 0
    }

    It 'does not grow blank lines on repeated adds and removes' {
        $hosts = New-HostsFile
        $before = @(Get-Content -LiteralPath $hosts).Count
        1..3 | ForEach-Object {
            Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.5'
            Remove-HostsEntry -HostsFile $hosts -Hostname 'feat-x'
        }
        @(Get-Content -LiteralPath $hosts).Count | Should -Be $before
    }
}

Describe 'Get-BCContainerTestHostname' {
    It 'returns feat-x.test for feat-x' {
        Get-BCContainerTestHostname -ContainerName 'feat-x' | Should -Be 'feat-x.test'
    }
}

Describe 'Update-BCPublicWebBaseUrl on the .test host' {
    It 'moves PublicWebBaseUrl to the .test host and addresses the container by its bare name' {
        InModuleScope common {
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://bctest:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            $result = Update-BCPublicWebBaseUrl -ContainerName 'feat-x' -NewHostname (Get-BCContainerTestHostname -ContainerName 'feat-x')

            $result | Should -Be 'http://feat-x.test:7080/BC/'
            Should -Invoke Get-BcContainerServerConfiguration -Times 1 -Exactly -ParameterFilter { $containerName -eq 'feat-x' }
            Should -Invoke Set-BcContainerServerConfiguration -Times 1 -Exactly -ParameterFilter {
                $containerName -eq 'feat-x' -and $keyName -eq 'PublicWebBaseUrl' -and $keyValue -eq 'http://feat-x.test:7080/BC/'
            }
            Should -Invoke Restart-BcContainerServiceTier -Times 1 -Exactly -ParameterFilter { $containerName -eq 'feat-x' }
        }
    }
}

Describe 'Update-BCPublicWebBaseUrl when already on the host' {
    It 'makes no set and no restart, and returns the URL unchanged' {
        InModuleScope common {
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://feat-x.test:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            Update-BCPublicWebBaseUrl -ContainerName 'feat-x' -NewHostname 'feat-x.test' | Should -Be 'http://feat-x.test:7080/BC/'

            Should -Invoke Set-BcContainerServerConfiguration -Times 0 -Exactly
            Should -Invoke Restart-BcContainerServiceTier -Times 0 -Exactly
        }
    }
}

Describe 'Set-BCAgentContainerHost' {
    It 'writes both hosts lines with the container IP and moves PublicWebBaseUrl to the .test host' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://bctest:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            Set-BCAgentContainerHost -ContainerName 'feat-x' -IPAddress '172.28.0.5' -HostsFile $Hosts

            Should -Invoke Set-BcContainerServerConfiguration -Times 1 -Exactly -ParameterFilter {
                $containerName -eq 'feat-x' -and $keyValue -eq 'http://feat-x.test:7080/BC/'
            }
        }

        $bare = @(Get-HostLines -Path $hosts -Hostname 'feat-x')
        $test = @(Get-HostLines -Path $hosts -Hostname 'feat-x.test')
        $bare | Should -HaveCount 1
        $test | Should -HaveCount 1
        ($bare[0] -split '\s+')[0] | Should -Be '172.28.0.5'
        ($test[0] -split '\s+')[0] | Should -Be '172.28.0.5'
    }

    It 'returns the .test PublicWebBaseUrl it set' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://bctest:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}

            Set-BCAgentContainerHost -ContainerName 'feat-x' -IPAddress '172.28.0.5' -HostsFile $Hosts | Should -Be 'http://feat-x.test:7080/BC/'
        }
    }

    It 'passes through the URL Update-BCPublicWebBaseUrl returns, asking for the .test host' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Update-BCPublicWebBaseUrl { 'http://feat-x.test:7080/BC/' }

            Set-BCAgentContainerHost -ContainerName 'feat-x' -IPAddress '172.28.0.5' -HostsFile $Hosts | Should -Be 'http://feat-x.test:7080/BC/'

            Should -Invoke Update-BCPublicWebBaseUrl -Times 1 -Exactly -ParameterFilter {
                $ContainerName -eq 'feat-x' -and $NewHostname -eq 'feat-x.test'
            }
        }
    }

    It 'skips the hosts lines for an empty IP, warns that the .test host has no entry, and still moves PublicWebBaseUrl' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Get-BcContainerServerConfiguration { [pscustomobject]@{ PublicWebBaseUrl = 'http://bctest:7080/BC/' } }
            Mock Set-BcContainerServerConfiguration {}
            Mock Restart-BcContainerServiceTier {}
            Mock Write-BuildMessage {}

            Set-BCAgentContainerHost -ContainerName 'feat-x' -IPAddress '' -HostsFile $Hosts

            Should -Invoke Set-BcContainerServerConfiguration -Times 1 -Exactly
            Should -Invoke Write-BuildMessage -Times 1 -Exactly -ParameterFilter {
                $Type -eq 'Warning' -and $Message -like "*'feat-x.test'*no hosts entry*"
            }
        }
        Get-HostLines -Path $hosts -Hostname 'feat-x' | Should -HaveCount 0
        Get-HostLines -Path $hosts -Hostname 'feat-x.test' | Should -HaveCount 0
    }

    It 'throws when PublicWebBaseUrl cannot be set' {
        $hosts = New-HostsFile
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Get-BcContainerServerConfiguration { throw 'service tier unreachable' }
            { Set-BCAgentContainerHost -ContainerName 'feat-x' -IPAddress '172.28.0.5' -HostsFile $Hosts } |
                Should -Throw '*service tier unreachable*'
        }
    }
}

Describe 'Remove-BCAgentContainerHost' {
    It 'removes the bare and the .test line and leaves the rest' {
        $hosts = New-HostsFile
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.5'
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x.test' -IPAddress '172.28.0.5'
        Remove-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $hosts

        Get-HostLines -Path $hosts -Hostname 'feat-x' | Should -HaveCount 0
        Get-HostLines -Path $hosts -Hostname 'feat-x.test' | Should -HaveCount 0
        Get-Content -LiteralPath $hosts | Should -Contain '10.0.0.9        unrelated-host'
    }

    It 'still removes the .test line when the bare removal throws, and names the failed entry' {
        $hosts = New-HostsFile
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x' -IPAddress '172.28.0.5'
        Add-HostsEntry -HostsFile $hosts -Hostname 'feat-x.test' -IPAddress '172.28.0.5'
        InModuleScope common -Parameters @{ Hosts = $hosts } {
            param($Hosts)
            Mock Remove-HostsEntry { throw 'hosts file locked' } -ParameterFilter { $Hostname -eq 'feat-x' }
            Mock Remove-HostsEntry { Update-HostsFile -HostsFile $HostsFile -Hostname $Hostname } -ParameterFilter { $Hostname -ne 'feat-x' }

            { Remove-BCAgentContainerHost -ContainerName 'feat-x' -HostsFile $Hosts } |
                Should -Throw "*'feat-x': hosts file locked*"
        }

        Get-HostLines -Path $hosts -Hostname 'feat-x.test' | Should -HaveCount 0
        Get-HostLines -Path $hosts -Hostname 'feat-x' | Should -HaveCount 1
    }
}

Describe 'new-agent-container.ps1' {
    BeforeAll {
        $script:Ast = Get-ScriptAst
        $script:Commands = @($script:Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true))

        function script:Get-CommandsNamed {
            param([string]$Name)
            @($script:Commands | Where-Object { $_.GetCommandName() -eq $Name })
        }
        # The text of the value following -<Parameter> in a command, or $null.
        function script:Get-ParameterText {
            param($Command, [string]$ParameterName)
            $elements = $Command.CommandElements
            for ($i = 0; $i -lt $elements.Count - 1; $i++) {
                if ($elements[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and $elements[$i].ParameterName -eq $ParameterName) {
                    return $elements[$i + 1].Extent.Text
                }
            }
            return $null
        }
    }

    It 'calls Set-BCAgentContainerHost once, after the health check, for the bare name and the container IP' {
        $calls = Get-CommandsNamed 'Set-BCAgentContainerHost'
        $calls | Should -HaveCount 1
        Get-ParameterText $calls[0] 'ContainerName' | Should -Be '$AgentName'
        Get-ParameterText $calls[0] 'IPAddress' | Should -Be '$containerIP'
        $health = $script:Ast.Extent.Text.IndexOf('Container is healthy')
        $calls[0].Extent.StartOffset | Should -BeGreaterThan $health
    }

    It 'takes the container IP from Get-BCAgentContainerIP, with no docker inspect of its own' {
        $ip = @(Get-CommandsNamed 'Get-BCAgentContainerIP')
        $ip | Should -HaveCount 1
        Get-ParameterText $ip[0] 'ContainerName' | Should -Be '$AgentName'
        $script:Ast.Extent.Text | Should -Not -Match 'NetworkSettings'
    }

    It 'does not build the .test name or call Update-BCPublicWebBaseUrl itself' {
        $script:Ast.Extent.Text | Should -Not -Match '\$\{?\w+\}?\.test|''\.test''|"\.test'
        Get-CommandsNamed 'Update-BCPublicWebBaseUrl' | Should -HaveCount 0
    }

    It 'exits non-zero when Set-BCAgentContainerHost fails, with no catch that only warns' {
        $call = (Get-CommandsNamed 'Set-BCAgentContainerHost')[0]
        $try = $call.Parent
        while ($try -and $try -isnot [System.Management.Automation.Language.TryStatementAst]) { $try = $try.Parent }
        $try | Should -Not -BeNullOrEmpty
        $try.CatchClauses | Should -HaveCount 1
        $catchText = $try.CatchClauses[0].Body.Extent.Text
        $catchText | Should -Match '(?s)-Type Error.*exit \$Exit\.Integration\s*\}$'
    }

    It 'removes the container it started and both hosts entries before it exits on that failure' {
        $call = (Get-CommandsNamed 'Set-BCAgentContainerHost')[0]
        $try = $call.Parent
        while ($try -and $try -isnot [System.Management.Automation.Language.TryStatementAst]) { $try = $try.Parent }
        $catchText = $try.CatchClauses[0].Body.Extent.Text
        $exit = $catchText.IndexOf('exit $Exit.Integration')
        $catchText.IndexOf('Remove-BcContainer -containerName $AgentName') | Should -BeGreaterThan -1
        $catchText.IndexOf('Remove-BcContainer -containerName $AgentName') | Should -BeLessThan $exit
        $catchText.IndexOf('Remove-BCAgentContainerHost -ContainerName $AgentName') | Should -BeGreaterThan -1
        $catchText.IndexOf('Remove-BCAgentContainerHost -ContainerName $AgentName') | Should -BeLessThan $exit
    }

    It 'removes both hosts entries when it recreates an existing container' {
        $recreate = @(Get-CommandsNamed 'Remove-BCAgentContainerHost' | Where-Object {
            $if = $_.Parent
            while ($if -and $if -isnot [System.Management.Automation.Language.IfStatementAst]) { $if = $if.Parent }
            $if -and $if.Clauses[0].Item1.Extent.Text -eq '$existingContainer'
        })
        $recreate | Should -HaveCount 1
        Get-ParameterText $recreate[0] 'ContainerName' | Should -Be '$AgentName'
        Get-CommandsNamed 'Remove-HostsEntry' | Should -HaveCount 0
    }

    It 'keeps the bare name on docker run --name and --hostname' {
        $text = $script:Ast.Extent.Text
        $text | Should -Match "'--name',\s*\`$AgentName"
        $text | Should -Match "'--hostname',\s*\`$AgentName"
    }
}

# Ensure-BCAgentContainer runs new-agent-container.ps1 with `&` from inside common.psm1, so
# the script runs in the module's session state with its own script scope. From there,
# $script: resolves to the script's scope, not the module's (#139). These cases start a
# script the same way.
Describe 'Hosts defaults from a script that common.psm1 starts (#139)' {
    BeforeAll {
        $script:CommonModuleInfo = Get-Module common
        $script:WindowsHostsFile = 'C:\Windows\System32\drivers\etc\hosts'

        function script:Invoke-FromCommonModule {
            param([string]$ScriptPath)
            & $script:CommonModuleInfo { & $args[0] } $ScriptPath
        }
    }

    It 'resolves the hosts helpers'' -HostsFile default to the Windows hosts file' {
        Mock Update-HostsFile {} -ModuleName common
        $child = Join-Path $TestDrive 'hosts-helpers.ps1'
        Set-Content -LiteralPath $child -Value @(
            'Set-StrictMode -Version Latest'
            'Add-HostsEntry -Hostname ''feat-x'' -IPAddress ''172.28.0.5'''
            'Remove-HostsEntry -Hostname ''feat-x'''
        )

        Invoke-FromCommonModule -ScriptPath $child

        Should -Invoke Update-HostsFile -ModuleName common -Times 2 -Exactly -ParameterFilter {
            $HostsFile -eq $script:WindowsHostsFile
        }
    }

    It 'runs Remove-OrphanedAgentContainers, as new-agent-container.ps1''s cleanup does' {
        $originalHome = $env:HOME
        $originalUserProfile = $env:USERPROFILE
        try {
            $env:HOME = Join-Path $TestDrive 'home-139'
            $env:USERPROFILE = $env:HOME
            New-Item -ItemType Directory -Path $env:HOME -Force | Out-Null
            $child = Join-Path $TestDrive 'orphan-cleanup.ps1'
            Set-Content -LiteralPath $child -Value @(
                'Set-StrictMode -Version Latest'
                'Remove-OrphanedAgentContainers -WhatIf'
            )

            { Invoke-FromCommonModule -ScriptPath $child } | Should -Not -Throw
        }
        finally {
            $env:HOME = $originalHome
            $env:USERPROFILE = $originalUserProfile
        }
    }

    It 'has no common.psm1 function that reads a $script: variable' {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:CommonModule, [ref]$tokens, [ref]$parseErrors)
        $parseErrors | Should -BeNullOrEmpty

        $reads = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $node.VariablePath.IsScript
        }, $true) | Where-Object {
            $parent = $_.Parent
            while ($parent -and $parent -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
                $parent = $parent.Parent
            }
            $null -ne $parent
        } | ForEach-Object { "line $($_.Extent.StartLineNumber): $($_.Extent.Text)" })

        $reads | Should -BeNullOrEmpty
    }
}

# BC starts slowly: Docker must report 'starting' through a health start period, and the
# wait must not count startup failures or wait forever (#141).
Describe 'new-agent-container.ps1 health wait (#141)' {
    BeforeAll {
        $script:WaitAst = Get-ScriptAst
    }

    It 'starts the container with a health start period' {
        $runArgs = $script:WaitAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -eq '$runArgs'
        }, $true) | Select-Object -First 1
        $runArgs | Should -Not -BeNullOrEmpty

        $runArgs.Right.Extent.Text | Should -Match "'--health-start-period',\s*\`$healthStartPeriod"
        $script:WaitAst.Extent.Text | Should -Match "\`$healthStartPeriod = '\d+m'"
    }

    It 'decides each poll with Get-BCContainerWaitDecision' {
        $calls = @($script:WaitAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'Get-BCContainerWaitDecision'
        }, $true))
        $calls | Should -HaveCount 1
    }
}

Describe 'Get-BCContainerWaitDecision' {
    BeforeAll {
        $script:WaitArgs = @{
            UnhealthyThreshold = 3
            Elapsed            = [TimeSpan]::FromMinutes(1)
            Timeout            = [TimeSpan]::FromMinutes(20)
        }
    }

    It 'is Ready once Docker reports healthy' {
        $d = Get-BCContainerWaitDecision -Running 'true' -Health 'healthy' -UnhealthyCount 2 @script:WaitArgs
        $d.Action | Should -Be 'Ready'
    }

    It 'is Exited when the container stopped running' {
        $d = Get-BCContainerWaitDecision -Running 'false' -Health 'starting' -UnhealthyCount 0 @script:WaitArgs
        $d.Action | Should -Be 'Exited'
    }

    It 'keeps waiting through any number of starting polls and resets the count' {
        $count = 0
        foreach ($poll in 1..200) {
            $d = Get-BCContainerWaitDecision -Running 'true' -Health 'starting' -UnhealthyCount $count @script:WaitArgs
            $d.Action | Should -Be 'Wait'
            $count = $d.UnhealthyCount
        }
        $count | Should -Be 0
    }

    It 'counts consecutive unhealthy polls and is Unhealthy at the threshold' {
        $first = Get-BCContainerWaitDecision -Running 'true' -Health 'unhealthy' -UnhealthyCount 0 @script:WaitArgs
        $first.Action | Should -Be 'Wait'
        $first.UnhealthyCount | Should -Be 1

        $last = Get-BCContainerWaitDecision -Running 'true' -Health 'unhealthy' -UnhealthyCount 2 @script:WaitArgs
        $last.Action | Should -Be 'Unhealthy'
        $last.UnhealthyCount | Should -Be 3
    }

    It 'resets the unhealthy count when a poll is not unhealthy' {
        $d = Get-BCContainerWaitDecision -Running 'true' -Health 'starting' -UnhealthyCount 2 @script:WaitArgs
        $d.Action | Should -Be 'Wait'
        $d.UnhealthyCount | Should -Be 0
    }

    It 'is TimedOut once the overall wait runs out' {
        $timedOut = $script:WaitArgs.Clone()
        $timedOut.Elapsed = [TimeSpan]::FromMinutes(20)
        $d = Get-BCContainerWaitDecision -Running 'true' -Health 'starting' -UnhealthyCount 0 @timedOut
        $d.Action | Should -Be 'TimedOut'
    }
}
