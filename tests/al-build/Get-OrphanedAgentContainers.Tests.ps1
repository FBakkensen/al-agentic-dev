#Requires -Version 7.2

BeforeAll {
    $script:CommonModule = Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'skills' 'al-build' 'scripts' 'common.psm1')
    Import-Module $script:CommonModule -Force

    function script:Initialize-TestClone {
        param(
            [Parameter(Mandatory)][string]$Path,
            [Parameter(Mandatory)][string]$Branch
        )
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        git -C $Path init -q
        git -C $Path config user.email 'test@example.invalid'
        git -C $Path config user.name  'test'
        git -C $Path config commit.gpgsign false
        git -C $Path remote add origin 'https://example.com/foo.git'
        git -C $Path checkout -q -b $Branch
        git -C $Path commit -q --allow-empty -m 'init'
    }

    # docker and BcContainerHelper may be absent (CI) or live (a developer
    # machine). Mock mocks only a command that exists, so a global stub stands in
    # when it is absent; every case mocks the command inside the common module.
    $script:StubbedCommands = @()
    foreach ($name in 'docker', 'Remove-BcContainer') {
        if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
            $script:StubbedCommands += $name
            Set-Item -Path "function:global:$name" -Value { }
        }
    }
}

AfterAll {
    foreach ($name in $script:StubbedCommands) {
        Remove-Item "function:global:$name" -ErrorAction SilentlyContinue
    }
}

Describe 'Get-OrphanedAgentContainers — cross-clone isolation' -Tag 'Process' {
    BeforeAll {
        $script:OriginalHome = $env:HOME
        $script:OriginalUserProfile = $env:USERPROFILE

        $script:FakeHome = Join-Path $TestDrive 'home'
        New-Item -ItemType Directory -Path $script:FakeHome -Force | Out-Null
        $env:HOME = $script:FakeHome
        $env:USERPROFILE = $script:FakeHome

        $script:CloneA = Join-Path $TestDrive 'cloneA'
        $script:CloneB = Join-Path $TestDrive 'cloneB'
        Initialize-TestClone -Path $script:CloneA -Branch 'feat-x'
        Initialize-TestClone -Path $script:CloneB -Branch 'feat-y'

        Push-Location $script:CloneA
        try {
            Register-AgentContainer -ContainerName 'feat-x' -Branch 'feat-x'
            Register-AgentContainer -ContainerName 'ghost'  -Branch 'never-created'
        } finally {
            Pop-Location
        }

        Push-Location $script:CloneB
        try {
            Register-AgentContainer -ContainerName 'feat-y' -Branch 'feat-y'
        } finally {
            Pop-Location
        }
    }

    AfterAll {
        $env:HOME = $script:OriginalHome
        $env:USERPROFILE = $script:OriginalUserProfile
    }

    It 'does not flag a peer clone container as orphaned' {
        Push-Location $script:CloneA
        try {
            $orphaned = @(Get-OrphanedAgentContainers)
            $orphaned.ContainerName | Should -Not -Contain 'feat-y'
        } finally {
            Pop-Location
        }
    }

    It 'flags the current clone container whose branch does not exist' {
        Push-Location $script:CloneA
        try {
            $orphaned = @(Get-OrphanedAgentContainers)
            $ghost = $orphaned | Where-Object { $_.ContainerName -eq 'ghost' }
            $ghost          | Should -Not -BeNullOrEmpty
            $ghost.Reason   | Should -Be 'orphaned'
        } finally {
            Pop-Location
        }
    }

    It 'does not flag the current clone container whose branch exists' {
        Push-Location $script:CloneA
        try {
            $orphaned = @(Get-OrphanedAgentContainers)
            $orphaned.ContainerName | Should -Not -Contain 'feat-x'
        } finally {
            Pop-Location
        }
    }
}

Describe 'Get-GitRepoIdentifier — worktree consistency' -Tag 'Process' {
    BeforeAll {
        $script:OriginalHome = $env:HOME
        $script:OriginalUserProfile = $env:USERPROFILE

        $script:FakeHome = Join-Path $TestDrive 'home-worktree'
        New-Item -ItemType Directory -Path $script:FakeHome -Force | Out-Null
        $env:HOME = $script:FakeHome
        $env:USERPROFILE = $script:FakeHome

        $script:Primary = Join-Path $TestDrive 'primary'
        Initialize-TestClone -Path $script:Primary -Branch 'main-line'

        $script:Linked = Join-Path $TestDrive 'linked'
        git -C $script:Primary worktree add -q -b 'wt-branch' $script:Linked
    }

    AfterAll {
        $env:HOME = $script:OriginalHome
        $env:USERPROFILE = $script:OriginalUserProfile
    }

    It 'returns the same identifier from a linked worktree as from the primary working tree' {
        $primaryPath = $script:Primary
        $linkedPath  = $script:Linked

        $primaryId = InModuleScope common -Parameters @{ Path = $primaryPath } {
            param($Path)
            Push-Location $Path
            try { Get-GitRepoIdentifier } finally { Pop-Location }
        }

        $linkedId = InModuleScope common -Parameters @{ Path = $linkedPath } {
            param($Path)
            Push-Location $Path
            try { Get-GitRepoIdentifier } finally { Pop-Location }
        }

        $primaryId | Should -Not -BeNullOrEmpty
        $linkedId  | Should -Be $primaryId
    }
}

