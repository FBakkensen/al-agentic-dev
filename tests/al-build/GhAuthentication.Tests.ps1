#Requires -Version 7.2

BeforeAll {
    $script:CommonModule = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1')
    Import-Module $script:CommonModule -Force -DisableNameChecking
}

Describe 'Get-GhTargetHostName' {
    BeforeEach {
        $script:savedGhHost = $env:GH_HOST
    }
    AfterEach {
        $env:GH_HOST = $script:savedGhHost
    }

    It 'takes the host from the origin remote even when GH_HOST names another host' {
        Mock -ModuleName 'common' git { $global:LASTEXITCODE = 0; 'https://mytenant.ghe.com/acme/widget.git' }
        $env:GH_HOST = 'github.com'
        Get-GhTargetHostName | Should -Be 'mytenant.ghe.com'
    }

    It 'parses an SSH origin remote' {
        Mock -ModuleName 'common' git { $global:LASTEXITCODE = 0; 'git@mytenant.ghe.com:acme/widget.git' }
        Get-GhTargetHostName | Should -Be 'mytenant.ghe.com'
    }

    It 'parses an ssh:// origin remote with user and port' {
        Mock -ModuleName 'common' git { $global:LASTEXITCODE = 0; 'ssh://git@mytenant.ghe.com:122/acme/widget.git' }
        $env:GH_HOST = ''
        Get-GhTargetHostName | Should -Be 'mytenant.ghe.com'
    }

    It 'drops port and userinfo from an HTTPS origin remote' {
        Mock -ModuleName 'common' git { $global:LASTEXITCODE = 0; 'https://user:tok@mytenant.ghe.com:8443/acme/widget.git' }
        Get-GhTargetHostName | Should -Be 'mytenant.ghe.com'
    }

    It 'falls back to GH_HOST when there is no origin remote' {
        Mock -ModuleName 'common' git { $global:LASTEXITCODE = 2 }
        $env:GH_HOST = 'mytenant.ghe.com'
        Get-GhTargetHostName | Should -Be 'mytenant.ghe.com'
    }

    It 'falls back to github.com when neither origin nor GH_HOST is available' {
        Mock -ModuleName 'common' git { $global:LASTEXITCODE = 2 }
        $env:GH_HOST = ''
        Get-GhTargetHostName | Should -Be 'github.com'
    }

    It 'falls through to GH_HOST when the origin URL is unparseable' {
        Mock -ModuleName 'common' git { $global:LASTEXITCODE = 0; 'not a url' }
        $env:GH_HOST = 'mytenant.ghe.com'
        Get-GhTargetHostName | Should -Be 'mytenant.ghe.com'
    }
}

Describe 'Test-GhAuthentication' {
    BeforeEach {
        Mock -ModuleName 'common' git { $global:LASTEXITCODE = 0; 'https://mytenant.ghe.com/acme/widget.git' }
    }

    It 'checks only the resolved host with gh auth status --hostname' {
        Mock -ModuleName 'common' gh { $global:LASTEXITCODE = 0 }
        Test-GhAuthentication | Should -BeTrue
        Should -Invoke -ModuleName 'common' gh -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq 'auth' -and $args[1] -eq 'status' -and
            $args[2] -eq '--hostname' -and $args[3] -eq 'mytenant.ghe.com'
        }
    }

    It 'checks an explicit -HostName instead of the resolved one' {
        Mock -ModuleName 'common' gh { $global:LASTEXITCODE = 0 }
        Test-GhAuthentication -HostName 'github.com' | Should -BeTrue
        Should -Invoke -ModuleName 'common' gh -Times 1 -Exactly -ParameterFilter {
            $args[2] -eq '--hostname' -and $args[3] -eq 'github.com'
        }
    }

    It 'returns false when gh reports the host unauthenticated' {
        Mock -ModuleName 'common' gh { $global:LASTEXITCODE = 1 }
        Test-GhAuthentication | Should -BeFalse
    }
}
