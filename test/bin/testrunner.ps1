#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}
#Requires -Modules @{ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.24.0'}

<#
.SYNOPSIS
    Runs tests based on specified test type(s) and paths.

.DESCRIPTION
    Executes Pester tests with support for filtering by type (Unit/Integration),
    custom paths, and code coverage.

    - Default search paths: 'tools', 'test', 'bin', and 'lib' directories.
    - Use -Unit to run only unit tests (excludes *.Integration.Tests.ps1).
    - Use -Integration to run only integration tests (*.Integration.Tests.ps1).
    - Use -TestPath to specify custom search directories or files.
    - Use -LintOnly to run only PSScriptAnalyzer (no tests).

.PARAMETER TestPath
    One or more paths to search for tests. Defaults to 'tools', 'test', 'bin', and 'lib' if not provided.

.PARAMETER Unit
    Run unit tests only (excludes integration tests).

.PARAMETER Integration
    Run integration tests only.

.PARAMETER LintOnly
    Run only PSScriptAnalyzer via linter.Tests.ps1 (no test files are executed).
    Composes with -Unit, -Integration, and -TestPath to lint the same files
    those modes would discover.

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
    pwsh -File test/bin/testrunner.ps1 -TestPath "lib"

    Runs all tests in lib.

.EXAMPLE
    pwsh -File test/bin/testrunner.ps1 -LintOnly

    Lints all .ps1 files in default paths (no tests run).

.EXAMPLE
    pwsh -File test/bin/testrunner.ps1 -LintOnly -TestPath "lib"

    Lints only .ps1 files under lib.

