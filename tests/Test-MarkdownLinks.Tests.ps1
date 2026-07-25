#Requires -Version 7.2

BeforeAll {
    $script:AuditPath = Resolve-Path (Join-Path $PSScriptRoot '..' 'scripts' 'Test-MarkdownLinks.ps1')

    function New-MarkdownFixture {
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
    }

    function Invoke-MarkdownLinkAudit {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [Parameter(Mandatory = $true)]
            [string[]]$Source,

            [string[]]$Arguments = @()
        )

        $output = @(& pwsh -NoProfile -File $script:AuditPath -RepoRoot $Root -Path ($Source -join ',') @Arguments)
        return @{
            ExitCode = $LASTEXITCODE
            Pairs = @($output | Where-Object { $_ -is [string] })
        }
    }
}

Describe 'Test-MarkdownLinks' {
    It 'resolves relative targets, fragments, URL-encoded names, and directories' {
        $root = Join-Path $TestDrive 'resolved-targets'
        New-MarkdownFixture -Root $root -Files @{
            'docs\guide.md' = @'
[Guide](guide/intro.md#overview)
[Encoded](encoded%20name.md)
[Directory](guide/)
'@
            'docs\guide\intro.md' = '# Intro'
            'docs\encoded name.md' = '# Encoded'
            'docs\guide\.gitkeep' = ''
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'docs/guide.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -BeNullOrEmpty
    }

    It 'ignores external, protocol-relative, fragment-only, and intentional placeholder links' {
        $root = Join-Path $TestDrive 'ignored-targets'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = @'
[Web](https://example.test/missing.md)
[Mail](mailto:docs@example.test)
[Protocol](//example.test/missing.md)
[Section](#not-present)
[Placeholder](#)
'@
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -BeNullOrEmpty
    }

    It 'ignores Markdown-looking links inside fenced code blocks' {
        $root = Join-Path $TestDrive 'fenced-code'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = @'
```markdown
[Not rendered](missing-in-fence.md)
```

[Rendered](missing.md)
'@
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @("README.md`tmissing.md")
    }

    It 'ignores source files absent from the working tree' {
        $root = Join-Path $TestDrive 'deleted-source'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = '[Missing](missing.md)'
        }
        # Matches a tracked file deleted from the working tree, which
        # git ls-files still reports.
        Remove-Item -LiteralPath (Join-Path $root 'README.md')

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -BeNullOrEmpty
    }

    It 'ignores source files that escape the repository root' {
        $parent = Join-Path $TestDrive 'source-escape'
        $root = Join-Path $parent 'repo'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = '[Present](README.md)'
        }
        Set-Content -LiteralPath (Join-Path $parent 'outside.md') `
            -Value '[Missing](absent.md)' -Encoding utf8

        $result = Invoke-MarkdownLinkAudit -Root $root -Source '../outside.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -BeNullOrEmpty
    }

    It 'writes sorted unique literal source-target pairs' {
        $root = Join-Path $TestDrive 'unresolved-pairs'
        New-MarkdownFixture -Root $root -Files @{
            'docs\a.md' = @'
[Z](z.md)
[A](absent-a.md)
[Duplicate](z.md)
'@
            'README.md' = '[Same target](docs/z.md)'
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'docs/a.md', 'README.md'

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
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = @'
[Known](known.md)
[New](new.md)
'@
        }
        Set-Content -LiteralPath $baselinePath -Value "README.md`tknown.md" -Encoding utf8

        $comparison = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md' -Arguments @(
            '-BaselinePath', $baselinePath, '-FailOnUnresolved'
        )
        $comparison.ExitCode | Should -Be 1
        $comparison.Pairs | Should -Be @(
            "README.md`tknown.md",
            "README.md`tnew.md"
        )

        $writtenBaseline = Join-Path $root 'written-baseline.txt'
        $writeResult = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md' -Arguments @(
            '-BaselinePath', $writtenBaseline, '-WriteBaseline'
        )
        $writeResult.ExitCode | Should -Be 0
        Get-Content -LiteralPath $writtenBaseline | Should -Be @(
            "README.md`tknown.md",
            "README.md`tnew.md"
        )

        $passingComparison = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md' -Arguments @(
            '-BaselinePath', $writtenBaseline, '-FailOnUnresolved'
        )
        $passingComparison.ExitCode | Should -Be 0
    }

    It 'passes -WriteBaseline -FailOnUnresolved by comparing against the just-written baseline' {
        $root = Join-Path $TestDrive 'write-and-fail'
        $baselinePath = Join-Path $root '.link-baseline.txt'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = '[Missing](missing.md)'
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md' -Arguments @(
            '-BaselinePath', $baselinePath, '-WriteBaseline', '-FailOnUnresolved'
        )

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @("README.md`tmissing.md")
        Get-Content -LiteralPath $baselinePath | Should -Be @("README.md`tmissing.md")
    }

    It 'resolves leading-slash targets from the repository root' {
        $root = Join-Path $TestDrive 'repo-root-links'
        New-MarkdownFixture -Root $root -Files @{
            'docs\nested\deep.md' = @'
[Root doc](/docs/present.md)
[Root missing](/docs/absent.md)
'@
            'docs\present.md' = '# Present'
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'docs/nested/deep.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @("docs/nested/deep.md`t/docs/absent.md")
    }

    It 'reports targets escaping the repository root as unresolved without probing outside paths' {
        $parent = Join-Path $TestDrive 'containment'
        $root = Join-Path $parent 'repo'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = @'
[Escape](../outside.md)
[Deep escape](docs/../../outside.md)
'@
        }
        # The sibling file exists, but a target outside the repo root must
        # still be unresolved: existence outside the root is never probed.
        Set-Content -LiteralPath (Join-Path $parent 'outside.md') -Value '# Outside' -Encoding utf8

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @(
            "README.md`t../outside.md",
            "README.md`tdocs/../../outside.md"
        )
    }

    It 'ignores Markdown-looking links inside inline code spans but keeps real links on the same line' {
        $root = Join-Path $TestDrive 'inline-code'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = @'
Use `[Not a link](missing-in-span.md)` as shown.
Double span: ``[Also not](missing-double.md)`` here.
Mixed: `[In span](missing-in-span.md)` and [Real](missing-real.md) after.
Unclosed backtick ` then [Still real](present.md) works.
'@
            'present.md' = '# Present'
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @("README.md`tmissing-real.md")
    }

    It 'keeps links visible around backslash-escaped backticks' {
        $root = Join-Path $TestDrive 'escaped-backticks'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = 'Escaped \` then [Real](missing-escaped.md) and \` more.'
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @("README.md`tmissing-escaped.md")
    }

    It 'ignores links inside code spans continuing across lines and keeps unmatched backticks literal' {
        $root = Join-Path $TestDrive 'multiline-spans'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = @'
Start ``code [Hidden](hidden-in-span.md)
still code`` then [After](missing-after-span.md).

A lone ` backtick and [Literal](missing-literal.md) still count.
'@
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @(
            "README.md`tmissing-after-span.md",
            "README.md`tmissing-literal.md"
        )
    }

    It 'strips query strings before resolution while reporting the literal target' {
        $root = Join-Path $TestDrive 'query-strings'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = @'
[Versioned](present.md?v=2)
[Both](present.md?v=2#section)
[Missing](absent.md?x=1#frag)
[Query only](?tab=readme)
'@
            'present.md' = '# Present'
        }

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @("README.md`tabsent.md?x=1#frag")
    }

    It 'reports existing directory link targets that resolve outside the repository root' {
        $parent = Join-Path $TestDrive 'link-escape'
        $root = Join-Path $parent 'repo'
        $outside = Join-Path $parent 'outside'
        New-Item -ItemType Directory -Path $outside -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $outside 'note.md') -Value '# Outside' -Encoding utf8
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = @'
[Escapes](linked/note.md)
[Stays](docs-link/inside.md)
'@
            'docs\inside.md' = '# Inside'
        }

        # A junction on Windows and a directory symlink elsewhere; neither
        # needs elevation, unlike a Windows file symlink.
        $directoryLinkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $directoryLinkType -Path (Join-Path $root 'linked') `
            -Target $outside -ErrorAction Stop | Out-Null
        New-Item -ItemType $directoryLinkType -Path (Join-Path $root 'docs-link') `
            -Target (Join-Path $root 'docs') -ErrorAction Stop | Out-Null

        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        $result.Pairs | Should -Be @("README.md`tlinked/note.md")
    }

    It 'honors the case sensitivity of the hosting volume for root containment' {
        $parent = Join-Path $TestDrive 'case-volume'
        $root = Join-Path $parent 'repo'
        New-MarkdownFixture -Root $root -Files @{
            'README.md' = '[Reenter](../REPO/present.md)'
            'present.md' = '# Present'
        }

        $caseInsensitiveVolume = Test-Path -LiteralPath (Join-Path $root 'PRESENT.MD')
        $result = Invoke-MarkdownLinkAudit -Root $root -Source 'README.md'

        $result.ExitCode | Should -Be 0
        if ($caseInsensitiveVolume) {
            $result.Pairs | Should -BeNullOrEmpty
        } else {
            $result.Pairs | Should -Be @("README.md`t../REPO/present.md")
        }
    }
}

