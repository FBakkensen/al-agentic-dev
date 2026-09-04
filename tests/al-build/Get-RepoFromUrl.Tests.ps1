#Requires -Version 7.2

BeforeAll {
    $script:CommonModule = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1')
    Import-Module $script:CommonModule -Force
}

Describe 'Get-RepoFromUrl' {
    Context 'HTTPS URLs' {
        It 'parses HTTPS github.com URL' {
            $r = Get-RepoFromUrl 'https://github.com/owner/repo'
            $r.HostName | Should -Be 'github.com'
            $r.Owner    | Should -Be 'owner'
            $r.Repo     | Should -Be 'repo'
        }

        It 'parses HTTPS github.com URL with .git suffix' {
            $r = Get-RepoFromUrl 'https://github.com/owner/repo.git'
            $r.HostName | Should -Be 'github.com'
            $r.Owner    | Should -Be 'owner'
            $r.Repo     | Should -Be 'repo'
        }

        It 'parses HTTPS GHE URL' {
            $r = Get-RepoFromUrl 'https://mytenant.ghe.com/acme/widget'
            $r.HostName | Should -Be 'mytenant.ghe.com'
            $r.Owner    | Should -Be 'acme'
            $r.Repo     | Should -Be 'widget'
        }

        It 'parses HTTPS GHE URL with .git suffix' {
            $r = Get-RepoFromUrl 'https://mytenant.ghe.com/acme/widget.git'
            $r.HostName | Should -Be 'mytenant.ghe.com'
            $r.Owner    | Should -Be 'acme'
            $r.Repo     | Should -Be 'widget'
        }

        It 'parses HTTPS custom-host URL' {
            $r = Get-RepoFromUrl 'https://git.example.com/team/proj'
            $r.HostName | Should -Be 'git.example.com'
            $r.Owner    | Should -Be 'team'
            $r.Repo     | Should -Be 'proj'
        }

        It 'parses HTTP (insecure) URL' {
            $r = Get-RepoFromUrl 'http://internal.example/owner/repo'
            $r.HostName | Should -Be 'internal.example'
            $r.Owner    | Should -Be 'owner'
            $r.Repo     | Should -Be 'repo'
        }

        It 'drops the port from an HTTPS host' {
            $r = Get-RepoFromUrl 'https://ghe.example.com:8443/acme/widget.git'
            $r.HostName | Should -Be 'ghe.example.com'
            $r.Owner    | Should -Be 'acme'
            $r.Repo     | Should -Be 'widget'
        }

        It 'drops userinfo from an HTTPS host' {
            $r = Get-RepoFromUrl 'https://user:tok@ghe.example.com/acme/widget.git'
            $r.HostName | Should -Be 'ghe.example.com'
            $r.Owner    | Should -Be 'acme'
            $r.Repo     | Should -Be 'widget'
        }
    }

    Context 'SSH URLs' {
        It 'parses ssh:// URL with user' {
            $r = Get-RepoFromUrl 'ssh://git@ghe.example.com/acme/widget.git'
            $r.HostName | Should -Be 'ghe.example.com'
            $r.Owner    | Should -Be 'acme'
            $r.Repo     | Should -Be 'widget'
        }

        It 'parses ssh:// URL with a non-standard port' {
            $r = Get-RepoFromUrl 'ssh://git@ghe.example.com:122/acme/widget.git'
            $r.HostName | Should -Be 'ghe.example.com'
            $r.Owner    | Should -Be 'acme'
            $r.Repo     | Should -Be 'widget'
        }

        It 'parses ssh:// URL without user or .git' {
            $r = Get-RepoFromUrl 'ssh://ghe.example.com/acme/widget'
            $r.HostName | Should -Be 'ghe.example.com'
            $r.Repo     | Should -Be 'widget'
        }
        It 'parses SSH github.com URL with .git suffix' {
            $r = Get-RepoFromUrl 'git@github.com:owner/repo.git'
            $r.HostName | Should -Be 'github.com'
            $r.Owner    | Should -Be 'owner'
            $r.Repo     | Should -Be 'repo'
        }

        It 'parses SSH github.com URL without .git suffix' {
            $r = Get-RepoFromUrl 'git@github.com:owner/repo'
            $r.HostName | Should -Be 'github.com'
            $r.Owner    | Should -Be 'owner'
            $r.Repo     | Should -Be 'repo'
        }

        It 'parses SSH GHE URL' {
            $r = Get-RepoFromUrl 'git@mytenant.ghe.com:acme/widget.git'
            $r.HostName | Should -Be 'mytenant.ghe.com'
            $r.Owner    | Should -Be 'acme'
            $r.Repo     | Should -Be 'widget'
        }
    }

    Context 'Bare owner/repo form' {
        It 'treats bare owner/repo as github.com' {
            $r = Get-RepoFromUrl 'owner/repo'
            $r.HostName | Should -Be 'github.com'
            $r.Owner    | Should -Be 'owner'
            $r.Repo     | Should -Be 'repo'
        }

        It 'treats bare owner/repo.git as github.com and strips .git' {
            $r = Get-RepoFromUrl 'owner/repo.git'
            $r.HostName | Should -Be 'github.com'
            $r.Owner    | Should -Be 'owner'
            $r.Repo     | Should -Be 'repo'
        }
    }

    Context 'Repository names with dots' {
        It 'preserves dots in HTTPS repo name' {
            $r = Get-RepoFromUrl 'https://github.com/microsoft/vscode.dev'
            $r.HostName | Should -Be 'github.com'
            $r.Owner    | Should -Be 'microsoft'
            $r.Repo     | Should -Be 'vscode.dev'
        }

        It 'preserves dots in bare repo name' {
            $r = Get-RepoFromUrl 'microsoft/vscode.dev'
            $r.HostName | Should -Be 'github.com'
            $r.Owner    | Should -Be 'microsoft'
            $r.Repo     | Should -Be 'vscode.dev'
        }

        It 'preserves dots in github.io style repo name' {
            $r = Get-RepoFromUrl 'https://github.com/octocat/octocat.github.io'
            $r.Repo | Should -Be 'octocat.github.io'
        }
    }

    Context 'Invalid inputs' {
        It 'throws on empty string' {
            { Get-RepoFromUrl '' } | Should -Throw
        }

        It 'throws on URL with missing repo segment' {
            { Get-RepoFromUrl 'https://github.com/owner' } | Should -Throw
        }

        It 'throws on URL with extra path segments' {
            { Get-RepoFromUrl 'https://github.com/owner/repo/tree/main' } | Should -Throw
        }

        It 'throws on garbage input' {
            { Get-RepoFromUrl 'not a url' } | Should -Throw
        }

        It 'throws on single-segment slug' {
            { Get-RepoFromUrl 'reponame' } | Should -Throw
        }

        It 'redacts userinfo from the error message' {
            $err = { Get-RepoFromUrl 'https://user:s3cret@ghe.example.com/owner' } | Should -Throw -PassThru
            $err.Exception.Message | Should -Not -Match 's3cret'
            $err.Exception.Message | Should -Match 'https://ghe.example.com/owner'
        }
    }
}
