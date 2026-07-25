<#
.SYNOPSIS
    Scoop Update Helper - Interactive tool to update Scoop packages.

.DESCRIPTION
    Refreshes Scoop, then loops: lists updatable apps and lets you select apps
    to update, refresh the buckets ([R]), or quit ([Q]). Scoop failures are
    shown and control returns to the menu, so the session never exits on error.

    Runs under Windows PowerShell 5.1 (launched via update-scoop.bat in a classic
    console) so that pwsh and Windows Terminal can be updated while it runs. All
    logic lives in lib/scoop/scoop.ps1; this script is a thin wrapper.

.EXAMPLE
    .\update-scoop.ps1
    Starts the interactive Scoop update helper.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive tool requires console output for the fatal-error message')]
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\..\lib\scoop\scoop.ps1"

try {
    Invoke-ScoopUpdate
}
catch {
    Write-Host "Fatal error: $_" -ForegroundColor Red
    exit 1
}
