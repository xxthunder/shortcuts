<#
.SYNOPSIS
    Windows PowerShell 5.1 compatibility smoke guard for the Scoop lib.

.DESCRIPTION
    Enforces docs/architecture/adr/0001-lib-powershell-5.1-compatibility.md.

    Dot-sources lib/scoop/scoop.ps1 (which sources lib/utils/utils.ps1) under
    Windows PowerShell 5.1, so any PS7-only construct fails to parse/load and the
    build breaks. Then asserts the key functions are defined and validates
    Get-ScoopUpdatableApp parsing (modern PSCustomObject and legacy text output)
    by shadow-stubbing Invoke-CommandLine, so no real 'scoop status' is invoked.

    Dependency-free (no Pester); exits non-zero on the first failure so CI fails.

.NOTES
    MUST run under Windows PowerShell 5.1 (shell: powershell), not pwsh.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Join-Path $PSScriptRoot "..\.."
$scoopLib = Join-Path $repoRoot "lib\scoop\scoop.ps1"

Write-Output "==> PowerShell version: $($PSVersionTable.PSVersion)"
if ($PSVersionTable.PSVersion.Major -ne 5) {
    throw "smoke-ps51 must run under Windows PowerShell 5.1 (found $($PSVersionTable.PSVersion))"
}

# 1. Dot-source the lib under 5.1 - catches any PS7-only parse/load regression.
. $scoopLib

# 2. Assert the key functions are defined (scoop lib + a representative util).
$expected = @(
    'Get-ScoopUpdatableApp'
    'Show-ScoopUpdatableApp'
    'Read-ScoopMenuChoice'
    'Get-ScoopHostRawUi'
    'Wait-ScoopKeyPress'
    'Invoke-ScoopBucketRefresh'
    'Update-ScoopApp'
    'Invoke-ScoopUpdate'
    'Invoke-CommandLine'
)
foreach ($fn in $expected) {
    if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
        throw "Expected function not defined after dot-sourcing under 5.1: $fn"
    }
}
Write-Output "==> All expected functions defined under 5.1"

# 3. Validate Get-ScoopUpdatableApp parsing via a shadow-stubbed Invoke-CommandLine.
#    Redefining the function in this scope overrides the dot-sourced one for
#    subsequent calls, so no real 'scoop status' runs.

# Modern scoop: structured PSCustomObject output.
function Invoke-CommandLine {
    param($CommandLine, $StopAtError, $PrintCommand, $Silent)
    $null = $CommandLine, $StopAtError, $PrintCommand, $Silent
    return @(
        [PSCustomObject]@{ Name = 'gimp'; 'Installed Version' = '3.0.8'; 'Latest Version' = '3.2.0' }
        [PSCustomObject]@{ Name = 'pwsh'; 'Installed Version' = '7.5.4'; 'Latest Version' = '7.5.5' }
    )
}
$modern = @(Get-ScoopUpdatableApp)
if ($modern.Count -ne 2) { throw "Modern parse: expected 2 apps, got $($modern.Count)" }
if ($modern[0].Name -ne 'gimp' -or $modern[0].LatestVersion -ne '3.2.0') { throw "Modern parse: unexpected first app" }
if ($modern[1].Name -ne 'pwsh') { throw "Modern parse: unexpected second app" }
Write-Output "==> Modern PSCustomObject parsing OK"

# Legacy scoop: text table output.
function Invoke-CommandLine {
    param($CommandLine, $StopAtError, $PrintCommand, $Silent)
    $null = $CommandLine, $StopAtError, $PrintCommand, $Silent
    return @(
        "Name      Installed Version  Latest Version  Missing Dependencies  Info"
        "----      -----------------  --------------  --------------------  ----"
        "7zip      24.08              24.09"
        "git       2.46.0             2.47.0"
    )
}
$legacy = @(Get-ScoopUpdatableApp)
if ($legacy.Count -ne 2) { throw "Legacy parse: expected 2 apps, got $($legacy.Count)" }
if ($legacy[0].Name -ne '7zip' -or $legacy[0].InstalledVersion -ne '24.08') { throw "Legacy parse: unexpected first app" }
if ($legacy[1].Name -ne 'git' -or $legacy[1].LatestVersion -ne '2.47.0') { throw "Legacy parse: unexpected second app" }
Write-Output "==> Legacy text parsing OK"

Write-Output "==> PS 5.1 smoke guard PASSED"
