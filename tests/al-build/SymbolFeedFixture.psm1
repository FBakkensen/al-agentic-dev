#Requires -Version 7.2

<#
.SYNOPSIS
    Builds a local symbol feed for Pester: flat2 feed roots of .nupkg packages, each holding a
    .nuspec and a real-format .app.

.DESCRIPTION
    A real-format .app is a 40-byte NAVX header in front of a zip. The zip holds
    NavxManifest.xml with the app's id, name, publisher, and 4-part version. The package's
    NuGet version and the manifest's version are set apart, so a test can build a 26.1.9
    package around a 26.1.9.0 manifest, as NuGet trims the trailing zero.

    Import it from a test's BeforeAll. Its file name does not end in .Tests.ps1, so Pester
    does not run it.
#>

Set-StrictMode -Version Latest

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

function Add-ZipTextEntry {
    param(
        [Parameter(Mandatory)][System.IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Content
    )

    $entry = $Archive.CreateEntry($Name)
    $writer = [System.IO.StreamWriter]::new($entry.Open(), [System.Text.UTF8Encoding]::new($false))
    try { $writer.Write($Content) } finally { $writer.Dispose() }
}

function New-FixtureAppFile {
    <#
    .SYNOPSIS
        Writes a real-format .app file: a NAVX header in front of a zip with NavxManifest.xml.
    .PARAMETER Version
        The manifest's version, written exactly as given (for example 26.1.9.0).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Publisher,
        [Parameter(Mandatory)][string]$Version
    )

    $escape = { param([string]$Value) [System.Security.SecurityElement]::Escape($Value) }
    $manifest = @(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<Package xmlns="http://schemas.microsoft.com/navx/2015/manifest">'
        ('  <App Id="{0}" Name="{1}" Publisher="{2}" Version="{3}" Brief="" Description="" Privacy="" EULA="" Help="" Url="" Logo="" Platform="26.0.0.0" Application="26.0.0.0" Runtime="15.0" />' -f
            (& $escape $Id), (& $escape $Name), (& $escape $Publisher), (& $escape $Version))
        '</Package>'
    ) -join "`n"

    $zipStream = [System.IO.MemoryStream]::new()
    $archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        Add-ZipTextEntry -Archive $archive -Name 'NavxManifest.xml' -Content $manifest
        Add-ZipTextEntry -Archive $archive -Name 'src/Placeholder.al' -Content 'codeunit 50100 Placeholder { }'
    } finally {
        $archive.Dispose()
    }
    $zipBytes = $zipStream.ToArray()

    # NAVX, header length (40), format version, package GUID, content length, reserved, NAVX.
    $header = [System.IO.MemoryStream]::new()
    $headerWriter = [System.IO.BinaryWriter]::new($header)
    $headerWriter.Write([byte[]](0x4E, 0x41, 0x56, 0x58))
    $headerWriter.Write([int]40)
    $headerWriter.Write([int]2)
    $headerWriter.Write([guid]::NewGuid().ToByteArray())
    $headerWriter.Write([int]$zipBytes.Length)
    $headerWriter.Write([int]0)
    $headerWriter.Write([byte[]](0x4E, 0x41, 0x56, 0x58))
    $headerWriter.Flush()

    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllBytes($Path, [byte[]]($header.ToArray() + $zipBytes))
    return $Path
}

function New-FixtureFeedPackage {
    <#
    .SYNOPSIS
        Writes one package into a flat2 feed root and lists its version in the package's index.json.
    .PARAMETER NuGetVersion
        The package's NuGet version, the one in flat2/<id>/<version>/.
    .PARAMETER App
        The .app inside the package: Id, Name, Publisher, and Version (the manifest's 4-part version).
    .PARAMETER Dependencies
        The .nuspec dependencies: hashtables with Id and Version (the minimum version).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FeedRoot,
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string]$NuGetVersion,
        [Parameter(Mandatory)][hashtable]$App,
        [hashtable[]]$Dependencies = @()
    )

    $idLower = $PackageId.ToLowerInvariant()
    $packageDir = Join-Path -Path $FeedRoot -ChildPath (Join-Path 'flat2' (Join-Path $idLower $NuGetVersion))
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

    $appPath = Join-Path -Path $packageDir -ChildPath 'staged.app'
    New-FixtureAppFile -Path $appPath -Id $App.Id -Name $App.Name -Publisher $App.Publisher -Version $App.Version | Out-Null

    $dependencyXml = ($Dependencies | ForEach-Object {
        '      <dependency id="{0}" version="{1}" />' -f $_.Id, $_.Version
    }) -join "`n"
    $nuspec = @(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">'
        '  <metadata>'
        "    <id>$PackageId</id>"
        "    <version>$NuGetVersion</version>"
        '    <authors>fixture</authors>'
        '    <description>Fixture symbol package</description>'
        '    <dependencies>'
        $dependencyXml
        '    </dependencies>'
        '  </metadata>'
        '</package>'
    ) -join "`n"

    $nupkgPath = Join-Path -Path $packageDir -ChildPath "$idLower.$NuGetVersion.nupkg"
    $archive = [System.IO.Compression.ZipFile]::Open($nupkgPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        Add-ZipTextEntry -Archive $archive -Name "$PackageId.nuspec" -Content $nuspec
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $appPath, "$($App.Name).app") | Out-Null
    } finally {
        $archive.Dispose()
    }
    Remove-Item -LiteralPath $appPath -Force

    $indexPath = Join-Path -Path $FeedRoot -ChildPath (Join-Path 'flat2' (Join-Path $idLower 'index.json'))
    $versions = @()
    if (Test-Path -LiteralPath $indexPath) {
        $versions = @((Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Json).versions)
    }
    if ($versions -notcontains $NuGetVersion) { $versions += $NuGetVersion }
    [ordered]@{ versions = @($versions) } | ConvertTo-Json | Set-Content -LiteralPath $indexPath -Encoding UTF8

    return $nupkgPath
}

Export-ModuleMember -Function @(
    'New-FixtureAppFile'
    'New-FixtureFeedPackage'
)
