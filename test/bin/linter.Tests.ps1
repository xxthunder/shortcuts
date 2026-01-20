<#
.SYNOPSIS
    PSScriptAnalyzer linting tests for PowerShell scripts.

.DESCRIPTION
    Analyzes PowerShell scripts using PSScriptAnalyzer rules.
    Paths to analyze are provided via PESTER_LINT_PATHS environment variable
    (semicolon-separated list). Falls back to test/bin directory if not set.

.NOTES
    This test file is typically invoked by testrunner.ps1, not run directly.
#>

#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.2.0'}
#Requires -Modules @{ModuleName = 'PSScriptAnalyzer'; ModuleVersion = '1.18.0'}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeDiscovery {
    # Check if paths are provided via environment variable
    if ($env:PESTER_LINT_PATHS) {
        $paths = $env:PESTER_LINT_PATHS -split ';'
        $repoRoot = Join-Path $PSScriptRoot "..\..\"

        $toBeAnalysed = @()
        foreach ($path in $paths) {
            $resolvedPath = if ([System.IO.Path]::IsPathRooted($path)) {
                $path
            } else {
                Join-Path $repoRoot $path
            }

            if (Test-Path $resolvedPath -PathType Container) {
                $files = Get-ChildItem -Path $resolvedPath -Filter "*.ps1" -Recurse
                if ($files) {
                    $toBeAnalysed += $files.FullName
                }
            } elseif (Test-Path $resolvedPath -PathType Leaf) {
                if ($resolvedPath -like "*.ps1") {
                    $toBeAnalysed += $resolvedPath

                    # If targeting a test file directly, also lint the associated implementation file
                    if ($resolvedPath -match '\.Tests\.ps1$') {
                        $implPath = $resolvedPath -replace '\.Tests\.ps1$', '.ps1'
                        if (Test-Path $implPath) {
                            $toBeAnalysed += $implPath
                        }
                    }
                }
            }
        }
    } else {
        # Fallback to default behavior
        $toBeAnalysed = @()
        $files = Get-ChildItem -Path $PSScriptRoot -Depth 0 -Filter "*.ps1"
        if ($files) {
            $toBeAnalysed += $files.FullName
        }
        $files = Get-ChildItem -Path "$PSScriptRoot\.." -Depth 0 -Filter "*.ps1"
        if ($files) {
            $toBeAnalysed += $files.FullName
        }
    }
}

Describe 'Analysis of file <_> against Script Analyzer Rules' -ForEach $toBeAnalysed {
    It "Shall not have deviations" {
        $analysisRules = Get-ScriptAnalyzerRule -Severity Warning, Error
        $analysisResult = Invoke-ScriptAnalyzer -IncludeRule $analysisRules -Path $_
        if ($analysisResult) {
            $ScriptAnalyzerResultString = $analysisResult | Out-String
            Write-Warning $ScriptAnalyzerResultString
        }
        $analysisResult | Should -BeNullOrEmpty
    }
}
