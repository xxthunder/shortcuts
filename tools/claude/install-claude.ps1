#Requires -Version 5.1

<#
.SYNOPSIS
    Installs or updates Node.js via Scoop and Claude CLI via npm.

.DESCRIPTION
    This script ensures Node.js is installed/updated using Scoop, then installs or updates
    the Claude CLI tool via npm. Works in both interactive and CI environments.

.EXAMPLE
    .\install-claude.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install-claude.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

. $PSScriptRoot\..\pslib\utils.ps1

#region Main Logic

try {
    # Check if Scoop is installed
    Write-Status "Checking for Scoop ..."
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Error "Scoop is not installed. Please install Scoop first!"
    }
    Write-Success "Scoop is installed"

    # Install or update Node.js via Scoop
    Write-Status "Checking Node.js installation ..."
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $nodeVersion = node --version
        Write-Information "  Current Node.js version: $nodeVersion"

        Write-Status "Updating Node.js via Scoop ..."
        scoop update nodejs 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Scoop update failed, but Node.js is already installed"
        }

        $newNodeVersion = node --version
        if ($nodeVersion -eq $newNodeVersion) {
            Write-Success "Node.js is up to date ($newNodeVersion)"
        } else {
            Write-Success "Node.js updated from $nodeVersion to $newNodeVersion"
        }
    } else {
        Write-Status "Installing Node.js via Scoop ..."
        scoop install nodejs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install Node.js"
        }
        Write-Success "Node.js installed"
    }

    # Verify npm is available
    Write-Status "Verifying npm installation ..."
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Error "npm not found. Node.js installation may be incomplete."
    }
    $npmVersion = npm --version
    Write-Success "npm version: $npmVersion"

    # Install or update Claude Code CLI via npm
    Write-Status "Checking Claude Code CLI installation ..."
    $claudePackage = "@anthropic-ai/claude-code"
    npm list -g $claudePackage --depth=0 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Information "  Claude Code CLI is already installed"
        Write-Status "Updating Claude Code CLI ..."
        npm update -g $claudePackage
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to update Claude Code CLI"
        }
        Write-Success "Claude CLI updated"
    } else {
        Write-Status "Installing Claude CLI ..."
        npm install -g @anthropic-ai/claude-code
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to install Claude CLI"
        }
        Write-Success "Claude CLI installed"
    }

    # Verify Claude installation
    Write-Status "Verifying Claude CLI installation ..."
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $claudeVersion = claude --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Claude CLI is ready: $claudeVersion"
        } else {
            Write-Success "Claude CLI is ready"
        }
    } else {
        Write-ErrorMsg "Claude CLI installation verification failed"
        Write-ErrorMsg "Try restarting your terminal or run: refreshenv"
        exit 1
    }

    Write-Information ""
    Write-Success "Installation complete!"
    Write-Information ""
    Write-Information "You can now run: claude"
    Write-Information ""
    Write-Information "Remember to refresh Keypirinha catalog:"
    Write-Information "  Press Win+Alt+Space and type 'Refresh catalog'"

} catch {
    Write-Error "An unexpected error occurred: $_"
} finally {
    if (-not (Test-RunningInCIorTestEnvironment)) {
        Write-Information ""
        Write-Information "Press any key to exit ..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    Write-Information ""
}

#endregion
