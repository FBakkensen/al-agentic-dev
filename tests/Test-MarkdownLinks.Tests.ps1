#Requires -Version 7.2

BeforeAll {
    $script:AuditPath = Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Test-MarkdownLinks.ps1')

    function New-MarkdownRepoFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [Parameter(Mandatory = $true)]
            [hashtable]$Files
        )

        New-Item -ItemType Directory -Path $Root -Force | Out-Null
        foreach ($relativePath in $Files.Keys) {
            $path = Join-Path $Root $relativePath
            $directory = [System.IO.Path]::GetDirectoryName($path)
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Set-Content -LiteralPath $path -Value $Files[$relativePath] -Encoding utf8
        }

        & git -C $Root init --quiet
        & git -C $Root add -- '*.md'
        if ($LASTEXITCODE -ne 0) {
            throw "Could not stage Markdown fixture files in '$Root'."
        }
    }

    function Invoke-MarkdownLinkAudit {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [string[]]$Arguments = @()
        )

        $output = @(& pwsh -NoProfile -File $script:AuditPath -RepoRoot $Root @Arguments)
        return @{
            ExitCode = $LASTEXITCODE
            Pairs = @($output | Where-Object { $_ -is [string] })
        }
    }
}

Describe 'Test-MarkdownLinks' {
    It 'resolves relative targets, fragments, URL-encoded names, and directories' {
        $root = Join-Path $TestDrive 'resolved-targets'
        New-MarkdownRepoFixture -Root $root -Files @{
            'docs\guide.md' = @'
[Guide](guide/intro.md#overview)
[Encoded](encoded%20name.md)
[Directory](guide/)
'@
            'docs\guide\intro.md' = '# Intro'
            'docs\encoded name.md' = '# Encoded'
            'docs\guide\.gitkeep' = ''
        }

        $result = Invoke-MarkdownLinkAudit -Root $root

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -BeNullOrEmpty
    }

    It 'ignores external, protocol-relative, fragment-only, and intentional placeholder links' {
        $root = Join-Path $TestDrive 'ignored-targets'
        New-MarkdownRepoFixture -Root $root -Files @{
            'README.md' = @'
[Web](https://example.test/missing.md)
[Mail](mailto:docs@example.test)
[Protocol](//example.test/missing.md)
[Section](#not-present)
[Placeholder](#)
'@
        }

        $result = Invoke-MarkdownLinkAudit -Root $root

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -BeNullOrEmpty
    }

    It 'ignores Markdown-looking links inside fenced code blocks' {
        $root = Join-Path $TestDrive 'fenced-code'
        New-MarkdownRepoFixture -Root $root -Files @{
            'README.md' = @'
```markdown
[Not rendered](missing-in-fence.md)
```

[Rendered](missing.md)
'@
        }

        $result = Invoke-MarkdownLinkAudit -Root $root

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @("README.md`tmissing.md")
    }

    It 'writes sorted unique literal source-target pairs' {
        $root = Join-Path $TestDrive 'unresolved-pairs'
        New-MarkdownRepoFixture -Root $root -Files @{
            'docs\a.md' = @'
[Z](z.md)
[A](absent-a.md)
[Duplicate](z.md)
'@
            'README.md' = '[Same target](docs/z.md)'
        }

        $result = Invoke-MarkdownLinkAudit -Root $root

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @(
            "README.md`tdocs/z.md",
            "docs/a.md`tabsent-a.md",
            "docs/a.md`tz.md"
        )
    }

    It 'uses a baseline for CI-style failure comparison and can write that baseline' {
        $root = Join-Path $TestDrive 'baseline-comparison'
        $baselinePath = Join-Path $root '.link-baseline.txt'
        New-MarkdownRepoFixture -Root $root -Files @{
            'README.md' = @'
[Known](known.md)
[New](new.md)
'@
        }
        Set-Content -LiteralPath $baselinePath -Value "README.md`tknown.md" -Encoding utf8

        $comparison = Invoke-MarkdownLinkAudit -Root $root -Arguments @(
            '-BaselinePath', $baselinePath, '-FailOnUnresolved'
        )
        $comparison.ExitCode | Should -Be 1
        $comparison.Pairs | Should -Be @(
            "README.md`tknown.md",
            "README.md`tnew.md"
        )

        $writtenBaseline = Join-Path $root 'written-baseline.txt'
        $writeResult = Invoke-MarkdownLinkAudit -Root $root -Arguments @(
            '-BaselinePath', $writtenBaseline, '-WriteBaseline'
        )
        $writeResult.ExitCode | Should -Be 0
        Get-Content -LiteralPath $writtenBaseline | Should -Be @(
            "README.md`tknown.md",
            "README.md`tnew.md"
        )

        $passingComparison = Invoke-MarkdownLinkAudit -Root $root -Arguments @(
            '-BaselinePath', $writtenBaseline, '-FailOnUnresolved'
        )
        $passingComparison.ExitCode | Should -Be 0
    }
}
