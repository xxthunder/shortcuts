#Requires -Version 7.4

<#
.SYNOPSIS
    Build the release tree from an allow-list.

.DESCRIPTION
    Copies the files users need (listed in paths.txt) from the source tree into
    an empty destination folder, keeping their relative paths, and writes the
    release README (bin/release/README.md) as README.md at the root. CI runs this
    from develop to build the orphan branch 'release'.

    paths.txt format: one entry per line; '#' starts a comment; blank lines are
    ignored; an entry ending in '/' is a folder taken recursively; an entry
    starting with '!' is a wildcard pattern (matched with -like against the
    relative path with '/' separators and against the file name) that removes
    files.

.PARAMETER SourceRoot
    Root of the tree to take files from. Defaults to the repository root.

.PARAMETER Destination
    Folder to build the release tree in. Must be empty or not exist. Required
    unless the script is dot-sourced in library mode (a mandatory parameter
    would make the dot-source prompt).

.EXAMPLE
    .\Build-Release.ps1 -Destination C:\temp\release
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\..'),

    [Parameter(Mandatory = $false)]
    [string]$Destination
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Dependencies ---------------------------------------------------------
. "$PSScriptRoot\..\..\lib\utils\utils.ps1"

# --- Functions ------------------------------------------------------------

function Get-ReleasePath {
    <#
    .SYNOPSIS
        Expand the allow-list into the file paths of the release tree.
    .OUTPUTS
        [string[]] paths relative to SourceRoot, with '\' as separator, sorted.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ListPath,

        [Parameter(Mandatory = $true)]
        [string]$SourceRoot
    )

    $root = [System.IO.Path]::GetFullPath($SourceRoot).TrimEnd('\', '/')
    $entries = Get-Content -LiteralPath $ListPath |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') }

    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $exclusions = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $entries) {
        if ($entry.StartsWith('!')) {
            $exclusions.Add($entry.Substring(1))
            continue
        }

        $target = Join-Path $root $entry.TrimEnd('/')
        if ($entry.EndsWith('/')) {
            if (-not (Test-Path -LiteralPath $target -PathType Container)) {
                throw "Listed path does not exist: $entry"
            }
            $found = Get-ChildItem -LiteralPath $target -Recurse -File -Force
        }
        else {
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                throw "Listed path does not exist: $entry"
            }
            $found = Get-Item -LiteralPath $target -Force
        }

        foreach ($file in $found) {
            [void]$files.Add($file.FullName.Substring($root.Length + 1))
        }
    }

    $kept = [System.Collections.Generic.List[string]]::new()
    foreach ($path in $files) {
        $slashPath = $path.Replace('\', '/')
        $name = [System.IO.Path]::GetFileName($path)
        $excluded = $false
        foreach ($pattern in $exclusions) {
            if ($slashPath -like $pattern -or $name -like $pattern) {
                $excluded = $true
                break
            }
        }
        if (-not $excluded) { $kept.Add($path) }
    }

    $result = $kept.ToArray()
    [Array]::Sort($result, [System.StringComparer]::Ordinal)
    return $result
}

function Copy-ReleaseTree {
    <#
    .SYNOPSIS
        Copy the release files to Destination and write the release README.
    .OUTPUTS
        [int] number of files in the release tree, README included.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string]$ListPath,

        [Parameter(Mandatory = $true)]
        [string]$ReadmePath
    )

    if ((Test-Path -LiteralPath $Destination) -and
        (Get-ChildItem -LiteralPath $Destination -Force | Select-Object -First 1)) {
        throw "Destination is not empty: $Destination"
    }

    $paths = @(Get-ReleasePath -ListPath $ListPath -SourceRoot $SourceRoot)
    foreach ($path in $paths) {
        $target = Join-Path $Destination $path
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $SourceRoot $path) -Destination $target
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -LiteralPath $ReadmePath -Destination (Join-Path $Destination 'README.md') -Force

    return $paths.Count + 1
}

function Invoke-BuildReleaseMain {
    <#
    .SYNOPSIS
        Build the release tree and report the result.
    .OUTPUTS
        [int] exit code: 0 on success, 1 when -Destination is missing or the
        build fails.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $false)]
        [string]$Destination
    )

    if (-not $Destination) {
        Write-ErrorMsg 'Parameter -Destination is required.'
        return 1
    }

    try {
        Write-Status "Building the release tree in $Destination"
        $count = Copy-ReleaseTree -SourceRoot $SourceRoot -Destination $Destination `
            -ListPath (Join-Path $PSScriptRoot 'paths.txt') `
            -ReadmePath (Join-Path $PSScriptRoot 'README.md')
        Write-Success "Release tree built: $count files"
        return 0
    }
    catch {
        Write-ErrorMsg $_.Exception.Message
        return 1
    }
}

# --- Main -----------------------------------------------------------------
if (-not $env:BUILDRELEASE_LIBRARY_MODE) {
    exit (Invoke-BuildReleaseMain -SourceRoot $SourceRoot -Destination $Destination)
}
