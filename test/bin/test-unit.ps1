#Requires -Version 5.1

<#
.SYNOPSIS
    Runs unit tests (excluding integration tests) with detailed output.

.DESCRIPTION
    Convenience wrapper script that executes test.ps1 with unit test paths,
    excluding integration tests (*.Integration.Tests.ps1 files).

.PARAMETER Coverage
    Enable code coverage analysis and generate HTML report.

.EXAMPLE
    pwsh -File test/bin/test-unit.ps1

    Runs all unit tests found in the tools and test directories.

.EXAMPLE
    pwsh -File test/bin/test-unit.ps1 -Coverage

    Runs all unit tests with code coverage analysis enabled.
#>

[CmdletBinding()]
param(
    [switch]$Coverage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testScript = Join-Path $PSScriptRoot "test.ps1"

$params = @{
    TestPath = @(".\tools", ".\test")
    Verbosity = 'Detailed'
    ExcludePattern = '*.Integration.Tests.ps1'
}

if ($Coverage) {
    $params.EnableCodeCoverage = $true
}

& $testScript @params

exit $LASTEXITCODE
