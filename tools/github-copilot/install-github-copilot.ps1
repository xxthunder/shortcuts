#Requires -Version 5.1

<#
.SYNOPSIS
    Installs or updates GitHub Copilot CLI via npm.

.DESCRIPTION
    This script ensures Node.js is installed/updated using Scoop, then installs or updates
    the GitHub Copilot CLI tool via npm. Works in both interactive and CI environments.

.EXAMPLE
    .\install-github-copilot.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install-github-copilot.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

. $PSScriptRoot\..\pslib\utils\utils.ps1

#region Main Logic

try {
    Install-NpmPackage -PackageName "@github/copilot" -CheckCommand "copilot"

    Write-Information ""
    Write-Success "Installation complete!"
    Write-Information ""
    Write-Information "You can now run: copilot"
    Write-Information ""
    Write-Information "Remember to refresh Keypirinha catalog:"
    Write-Information "  Press Win+Alt+Space and type 'Refresh catalog'"

} catch {
    Write-ErrorMsg "Installation failed: $_"
    exit 1
} finally {
    if (-not (Test-RunningInCIorTestEnvironment)) {
        Write-Information ""
        Write-Information "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    Write-Information ""
}

#endregion
