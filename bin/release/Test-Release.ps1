#Requires -Version 7.4

<#
.SYNOPSIS
    Check that a built release tree is complete and loads.

.DESCRIPTION
    Two checks on the tree built by Build-Release.ps1:
    1. Every literal script reference ($PSScriptRoot\x, Join-Path $PSScriptRoot "x"
       in .ps1 files, %~dp0x in .bat files) points to a file in the tree.
    2. The library entry points dot-source in a clean pwsh and define the
       functions the tools call.
    Each problem is printed on its own line; the script exits 1 on any problem.

.PARAMETER Path
    Root of the release tree. Required unless the script is dot-sourced in
    library mode (a mandatory parameter would make the dot-source prompt).

.EXAMPLE
    .\Test-Release.ps1 -Path C:\temp\release
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Dependencies ---------------------------------------------------------
. "$PSScriptRoot\..\..\lib\utils\utils.ps1"

# --- Functions ------------------------------------------------------------

function Get-MissingScriptReference {
    <#
    .SYNOPSIS
        Name every literal script reference that does not exist in the tree.
    .OUTPUTS
        [string[]] entries "<file relative to Root>: <reference as written>".
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $patterns = @{
        '.ps1' = @('\$PSScriptRoot\\([^"'']+)["'']', 'Join-Path\s+\$PSScriptRoot\s+["'']([^"'']+)["'']')
        '.bat' = @('%~dp0([^"\s]+)')
    }

    $missing = [System.Collections.Generic.List[string]]::new()
    $files = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force |
        Where-Object { $patterns.ContainsKey($_.Extension.ToLowerInvariant()) }

    foreach ($file in $files) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        $relative = $file.FullName.Substring($rootFull.Length + 1)
        foreach ($pattern in $patterns[$file.Extension.ToLowerInvariant()]) {
            foreach ($match in [regex]::Matches($text, $pattern)) {
                $reference = $match.Groups[1].Value
                if ($reference.Contains('$') -or $reference.Contains('%')) { continue }
                $target = Join-Path $file.DirectoryName $reference
                if (-not (Test-Path -LiteralPath $target)) {
                    $missing.Add("${relative}: $reference")
                }
            }
        }
    }

    return $missing.ToArray()
}

function Test-ReleaseLoad {
    <#
    .SYNOPSIS
        Run load-check.ps1 on the tree in a child pwsh.
    .DESCRIPTION
        The child process sees only the functions of the release tree. Throws
        with the child's output when a function is missing or the dot-sourcing
        fails.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root)
    $pwsh = (Get-Process -Id $PID).Path
    $output = & $pwsh -NoProfile -File (Join-Path $PSScriptRoot 'load-check.ps1') -Root $rootFull 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "The release tree does not load:`n$output"
    }
}

function Invoke-TestReleaseMain {
    <#
    .SYNOPSIS
        Run both checks on the tree and report each problem.
    .OUTPUTS
        [int] exit code: 0 when the tree is complete and loads, 1 when -Path is
        missing or a check finds a problem.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path
    )

    if (-not $Path) {
        Write-ErrorMsg 'Parameter -Path is required.'
        return 1
    }

    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in @(Get-MissingScriptReference -Root $Path)) {
        $problems.Add("Missing file: $entry")
    }
    try { Test-ReleaseLoad -Root $Path }
    catch { $problems.Add($_.Exception.Message) }

    if ($problems.Count -gt 0) {
        $problems | ForEach-Object { Write-ErrorMsg $_ }
        return 1
    }
    Write-Success "Release tree is complete and loads: $Path"
    return 0
}

# --- Main -----------------------------------------------------------------
if (-not $env:TESTRELEASE_LIBRARY_MODE) {
    exit (Invoke-TestReleaseMain -Path $Path)
}
