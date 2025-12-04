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

#region Helper Functions
. $PSScriptRoot\..\pslib\utils.ps1
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

#endregion

#region Main Logic

try {
    # Check if Scoop is installed
    Write-Status "Checking for Scoop..."
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "Scoop is not installed. Please install Scoop first!"
        exit 1
    }
    Write-Success "Scoop is installed"

    # Install or update Node.js via Scoop
    Write-Status "Checking Node.js installation..."
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $nodeVersion = node --version
        Write-Host "  Current Node.js version: $nodeVersion"

        Write-Status "Updating Node.js via Scoop..."
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
        Write-Status "Installing Node.js via Scoop..."
        scoop install nodejs
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "Failed to install Node.js"
            exit 1
        }
        Write-Success "Node.js installed"
    }

    # Verify npm is available
    Write-Status "Verifying npm installation..."
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "npm not found. Node.js installation may be incomplete."
        exit 1
    }
    $npmVersion = npm --version
    Write-Success "npm version: $npmVersion"

    # Install or update Claude Code CLI via npm
    Write-Status "Checking Claude Code CLI installation..."
    $claudePackage = "@anthropic-ai/claude-code"
    $claudeInstalled = npm list -g $claudePackage --depth=0 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Claude Code CLI is already installed"
        Write-Status "Updating Claude Code CLI..."
        npm update -g $claudePackage
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "Failed to update Claude Code CLI"
            exit 1
        }
        Write-Success "Claude CLI updated"
    } else {
        Write-Status "Installing Claude CLI..."
        npm install -g @anthropic-ai/claude-code
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "Failed to install Claude CLI"
            exit 1
        }
        Write-Success "Claude CLI installed"
    }

    # Verify Claude installation
    Write-Status "Verifying Claude CLI installation..."
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $claudeVersion = claude --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Claude CLI is ready: $claudeVersion"
        } else {
            Write-Success "Claude CLI is ready"
        }
    } else {
        Write-ErrorMsg "Claude CLI installation verification failed"
        Write-Host "Try restarting your terminal or run: refreshenv" -ForegroundColor Yellow
        exit 1
    }

    Write-Host ""
    Write-Success "Installation complete!"
    Write-Host ""
    Write-Host "You can now run: claude" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Remember to refresh Keypirinha catalog:" -ForegroundColor Yellow
    Write-Host "  Press Win+Alt+Space and type 'Refresh catalog'" -ForegroundColor Yellow

} catch {
    Write-ErrorMsg "An unexpected error occurred: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
} finally {
    if (-not (Test-RunningInCIorTestEnvironment)) {
        Write-Host ""
        Write-Host "Press any key to exit..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    Write-Host ""
}

#endregion
