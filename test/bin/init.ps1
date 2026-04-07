#Requires -Version 7.4
$ErrorActionPreference = 'Stop'

Write-Output $PSVersionTable

wsl --update
wsl --version

# Define Scope Once (Must be CurrentUser for non-admin agents)
$Scope = "CurrentUser"

# ---------------------------------------------------------------------------
# 1. Install NuGet Provider
# ---------------------------------------------------------------------------
# We check specifically for the CurrentUser scope or general availability.
# If missing, we install explicitly to CurrentUser to avoid Admin prompts.
if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
    Write-Output "Installing NuGet Provider for $Scope..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope $Scope
}

# ---------------------------------------------------------------------------
# 2. Check and install dependencies
# ---------------------------------------------------------------------------
Write-Output 'Check and install dependencies ...'

# --- PESTER ---
# Check if Pester exists in the bounds we want
if (Get-InstalledModule -Name Pester -MinimumVersion 5.7.1 -MaximumVersion 5.99 -ErrorAction SilentlyContinue) {
    Write-Output 'Pester 5 is already installed.'
} else {
    Write-Output 'Installing Pester 5 ...'
    # -Force bypasses the "Untrusted Repository" prompt
    # -AllowClobber fixes issues if an older default version of Pester exists on the system
    Install-Module -Name Pester -Repository PSGallery -Scope $Scope -Force -MinimumVersion 5.7.1 -MaximumVersion 5.99 -SkipPublisherCheck -AllowClobber
}

# --- PSSCRIPTANALYZER ---
if (Get-InstalledModule -Name PSScriptAnalyzer -MinimumVersion 1.24 -ErrorAction SilentlyContinue) {
    Write-Output 'PSScriptAnalyzer is already installed.'
} else {
    Write-Output 'Installing PSScriptAnalyzer ...'
    Install-Module -Name PSScriptAnalyzer -Repository PSGallery -Scope $Scope -Force -MinimumVersion 1.24 -SkipPublisherCheck
}

# --- PWSHSPECTRECONSOLE ---
# install.ps1 installs this under PS 5.1 scope; pwsh 7.x has separate module paths,
# so integration tests (which run under pwsh) need it installed here too.
if (Get-InstalledModule -Name PwshSpectreConsole -MinimumVersion 2.0 -ErrorAction SilentlyContinue) {
    Write-Output 'PwshSpectreConsole is already installed.'
} else {
    Write-Output 'Installing PwshSpectreConsole ...'
    Install-Module -Name PwshSpectreConsole -Repository PSGallery -Scope $Scope -Force -MinimumVersion 2.0 -SkipPublisherCheck
}

Exit 0
