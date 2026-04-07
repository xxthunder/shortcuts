<#
.DESCRIPTION
    PwshSpectreConsole module loader.
    Dot-source this file in any library that needs Spectre commands.
    Handles UTF-8 encoding, interactive install prompt, and the import.

    Unit tests define lightweight stubs for Spectre commands in their BeforeAll
    blocks BEFORE dot-sourcing library files.  The command-existence check below
    skips the real Import-Module when stubs are present.
#>

# Enable UTF-8 encoding unconditionally (avoids PwshSpectreConsole "Western European (DOS)" warning)
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# Skip import when unit test stubs are already defined
if (Get-Command Format-SpectreTable -ErrorAction SilentlyContinue) {
    return
}

# In interactive sessions, offer to install the module if missing
if (-not (Get-Module -Name PwshSpectreConsole -ListAvailable)) {
    if (Test-RunningInCIorTestEnvironment) {
        throw "PwshSpectreConsole module is not installed. Run test/bin/init.ps1 to install test dependencies."
    }

    $install = Get-UserConfirmation -message "PwshSpectreConsole module is missing. Install now?"
    if ($install) {
        if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
            Write-Status "Installing NuGet package provider..."
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
        }
        Write-Status "Installing PwshSpectreConsole..."
        Install-Module -Name PwshSpectreConsole -Repository PSGallery -Scope CurrentUser -Force -MinimumVersion 2.0 -SkipPublisherCheck
        Write-Success "PwshSpectreConsole installed"
    }
    else {
        throw "PwshSpectreConsole module is required. Run bin/install.ps1 or relaunch and accept the install prompt."
    }
}

Import-Module PwshSpectreConsole -ErrorAction Stop
