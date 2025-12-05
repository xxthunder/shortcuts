#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.2.0'}
#Requires -Modules @{ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.18.0'}

param(
    [Parameter(Mandatory = $true)]
    [string[]]$TestPath,
    [string]$ReportPath = (Join-Path $PSScriptRoot "..\out\TestResults.xml"),
    [string]$Verbosity = 'Detailed',
    [string]$Filter
)

$ErrorActionPreference = 'Stop'

# Validate provided test paths
if ($TestPath) {
    $invalidPaths = @()
    $repoRoot = Join-Path $PSScriptRoot "..\.."
    foreach ($path in $TestPath) {
        $resolvedPath = if ([System.IO.Path]::IsPathRooted($path)) {
            $path
        } else {
            Join-Path $repoRoot $path
        }

        if (-not (Test-Path $resolvedPath)) {
            $invalidPaths += $path
        }
    }

    if ($invalidPaths.Count -gt 0) {
        Write-Host "Error: The following test paths do not exist:" -ForegroundColor Red
        foreach ($invalid in $invalidPaths) {
            Write-Host "  - $invalid" -ForegroundColor Red
        }
        exit 1
    }
}

# Display test path(s)
if ($TestPath.Count -eq 1) {
    Write-Output "Running tests in: $($TestPath[0])"
} else {
    Write-Output "Running tests in $($TestPath.Count) path(s):"
    foreach ($path in $TestPath) {
        Write-Output "  - $path"
    }
}

# Configure PSScriptAnalyzer via linter.Tests.ps1
Write-Output "`nConfiguring PSScriptAnalyzer..."
$linterTestPath = Join-Path $PSScriptRoot "linter.Tests.ps1"

# Pass test paths to linter via environment variable
$env:PESTER_LINT_PATHS = $TestPath -join ';'
Write-Output "Paths to analyze: $($env:PESTER_LINT_PATHS)"

# Add linter tests to run before regular tests
$TestPath = @($linterTestPath) + $TestPath
Write-Output "Linter tests will run from: $linterTestPath"

# Ensure output directory exists
$reportDir = Split-Path $ReportPath -Parent
if (-not (Test-Path $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}

# Configure Pester
$testConfig = New-PesterConfiguration -Hashtable @{
    Run    = @{
        Path     = $TestPath
        PassThru = $true
    }
    Filter = @{
        Tag = $Filter
    }
    Output = @{
        Verbosity = $Verbosity
    }
    TestResult = @{
        Enabled      = $true
        OutputPath   = $ReportPath
        OutputFormat = 'JUnitXml'
    }
}

Write-Output "Starting Pester tests..."
Write-Output "PowerShell: $($PSVersionTable.PSVersion)"

$testResult = Invoke-Pester -Configuration $testConfig

# Cleanup environment variable
if ($env:PESTER_LINT_PATHS) {
    Remove-Item -Path "Env:\PESTER_LINT_PATHS" -ErrorAction SilentlyContinue
}

if (Test-Path $ReportPath) {
    Write-Output "Test report generated at: $ReportPath"
} else {
    Write-Warning "Test report was not generated at: $ReportPath"
}

Write-Output "`nTest Summary:"
Write-Output "  Total: $($testResult.TotalCount)"
Write-Output "  Passed: $($testResult.PassedCount)"
Write-Output "  Failed: $($testResult.FailedCount)"
Write-Output "  Skipped: $($testResult.SkippedCount)"

if ($testResult.FailedCount -gt 0) {
    Write-Error "Tests failed! Failed count: $($testResult.FailedCount)"
}

Exit $testResult.FailedCount