Describe 'Remove-OrphanedAgentContainers - hosts entries' -Tag 'Process' {
    BeforeAll {
        $script:OriginalHome = $env:HOME
        $script:OriginalUserProfile = $env:USERPROFILE

        $script:FakeHome = Join-Path $TestDrive 'home-prune'
        New-Item -ItemType Directory -Path $script:FakeHome -Force | Out-Null
        $env:HOME = $script:FakeHome
        $env:USERPROFILE = $script:FakeHome

        $script:PruneClone = Join-Path $TestDrive 'cloneP'
        Initialize-TestClone -Path $script:PruneClone -Branch 'feat-x'
    }

    AfterAll {
        $env:HOME = $script:OriginalHome
        $env:USERPROFILE = $script:OriginalUserProfile
    }

    BeforeEach {
        # 'ghost' is registered against a branch that never existed, so prune flags it.
        Push-Location $script:PruneClone
        Register-AgentContainer -ContainerName 'ghost' -Branch 'never-created'

        $script:Hosts = Join-Path $TestDrive 'prune-hosts'
        Set-Content -LiteralPath $script:Hosts -Encoding ascii -Value @(
            '127.0.0.1       localhost'
            '# my comment line'
            "172.28.0.5`tghost"
            "172.28.0.5`tghost.test"
            '10.0.0.9        unrelated-host'
        )
    }

    AfterEach {
        Unregister-AgentContainer -ContainerName 'ghost'
        Pop-Location
    }

    It 'removes both hosts lines for a pruned container docker lists, and keeps unrelated lines' {
        InModuleScope common -Parameters @{ Hosts = $script:Hosts } {
            param($Hosts)
            Mock docker { 'ghost' } -ParameterFilter { $args[0] -eq 'ps' }
            Mock docker {}
            Mock Remove-BcContainer {}

            Remove-OrphanedAgentContainers -HostsFile $Hosts

            Should -Invoke Remove-BcContainer -Times 1 -Exactly -ParameterFilter { $containerName -eq 'ghost' }
        }

        $content = Get-Content -LiteralPath $script:Hosts
        $content | Should -Not -Match '\sghost(\.test)?(\s|$)'
        $content | Should -Contain '127.0.0.1       localhost'
        $content | Should -Contain '# my comment line'
        $content | Should -Contain '10.0.0.9        unrelated-host'
    }

    It 'still removes both hosts lines and unregisters a pruned container docker no longer lists' {
        InModuleScope common -Parameters @{ Hosts = $script:Hosts } {
            param($Hosts)
            Mock docker {}
            Mock Remove-BcContainer {}

            Remove-OrphanedAgentContainers -HostsFile $Hosts

            Should -Invoke Remove-BcContainer -Times 0 -Exactly
        }

        $content = Get-Content -LiteralPath $script:Hosts
        $content | Should -Not -Match '\sghost(\.test)?(\s|$)'
        $content | Should -Contain '10.0.0.9        unrelated-host'
        (Get-RegisteredAgentContainers).ContainsKey('ghost') | Should -BeFalse
    }

    It 'leaves the hosts file and the registry alone with -WhatIf' {
        $before = Get-Content -LiteralPath $script:Hosts -Raw
        InModuleScope common -Parameters @{ Hosts = $script:Hosts } {
            param($Hosts)
            Mock docker { 'ghost' } -ParameterFilter { $args[0] -eq 'ps' }
            Mock docker {}
            Mock Remove-BcContainer {}

            Remove-OrphanedAgentContainers -HostsFile $Hosts -WhatIf

            Should -Invoke Remove-BcContainer -Times 0 -Exactly
        }

        Get-Content -LiteralPath $script:Hosts -Raw | Should -Be $before
        (Get-RegisteredAgentContainers).ContainsKey('ghost') | Should -BeTrue
    }
}
