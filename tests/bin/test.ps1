#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}
#Requires -Modules @{ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.24.0'}

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host is required for colored console output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File contains Unicode emojis for CI/PR summaries. UTF-8 encoding is properly handled.')]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$TestPath,
    [string]$ReportPath = (Join-Path $PSScriptRoot "..\out\TestResults.xml"),
    [string]$Verbosity = 'Detailed',
    [string]$Filter,
    [switch]$EnableCodeCoverage = $false
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

# Define files for code coverage analysis (only files with tests)
# Dynamically discover source files based on existing test files
$repoRoot = Join-Path $PSScriptRoot "..\.."
$testFiles = Get-ChildItem -Path $repoRoot -Filter "*.Tests.ps1" -Recurse

$coveragePaths = @()
foreach ($testFile in $testFiles) {
    # Infer source file name (e.g., utils.Tests.ps1 -> utils.ps1)
    $sourceName = $testFile.Name -replace '\.Tests\.ps1$', '.ps1'
    $sourcePath = Join-Path $testFile.DirectoryName $sourceName

    if (Test-Path $sourcePath) {
        $coveragePaths += $sourcePath
    }
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

# Add code coverage configuration if enabled
if ($EnableCodeCoverage) {
    $coverageXmlPath = Join-Path $reportDir "coverage.xml"
    $testConfig.CodeCoverage.Enabled = $true
    $testConfig.CodeCoverage.Path = $coveragePaths
    $testConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    $testConfig.CodeCoverage.OutputPath = $coverageXmlPath
    $testConfig.CodeCoverage.OutputEncoding = 'UTF8'

    Write-Output "`nCode coverage enabled"
    Write-Output "Coverage XML will be generated at: $coverageXmlPath"
    Write-Output "Files under coverage:"
    foreach ($path in $coveragePaths) {
        Write-Output "  - $path"
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

# Display coverage summary if enabled
if ($EnableCodeCoverage -and $testResult.CodeCoverage) {
    $coverage = $testResult.CodeCoverage

    # Pester 5.x uses different property names
    # Try to get values from available properties
    if ($null -ne $coverage.CommandsExecutedCount) {
        $coveredCommands = $coverage.CommandsExecutedCount
        $totalCommands = $coverage.CommandsAnalyzedCount
    } elseif ($null -ne $coverage.NumberOfCommandsExecuted) {
        $coveredCommands = $coverage.NumberOfCommandsExecuted
        $totalCommands = $coverage.NumberOfCommandsAnalyzed
    } else {
        # Fallback: count from Hit and Missed commands
        $coveredCommands = ($coverage.HitCommands | Measure-Object).Count
        $missedCommands = ($coverage.MissedCommands | Measure-Object).Count
        $totalCommands = $coveredCommands + $missedCommands
    }

    $coveragePercent = if ($totalCommands -gt 0) {
        [math]::Round(($coveredCommands / $totalCommands) * 100, 2)
    } else {
        0
    }

    Write-Output "`nCode Coverage Summary:"
    Write-Output "  Commands Analyzed: $totalCommands"
    Write-Output "  Commands Executed: $coveredCommands"
    Write-Output "  Coverage: $coveragePercent%"

    if (Test-Path $coverageXmlPath) {
        Write-Output "`nCoverage XML report generated at: $coverageXmlPath"
    }

    # Generate markdown summary for CI/PR comments
    $summaryPath = Join-Path $reportDir "test-summary.md"
    $testStatus = if ($testResult.FailedCount -gt 0) { '❌' } else { '✅' }
    $coverageEmoji = if ($coveragePercent -ge 80) { '✅' } elseif ($coveragePercent -ge 60) { '⚠️' } else { '❌' }

    # Calculate execution time
    $executionTime = [math]::Round($testResult.Duration.TotalSeconds, 2)

    $markdownContent = @"
# $testStatus Test Results (PowerShell $($PSVersionTable.PSVersion))

## Test Summary

| Status | Count |
|--------|-------|
| ✅ Passed | $($testResult.PassedCount) |
| ❌ Failed | $($testResult.FailedCount) |
| ⏭️ Skipped | $($testResult.SkippedCount) |
| **Total** | **$($testResult.TotalCount)** |
| ⏱️ Duration | ${executionTime}s |

## $coverageEmoji Code Coverage

| Metric | Coverage |
|--------|----------|
| Commands | $coveredCommands/$totalCommands ($coveragePercent%) |
"@

    $markdownContent | Out-File -FilePath $summaryPath -Encoding UTF8 -Force
    Write-Output "`nTest summary markdown generated at: $summaryPath"
}

Exit ($testResult.FailedCount -gt 0 ? 1 : 0)