Describe 'Test-MarkdownLinks helpers' {
    BeforeAll {
        # Define the script's functions without running its main body.
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            "$script:AuditPath", [ref]$tokens, [ref]$parseErrors
        )
        $functionAsts = $ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $false
        )
        foreach ($functionAst in $functionAsts) {
            . ([scriptblock]::Create($functionAst.Extent.Text))
        }
    }

    It 'contains ordinary children of a drive or filesystem root' {
        if ($IsWindows) {
            Test-PathWithinRoot -Path 'C:\docs\a.md' -RootPath 'C:\' | Should -BeTrue
            Test-PathWithinRoot -Path 'C:\' -RootPath 'C:\' | Should -BeTrue
        } else {
            Test-PathWithinRoot -Path '/docs/a.md' -RootPath '/' | Should -BeTrue
            Test-PathWithinRoot -Path '/' -RootPath '/' | Should -BeTrue
        }
    }

    It 'contains ordinary children of a UNC share root without probing the network' -Skip:(-not $IsWindows) {
        Test-PathWithinRoot -Path '\\server\share\docs\a.md' -RootPath '\\server\share\' | Should -BeTrue
        Test-PathWithinRoot -Path '\\server\other\doc.md' -RootPath '\\server\share\' | Should -BeFalse
    }

    It 'rejects rooted results and parent escapes without rejecting children' {
        $root = Join-Path $TestDrive 'containment-unit'
        New-Item -ItemType Directory -Path (Join-Path $root 'child') -Force | Out-Null

        Test-PathWithinRoot -Path (Join-Path $root 'child\doc.md') -RootPath $root | Should -BeTrue
        Test-PathWithinRoot -Path (Join-Path $TestDrive 'outside.md') -RootPath $root | Should -BeFalse
        $escapePath = [System.IO.Path]::GetFullPath((Join-Path $root '..\sibling\doc.md'))
        Test-PathWithinRoot -Path $escapePath -RootPath $root | Should -BeFalse
    }

    It 'detects the case sensitivity of the hosting volume and caches it per root' {
        $root = Join-Path $TestDrive 'case-unit'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'probe.txt') -Value 'probe' -Encoding utf8
        $expected = if (Test-Path -LiteralPath (Join-Path $root 'PROBE.TXT')) {
            [System.StringComparison]::OrdinalIgnoreCase
        } else {
            [System.StringComparison]::Ordinal
        }

        Get-PathCaseComparison -RootPath $root | Should -Be $expected

        $cacheKey = [System.IO.Path]::TrimEndingDirectorySeparator([System.IO.Path]::GetFullPath($root))
        $script:PathCaseComparisonCache.ContainsKey($cacheKey) | Should -BeTrue
        Get-PathCaseComparison -RootPath $root | Should -Be $expected
    }

    It 'leaves no case probe behind in the probed root' {
        $root = Join-Path $TestDrive 'probe-cleanup'
        New-Item -ItemType Directory -Path $root -Force | Out-Null

        $null = Get-PathCaseComparison -RootPath $root

        Get-ChildItem -LiteralPath $root -Force | Should -BeNullOrEmpty
    }

    It 'treats escaped backticks as literal text and removes spans across lines' {
        $escaped = 'a \` [L](x.md) \` c'
        Remove-InlineCodeSpans -Text $escaped | Should -Be $escaped

        $multiline = 'span `hide [H](h.md)' + "`n" + 'still` [After](a.md)'
        $cleaned = Remove-InlineCodeSpans -Text $multiline
        $cleaned | Should -Not -Match '\[H\]'
        ($cleaned -split "`n")[1] | Should -Match '\[After\]'

        $unmatched = 'lone ` backtick [Real](r.md)'
        Remove-InlineCodeSpans -Text $unmatched | Should -Be $unmatched
    }

    It 'splits the NUL-separated tracked corpus and keeps only existing files' {
        $root = Join-Path $TestDrive 'tracked-corpus'
        New-Item -ItemType Directory -Path (Join-Path $root 'docs') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'README.md') -Value '# Present' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $root 'docs\space name.md') -Value '# Present' -Encoding utf8
        Mock git {
            $global:LASTEXITCODE = 0
            return "README.md`0docs/space name.md`0docs/deleted.md`0"
        }

        $sources = Get-MarkdownSourceFiles -Root $root

        Should -Invoke git -Times 1 -Exactly
        $sources | Should -Be @('README.md', 'docs/space name.md')
    }

    It 'throws when the tracked corpus cannot be listed' {
        $root = Join-Path $TestDrive 'tracked-corpus-failure'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Mock git {
            $global:LASTEXITCODE = 128
            return $null
        }

        { Get-MarkdownSourceFiles -Root $root } | Should -Throw "*Could not list tracked Markdown files*"
    }

    It 'never consults the tracked corpus when explicit paths are requested' {
        $root = Join-Path $TestDrive 'explicit-corpus'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'README.md') -Value '# Present' -Encoding utf8
        Mock git { throw 'git must not be called for explicit paths.' }

        Get-MarkdownSourceFiles -Root $root -ExplicitPaths 'README.md' -UseExplicitPaths |
            Should -Be @('README.md')
        # An explicitly empty corpus stays empty instead of falling back to git.
        Get-MarkdownSourceFiles -Root $root -ExplicitPaths @() -UseExplicitPaths |
            Should -BeNullOrEmpty
        Should -Invoke git -Times 0 -Exactly
    }

    It 'follows a file link to its final target when deciding root containment' {
        # A Windows file symlink needs elevation to create, so the reparse
        # point is described to Get-Item rather than laid down on disk.
        $parent = Join-Path $TestDrive 'file-link-unit'
        $root = Join-Path $parent 'repo'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $aliasPath = Join-Path $root 'alias.md'
        Set-Content -LiteralPath $aliasPath -Value '# Alias' -Encoding utf8
        $insidePath = Join-Path $root 'inside.md'
        Set-Content -LiteralPath $insidePath -Value '# Inside' -Encoding utf8
        $insideTargetPath = Join-Path $root 'inside-target.md'
        Set-Content -LiteralPath $insideTargetPath -Value '# Inside target' -Encoding utf8

        function New-LinkItemStub {
            param([string]$TargetPath)

            $stub = [pscustomobject]@{ LinkType = 'SymbolicLink' }
            $stub | Add-Member -MemberType ScriptMethod -Name ResolveLinkTarget -Value {
                [pscustomobject]@{ FullName = $TargetPath }
            }.GetNewClosure()
            return $stub
        }

        Mock Get-Item { New-LinkItemStub -TargetPath (Join-Path $parent 'outside.md') } `
            -ParameterFilter { $LiteralPath -eq $aliasPath }
        Mock Get-Item { New-LinkItemStub -TargetPath $insideTargetPath } `
            -ParameterFilter { $LiteralPath -eq $insidePath }

        Get-PhysicalPath -Path $aliasPath | Should -Be (Join-Path $parent 'outside.md')
        Test-PhysicalPathWithinRoot -Path $aliasPath -RootPath $root | Should -BeFalse
        Test-PhysicalPathWithinRoot -Path $insidePath -RootPath $root | Should -BeTrue
    }
}