.EXAMPLE
    pwsh -File test/bin/testrunner.ps1 -LintOnly -Unit

    Lints the .ps1 files that -Unit would discover (unit test files).
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host is required for colored console output')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File contains Unicode symbols for console output. UTF-8 encoding is properly handled.')]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$TestPath,
    [string]$ReportPath,
    [ValidateSet('None', 'Minimal', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Verbosity = 'Detailed',
    [string]$Filter,
    [string]$ExcludePattern,
    [switch]$Coverage = $false,
    [switch]$Unit,
    [switch]$Integration,
    [switch]$LintOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Disable ANSI color output to prevent escape sequences (0x1B) in test output.
# This avoids Pester XML export failures on PowerShell 5.1 where ANSI escapes
# are invalid XML characters.
$env:NO_COLOR = '1'
$env:TERM = 'dumb'

# On PowerShell 7+, also disable ANSI output rendering
if ($PSVersionTable.PSVersion.Major -ge 7 -and $null -ne (Get-Variable PSStyle -ErrorAction SilentlyContinue)) {
    $PSStyle.OutputRendering = 'PlainText'
}

#region Helper Functions
function Write-Status {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Get-CoverageSummary {
    <#
    .SYNOPSIS
        Extracts coverage summary from Pester code coverage result.
    .DESCRIPTION
        Handles different Pester API versions for coverage data extraction.
    #>
    param($CoverageResult)

    if ($null -eq $CoverageResult) {
        return $null
    }

    $coveredCommands = 0
    $totalCommands = 0

    if ($null -ne $CoverageResult.CommandsExecutedCount) {
        # Pester 5.4+ API
        $coveredCommands = $CoverageResult.CommandsExecutedCount
        $totalCommands = $CoverageResult.CommandsAnalyzedCount
    } elseif ($null -ne $CoverageResult.NumberOfCommandsExecuted) {
        # Older Pester API
        $coveredCommands = $CoverageResult.NumberOfCommandsExecuted
        $totalCommands = $CoverageResult.NumberOfCommandsAnalyzed
    } else {
        # Manual calculation fallback
        $coveredCommands = ($CoverageResult.HitCommands | Measure-Object).Count
        $missedCommands = ($CoverageResult.MissedCommands | Measure-Object).Count
        $totalCommands = $coveredCommands + $missedCommands
    }

    $coveragePercent = if ($totalCommands -gt 0) {
        [math]::Round(($coveredCommands / $totalCommands) * 100, 2)
    } else {
        0
    }

    return @{
        CoveredCommands = $coveredCommands
        TotalCommands   = $totalCommands
        Percent         = $coveragePercent
    }
}

function ConvertTo-RelativeJUnitXml {
    <#
    .SYNOPSIS
        Normalizes absolute Windows paths in JUnit XML to relative forward-slash paths.
    .DESCRIPTION
        Strips the repo root prefix from testsuite name/package and testcase classname/name
        attributes, then converts backslashes to forward slashes. This enables Codecov's
        test-results-parser to properly identify test files.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Function modifies a build artifact in-place, no confirmation needed')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    # Normalize trailing separator
    $RepoRoot = $RepoRoot.TrimEnd('\', '/')
    $escapedRoot = [regex]::Escape($RepoRoot + '\')

    [xml]$xml = Get-Content $Path -Raw

    foreach ($suite in $xml.SelectNodes('//testsuite')) {
        if ($suite.HasAttribute('name')) {
            $suite.name = ($suite.name -replace $escapedRoot, '').Replace('\', '/')
        }
        if ($suite.HasAttribute('package')) {
            $suite.package = ($suite.package -replace $escapedRoot, '').Replace('\', '/')
        }
    }

    foreach ($tc in $xml.SelectNodes('//testcase')) {
        if ($tc.HasAttribute('classname')) {
            $tc.classname = ($tc.classname -replace $escapedRoot, '').Replace('\', '/')
        }
        if ($tc.HasAttribute('name')) {
            $tc.name = ($tc.name -replace $escapedRoot, '').Replace('\', '/')
        }
    }

    $xml.Save($Path)
}

function Import-XmlWithoutDtd {
    <#
    .SYNOPSIS
        Loads an XML file while ignoring DTD processing.
    .DESCRIPTION
        JaCoCo XML files include a DOCTYPE declaration referencing report.dtd.
        Under Set-StrictMode, the default [xml] cast fails to resolve properties
        when DTD processing is attempted. This function uses XmlReaderSettings
        to skip DTD validation.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $reader = [System.Xml.XmlReader]::Create($Path, $settings)
    try {
        $doc = New-Object System.Xml.XmlDocument
        $doc.Load($reader)
        return $doc
    } finally {
        $reader.Close()
    }
}

function ConvertTo-RelativeJaCoCoXml {
    <#
    .SYNOPSIS
        Normalizes Pester JaCoCo XML paths so Codecov can resolve source files.
    .DESCRIPTION
        Pester's JaCoCo output uses a common-parent-leaf prefix (e.g., "shortcuts/")
        in package and class names, and full relative paths in sourcefile names.
        Codecov constructs paths as <package>/<sourcefile>, causing path duplication.
        This function detects and strips the common prefix, and reduces sourcefile
        and class sourcefilename attributes to bare filenames.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Function modifies a build artifact in-place, no confirmation needed')]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $xml = Import-XmlWithoutDtd -Path $Path

    # Detect the common-parent-leaf prefix from the first package name.
    # Pester prepends the repo folder name (e.g., "shortcuts/") to all packages.
    $firstPkg = $xml.SelectSingleNode('//package')
    if ($null -eq $firstPkg) { return }

    $pkgName = $firstPkg.name
    # The prefix is the first path segment followed by a slash (e.g., "shortcuts/")
    $slashIndex = $pkgName.IndexOf('/')
    if ($slashIndex -lt 0) { return }

    $prefix = $pkgName.Substring(0, $slashIndex + 1)

    foreach ($pkg in $xml.SelectNodes('//package')) {
        if ($pkg.name.StartsWith($prefix)) {
            $pkg.name = [string]$pkg.name.Substring($prefix.Length)
        }
    }

    foreach ($cls in $xml.SelectNodes('//class')) {
        if ($cls.HasAttribute('name') -and $cls.name.StartsWith($prefix)) {
            $cls.name = [string]$cls.name.Substring($prefix.Length)
        }
        if ($cls.HasAttribute('sourcefilename')) {
            $cls.sourcefilename = [string](Split-Path $cls.sourcefilename -Leaf)
        }
    }

    foreach ($src in $xml.SelectNodes('//sourcefile')) {
        if ($src.HasAttribute('name')) {
            $src.name = [string](Split-Path $src.name -Leaf)
        }
    }

    $xml.Save($Path)
}
#endregion

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
    $exitCode = 0

    try {
        $config = Get-TestConfiguration -TestPath $TestPath -RunUnit:$Unit -RunIntegration:$Integration -ExcludePattern $ExcludePattern -RepoRoot $repoRoot

        $finalTestPaths = $config.TestPaths

        if (-not $finalTestPaths -or $finalTestPaths.Count -eq 0) {
            Write-Warning "No tests found to run."
            exit 0
        }

        # Display test path(s)
        if ($finalTestPaths.Count -eq 1) {
            Write-Status "Running tests in: $($finalTestPaths[0])"
        } else {
            Write-Status "Running tests in $($finalTestPaths.Count) path(s):"
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

        # Build run list: lint-only skips test files
        if ($LintOnly) {
            $runList = @($linterTestPath)
            Write-Status "Lint only — skipping tests"
        } else {
            $runList = @($linterTestPath) + $finalTestPaths
        }

        # Ensure output directory exists
        $reportDir = Split-Path $ReportPath -Parent
        if (-not (Test-Path $reportDir)) {
            New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        }

        # Define coverage paths upfront to avoid scope issues
        $coverageXmlPath = Join-Path $reportDir "coverage.xml"

        # Code Coverage Logic
        # Dynamically discover source files based on existing test files
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
            Debug      = @{
                # Disable debug output capture to avoid ANSI escape sequences in XML
                WriteDebugMessages     = $false
                WriteDebugMessagesFrom = @()
            }
            TestResult = @{
                Enabled       = $true
                OutputPath    = $ReportPath
                OutputFormat  = 'JUnitXml'
                TestSuiteName = "Pester Tests (PowerShell $psVersion)"
            }
        }

        # Add code coverage configuration if enabled
        if ($Coverage) {
            if ($coveragePaths.Count -gt 0) {
                $pesterConfig['CodeCoverage'] = @{
                    Enabled        = $true
                    Path           = $coveragePaths
                    OutputFormat   = 'JaCoCo'
                    OutputPath     = $coverageXmlPath
                    OutputEncoding = 'UTF8'
                }

                Write-Status "Code coverage enabled"
                Write-Output "Coverage XML will be generated at: $coverageXmlPath"
            } else {
                Write-Warning "Code coverage requested but no source files found to analyze."
            }
        }

        $testConfig = New-PesterConfiguration -Hashtable $pesterConfig

        Write-Status "Starting Pester tests ..."
        if ($config.ExcludePaths) {
            Write-Output "Excluding $($config.ExcludePaths.Count) file(s) from run."
        }
        Write-Output "PowerShell: $($PSVersionTable.PSVersion)"

        $testResult = Invoke-Pester -Configuration $testConfig

        if ($null -eq $testResult) {
            Write-ErrorMsg "Pester returned no results. Test execution may have failed."
            $exitCode = 1
        } else {
            if (Test-Path $ReportPath) {
                ConvertTo-RelativeJUnitXml -Path $ReportPath -RepoRoot (Resolve-Path $repoRoot).Path
                Write-Success "Test report generated at: $ReportPath"
            } else {
                Write-Warning "Test report was not generated at: $ReportPath"
            }

            Write-Output "`nTest Summary:"
            Write-Output "  Total: $($testResult.TotalCount)"
            Write-Output "  Passed: $($testResult.PassedCount)"
            Write-Output "  Failed: $($testResult.FailedCount)"
            Write-Output "  Skipped: $($testResult.SkippedCount)"

            if ($testResult.FailedCount -gt 0) {
                Write-ErrorMsg "Tests failed! Failed count: $($testResult.FailedCount)"
                $exitCode = 1
            }

            # Extract coverage metrics if available
            $coverageMetrics = $null
            if ($Coverage -and $null -ne $testResult.CodeCoverage) {
                $coverageMetrics = Get-CoverageSummary -CoverageResult $testResult.CodeCoverage

                if ($null -ne $coverageMetrics) {
                    Write-Output "`nCode Coverage Summary:"
                    Write-Output "  Commands Analyzed: $($coverageMetrics.TotalCommands)"
                    Write-Output "  Commands Executed: $($coverageMetrics.CoveredCommands)"
                    Write-Output "  Coverage: $($coverageMetrics.Percent)%"

                    if (Test-Path $coverageXmlPath) {
                        ConvertTo-RelativeJaCoCoXml -Path $coverageXmlPath
                        Write-Success "Coverage XML report generated at: $coverageXmlPath"
                    }
                }
            }

            # Clear large objects before exit to prevent serialization issues
            $testResult = $null
            $testConfig = $null
        }

    } catch {
        Write-ErrorMsg "Test runner failed: $_"
        $exitCode = 1
    } finally {
        # Cleanup environment variable
        if ($env:PESTER_LINT_PATHS) {
            Remove-Item -Path "Env:\PESTER_LINT_PATHS" -ErrorAction SilentlyContinue
        }

        # Suppress any cleanup errors from Pester
        $ErrorActionPreference = 'SilentlyContinue'
    }

    $host.SetShouldExit($exitCode)
    exit $exitCode
}
