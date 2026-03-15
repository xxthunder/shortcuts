#Requires -Version 5.1

<#
.SYNOPSIS
    Scoop Update Helper - Interactive tool to update Scoop packages.

.DESCRIPTION
    Refreshes Scoop, lists updatable apps, and lets you select which to update.
    All logic is in lib/scoop/scoop.ps1; this script is a thin wrapper.

.EXAMPLE
    .\update-scoop.ps1
    Starts the interactive Scoop update helper.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive tool requires console output for press-any-key prompt')]
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\..\..\lib\scoop\scoop.ps1"

try {
    Invoke-ScoopUpdate
} finally {
    if (-not (Test-RunningInCIorTestEnvironment)) {
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}
