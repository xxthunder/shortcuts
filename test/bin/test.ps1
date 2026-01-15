#Requires -Version 5.1

<#
.SYNOPSIS
    Runs tests based on specified test type(s).

.DESCRIPTION
    Wrapper script that executes testrunner.ps1 with appropriate parameters
    based on the test type switches provided.

    - Use -Unit to run only unit tests (excludes *.Integration.Tests.ps1)
    - Use -Integration to run only integration tests (*.Integration.Tests.ps1)
    - Use both switches or neither to run all tests

.PARAMETER Unit
    Run unit tests only (excludes integration tests).

.PARAMETER Integration
    Run integration tests only.

.PARAMETER Coverage
    Enable code coverage analysis and generate reports.

.EXAMPLE
    pwsh -File test/bin/test.ps1 -Unit

    Runs only unit tests (excludes *.Integration.Tests.ps1 files).

.EXAMPLE
    pwsh -File test/bin/test.ps1 -Integration

    Runs only integration tests (*.Integration.Tests.ps1 files).

.EXAMPLE
    pwsh -File test/bin/test.ps1

    Runs all tests (both unit and integration).

.EXAMPLE
    pwsh -File test/bin/test.ps1 -Unit -Integration -Coverage

    Runs all tests with code coverage enabled.
#>

[CmdletBinding()]
param(
    [switch]$Unit,
    [switch]$Integration,
    [switch]$Coverage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testRunnerScript = Join-Path $PSScriptRoot "testrunner.ps1"
$repoRoot = Join-Path $PSScriptRoot "..\.."

# Determine which tests to run
$runUnitOnly = $Unit -and -not $Integration
$runIntegrationOnly = $Integration -and -not $Unit

# Build parameters for testrunner
$params = @{
    Verbosity = 'Detailed'
}

if ($runUnitOnly) {
    # Unit tests only: exclude integration tests
    $params.TestPath = @(".\tools", ".\test")
    $params.ExcludePattern = '*.Integration.Tests.ps1'
} elseif ($runIntegrationOnly) {
    # Integration tests only: discover and use integration test files
    Write-Output "Discovering integration tests ..."
    $integrationTests = @(Get-ChildItem -Path $repoRoot -Filter "*.Integration.Tests.ps1" -Recurse |
        Select-Object -ExpandProperty FullName)

    if ($integrationTests.Count -eq 0) {
        Write-Warning "No integration tests found matching pattern: *.Integration.Tests.ps1"
        Write-Output "Integration test discovery complete: 0 test files found"
        exit 0
    }

    Write-Output "Found $($integrationTests.Count) integration test file(s):"
    foreach ($test in $integrationTests) {
        $relativePath = $test -replace [regex]::Escape($repoRoot), '.'
        Write-Output "  - $relativePath"
    }
    Write-Output ""

    $params.TestPath = $integrationTests
} else {
    # Run all tests: no exclusions
    $params.TestPath = @(".\tools", ".\test")
}

# Add coverage if requested
if ($Coverage) {
    $params.EnableCodeCoverage = $true
}

# Execute testrunner once with configured parameters
& $testRunnerScript @params

exit $LASTEXITCODE
