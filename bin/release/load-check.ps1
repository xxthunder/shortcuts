#Requires -Version 7.4

<#
.SYNOPSIS
    Dot-source the library entry points of a release tree and check the functions.

.DESCRIPTION
    Test-Release.ps1 runs this in a clean child pwsh, so only the functions of
    the release tree are defined. Throws when an entry point fails to load or a
    function the tools call is absent. The stub for Format-SpectreTable makes
    lib/wsl/spectre.ps1 skip the import of PwshSpectreConsole.

.PARAMETER Root
    Root of the release tree.

.EXAMPLE
    pwsh -NoProfile -File .\load-check.ps1 -Root C:\temp\release
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Format-SpectreTable {}

. (Join-Path $Root 'lib\utils\utils.ps1')
. (Join-Path $Root 'lib\scoop\scoop.ps1')
. (Join-Path $Root 'lib\wsl\manager.ps1')

$expected = 'Invoke-WslCommand', 'Set-WslConf', 'Copy-WslDistro', 'Invoke-ScoopUpdate', 'Write-Status'
$absent = @($expected | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
if ($absent) {
    throw "Missing function after loading: $($absent -join ', ')"
}
