#Requires -Version 5.1

<#
.SYNOPSIS
    Runs all tests in the tools directory with detailed output.

.DESCRIPTION
    Convenience wrapper script that executes test.ps1 with the tools directory
    as the test path and increased verbosity for detailed test output.

.PARAMETER Coverage
    Enable code coverage analysis and generate HTML report.

.EXAMPLE
    pwsh -File test/bin/test-all.ps1

    Runs all tests found in the tools directory.

.EXAMPLE
    pwsh -File test/bin/test-all.ps1 -Coverage

    Runs all tests with code coverage analysis enabled.
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
}

if ($Coverage) {
    $params.EnableCodeCoverage = $true
}

& $testScript @params

exit $LASTEXITCODE
