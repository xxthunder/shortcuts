#Requires -Version 5.1

<#
.SYNOPSIS
    Runs integration tests with detailed output.

.DESCRIPTION
    Convenience wrapper script that executes test.ps1 with integration test paths
    (*.Integration.Tests.ps1 files only).

.PARAMETER Coverage
    Enable code coverage analysis and generate HTML report.

.EXAMPLE
    pwsh -File test/bin/test-integration.ps1

    Runs all integration tests found in the repository.

.EXAMPLE
    pwsh -File test/bin/test-integration.ps1 -Coverage

    Runs all integration tests with code coverage analysis enabled.
#>

[CmdletBinding()]
param(
    [switch]$Coverage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testScript = Join-Path $PSScriptRoot "test.ps1"
$repoRoot = Join-Path $PSScriptRoot "..\.."

# Discover all integration test files
Write-Output "Discovering integration tests..."
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

$params = @{
    TestPath = $integrationTests
    Verbosity = 'Detailed'
}

if ($Coverage) {
    $params.EnableCodeCoverage = $true
}

& $testScript @params

exit $LASTEXITCODE
