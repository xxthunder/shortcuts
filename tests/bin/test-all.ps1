#Requires -Version 5.1

<#
.SYNOPSIS
    Runs all tests in the tools directory with detailed output.

.DESCRIPTION
    Convenience wrapper script that executes test.ps1 with the tools directory
    as the test path and increased verbosity for detailed test output.

.EXAMPLE
    pwsh -File tests/bin/test-all.ps1

    Runs all tests found in the tools directory.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testScript = Join-Path $PSScriptRoot "test.ps1"
$testPath = ".\tools"

& $testScript -TestPath $testPath -Verbosity 'Detailed'

exit $LASTEXITCODE
