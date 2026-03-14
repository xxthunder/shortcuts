#Requires -Version 5.1

<#
.SYNOPSIS
    Installs or updates a global npm package.

.DESCRIPTION
    This script ensures Node.js is installed/updated using Scoop, then installs or updates
    the specified npm package globally. Works in both interactive and CI environments.

.PARAMETER PackageName
    The name of the npm package to install (e.g., "@anthropic-ai/claude-code").

.PARAMETER CheckCommand
    Optional. A command to check after installation to verify success (e.g., "claude").
    If not provided, the package installation is considered verified if npm install succeeds.

.EXAMPLE
    .\install-npm-global.ps1 -PackageName "@anthropic-ai/claude-code" -CheckCommand "claude"

.EXAMPLE
    .\install-npm-global.ps1 -PackageName "@github/copilot" -CheckCommand "copilot"

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File install-npm-global.ps1 -PackageName "@some/package"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The npm package to install (e.g., '@anthropic-ai/claude-code')")]
    [string]$PackageName,

    [Parameter(Mandatory = $false, HelpMessage = "Optional command to verify after installation (e.g., 'claude')")]
    [string]$CheckCommand
)

Set-StrictMode -Version Latest

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

# Source utils library
. "$PSScriptRoot\..\utils\utils.ps1"

#region Main Logic

try {
    # Install the npm package
    if ($CheckCommand) {
        Install-NpmPackage -PackageName $PackageName -CheckCommand $CheckCommand
    } else {
        Install-NpmPackage -PackageName $PackageName
    }

    Write-Information ""
    Write-Success "Installation complete!"
    Write-Information ""

    if ($CheckCommand) {
        Write-Information "You can now run: $CheckCommand"
    } else {
        Write-Information "Package '$PackageName' has been installed globally"
    }

    Write-Information ""
    Write-Information "Remember to refresh Keypirinha catalog:"
    Write-Information "  Press Win+Alt+Space and type 'Refresh catalog'"

} catch {
    Write-Error "An unexpected error occurred: $_"
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
