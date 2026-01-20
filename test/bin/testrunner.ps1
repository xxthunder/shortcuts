#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}
#Requires -Modules @{ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.24.0'}

<#
.SYNOPSIS
    Runs tests based on specified test type(s) and paths.

.DESCRIPTION
    Executes Pester tests with support for filtering by type (Unit/Integration),
    custom paths, and code coverage.

    - Default search paths: 'tools' and 'test' directories.
    - Use -Unit to run only unit tests (excludes *.Integration.Tests.ps1).
    - Use -Integration to run only integration tests (*.Integration.Tests.ps1).
    - Use -TestPath to specify custom search directories or files.

.PARAMETER TestPath
    One or more paths to search for tests. Defaults to 'tools' and 'test' if not provided.

.PARAMETER Unit
    Run unit tests only (excludes integration tests).

.PARAMETER Integration
    Run integration tests only.

.PARAMETER ReportPath
    Path to generate the JUnit XML test report.

.PARAMETER Verbosity
    Pester output verbosity (e.g., 'Detailed', 'Normal', 'Minimal').

.PARAMETER Filter
    Pester test filter (Tag).

.PARAMETER ExcludePattern
    Pattern to exclude test files.

.PARAMETER Coverage
    Enable code coverage analysis and generate reports.

.EXAMPLE
    pwsh -File test/bin/testrunner.ps1 -Unit

    Runs unit tests in default paths (tools, test).

.EXAMPLE
    pwsh -File test/bin/testrunner.ps1 -Integration

    Runs integration tests in default paths.

.EXAMPLE
    pwsh -File test/bin/testrunner.ps1 -TestPath "tools/pslib"

    Runs all tests in tools/pslib.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host is required for colored console output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File contains Unicode emojis for CI/PR summaries. UTF-8 encoding is properly handled.')]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$TestPath,
    [string]$ReportPath,
    [string]$Verbosity = 'Detailed',
    [string]$Filter,
    [string]$ExcludePattern,
    [switch]$Coverage = $false,
    [switch]$Unit,
    [switch]$Integration
)

$ErrorActionPreference = 'Stop'

if (-not $ReportPath) {
    if ($PSScriptRoot) {
        $ReportPath = Join-Path $PSScriptRoot "..\out\junit.xml"
    } else {
        # Fallback if PSScriptRoot is somehow empty (e.g. interactive without context)
        $ReportPath = Join-Path (Get-Location) "..\out\junit.xml"
    }
}

# Source dependencies
. "$PSScriptRoot\lib\TestConfiguration.ps1"

if ($MyInvocation.InvocationName -ne '.') {
    $repoRoot = Join-Path $PSScriptRoot "..\.."

    try {
        $config = Get-TestConfiguration -TestPath $TestPath -RunUnit:$Unit -RunIntegration:$Integration -ExcludePattern $ExcludePattern -RepoRoot $repoRoot
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }

    $finalTestPaths = $config.TestPaths

    if (-not $finalTestPaths -or $finalTestPaths.Count -eq 0) {
        Write-Warning "No tests found to run."
        exit 0
    }

    # Display test path(s)
    if ($finalTestPaths.Count -eq 1) {
        Write-Output "Running tests in: $($finalTestPaths[0])"
    } else {
        Write-Output "Running tests in $($finalTestPaths.Count) path(s):"
        foreach ($path in $finalTestPaths) {
            # Shorten output if it's a file list
            if ($path.Contains($repoRoot)) {
                $relativePath = $path -replace [regex]::Escape($repoRoot), '.'
                Write-Output "  - $relativePath"
            } else {
                Write-Output "  - $path"
            }
        }
        if ($finalTestPaths.Count -gt 20) { Write-Output "  ... (list truncated)" }
    }

    # Configure PSScriptAnalyzer via linter.Tests.ps1
    $linterTestPath = Join-Path $PSScriptRoot "linter.Tests.ps1"

    # Pass test paths via env var like before.
    $env:PESTER_LINT_PATHS = $finalTestPaths -join ';'

    # Add linter to HEAD of test list
    $runList = @($linterTestPath) + $finalTestPaths

    # Ensure output directory exists
    $reportDir = Split-Path $ReportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }

    # Code Coverage Logic
    # Dynamically discover source files based on existing test files
    # Keeping existing logic: scan all tests in repo to decide potential coverage files
    $coveragePaths = @()
    if ($Coverage) {
        $testFiles = Get-ChildItem -Path $repoRoot -Filter "*.Tests.ps1" -Recurse

        foreach ($testFile in $testFiles) {
            $sourceName = $testFile.Name -replace '\.Tests\.ps1$', '.ps1'
            $sourcePath = Join-Path $testFile.DirectoryName $sourceName

            if (Test-Path $sourcePath) {
                $coveragePaths += $sourcePath
            }
        }
    }

    # Configure Pester
    $psVersion = $PSVersionTable.PSVersion.ToString()
    $pesterConfig = @{
        Run        = @{
            Path        = $runList
            PassThru    = $true
            ExcludePath = $config.ExcludePaths
        }
        Filter     = @{
            Tag = $Filter
        }
        Output     = @{
            Verbosity = $Verbosity
        }
        TestResult = @{
            Enabled       = $true
            OutputPath    = $ReportPath
            OutputFormat  = 'JUnitXml'
            TestSuiteName = "Pester Tests (PowerShell $psVersion)"
        }
    }

    $testConfig = New-PesterConfiguration -Hashtable $pesterConfig

    # Add code coverage configuration if enabled
    if ($Coverage) {
        $coverageXmlPath = Join-Path $reportDir "coverage.xml"
        $testConfig.CodeCoverage.Enabled = $true
        $testConfig.CodeCoverage.Path = $coveragePaths
        $testConfig.CodeCoverage.OutputFormat = 'JaCoCo'
        $testConfig.CodeCoverage.OutputPath = $coverageXmlPath
        $testConfig.CodeCoverage.OutputEncoding = 'UTF8'

        Write-Output "`nCode coverage enabled"
        Write-Output "Coverage XML will be generated at: $coverageXmlPath"
    }

    Write-Output "Starting Pester tests ..."
    if ($config.ExcludePaths) {
        Write-Output "Excluding $($config.ExcludePaths.Count) file(s) from run."
        # Uncomment for deep debugging
        # $config.ExcludePaths | ForEach-Object { Write-Output "  Exclude: $_" }
    }
    Write-Output "PowerShell: $($PSVersionTable.PSVersion)"

    $testResult = Invoke-Pester -Configuration $testConfig

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

    if ($Coverage -and $testResult.CodeCoverage) {
        $coverage = $testResult.CodeCoverage

        if ($null -ne $coverage.CommandsExecutedCount) {
            $coveredCommands = $coverage.CommandsExecutedCount
            $totalCommands = $coverage.CommandsAnalyzedCount
        } elseif ($null -ne $coverage.NumberOfCommandsExecuted) {
            $coveredCommands = $coverage.NumberOfCommandsExecuted
            $totalCommands = $coverage.NumberOfCommandsAnalyzed
        } else {
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

        $summaryPath = Join-Path $reportDir "test-summary.md"
        $testStatus = if ($testResult.FailedCount -gt 0) { '❌' } else { '✅' }
        $coverageEmoji = if ($coveragePercent -ge 80) { '✅' } elseif ($coveragePercent -ge 60) { '⚠️' } else { '❌' }
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

    if ($testResult.FailedCount -gt 0) {
        Exit 1
    } else {
        Exit 0
    }
}
