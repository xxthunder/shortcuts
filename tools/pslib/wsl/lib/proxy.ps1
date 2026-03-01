<#
.DESCRIPTION
    WSL proxy configuration functions for setting up corporate proxy settings in distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\..\utils\utils.ps1"

function Install-WslProxy {
    <#
    .SYNOPSIS
        Configures or removes proxy settings inside a WSL distribution with automatic proxy detection.

    .DESCRIPTION
        Auto-detects proxy settings by dot-sourcing setProxy.ps1 in library mode and calling
        its PAC/registry detection functions. Prompts the user for credentials if needed.
        Falls back to manual entry or DIRECT (no proxy) when auto-detection is unavailable.

        This function is idempotent - safe to run multiple times (overwrites config).

        Configured targets:
        - ~/.bashrc (managed block with http_proxy, https_proxy, no_proxy)
        - /etc/apt/apt.conf.d/99proxy
        - ~/.docker/config.json (proxies.default)
        - ~/.config/containers/containers.conf ([engine] env)

    .PARAMETER DistroName
        The name of the WSL distribution to configure.

    .OUTPUTS
        System.Boolean
        Returns $true if configuration succeeds, $false otherwise.

    .EXAMPLE
        Install-WslProxy -DistroName "Debian" -Confirm:$false
        Auto-detects proxy from PAC/registry and configures Debian.

    .EXAMPLE
        Install-WslProxy -DistroName "Debian"
        Interactive mode - prompts for credentials and DIRECT/manual choices.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    # 1. Dot-source setProxy.ps1 in library mode to access detection functions
    $originalLibraryMode = $env:SETPROXY_LIBRARY_MODE
    $originalErrorActionPreference = $ErrorActionPreference
    try {
        $env:SETPROXY_LIBRARY_MODE = '1'
        . "$PSScriptRoot\..\..\..\proxy\setProxy.ps1"
    }
    finally {
        $ErrorActionPreference = $originalErrorActionPreference
        if ($null -eq $originalLibraryMode) {
            Remove-Item Env:\SETPROXY_LIBRARY_MODE -ErrorAction SilentlyContinue
        }
        else {
            $env:SETPROXY_LIBRARY_MODE = $originalLibraryMode
        }
    }

    # 2. Auto-detect proxy from PAC/registry
    $ProxyUrl = $null
    $isDirect = $false

    $internetSettings = Get-InternetSettingsFromRegistry
    $pacResult = Get-ProxyFromPac -InternetSettings $internetSettings -ProbeUrl "https://www.microsoft.com"

    if ($null -ne $pacResult) {
        # PAC was found and resolved
        if ($pacResult.IsDirect) {
            # PAC says DIRECT - ask user to confirm or enter manual proxy
            Write-Information "PAC resolved to DIRECT (no proxy needed)."
            $choice = Read-Host "Choose: [D]irect (no proxy) or [M]anual entry"
            if ($choice -eq 'M' -or $choice -eq 'm') {
                $manualEntry = Read-Host "Enter proxy host:port (e.g. proxy.corp.com:8080)"
                if ([string]::IsNullOrWhiteSpace($manualEntry)) {
                    throw "No proxy host:port provided."
                }
                $ProxyUrl = "http://$manualEntry"
            }
            else {
                $isDirect = $true
            }
        }
        else {
            # PAC resolved to a proxy URL
            $ProxyUrl = $pacResult.ProxyUrl
            Write-Information "Auto-detected proxy: $ProxyUrl"
        }
    }
    else {
        # No PAC detected - prompt user
        Write-Information "No PAC/AutoConfigURL detected in registry."
        $choice = Read-Host "Choose: [M]anual proxy entry or [D]irect (no proxy)"
        if ($choice -eq 'D' -or $choice -eq 'd') {
            $isDirect = $true
        }
        else {
            $manualEntry = Read-Host "Enter proxy host:port (e.g. proxy.corp.com:8080)"
            if ([string]::IsNullOrWhiteSpace($manualEntry)) {
                throw "No proxy host:port provided."
            }
            $ProxyUrl = "http://$manualEntry"
        }
    }

    # 3. If proxy URL resolved, ask about credentials
    if (-not $isDirect -and -not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
        $wantCreds = Read-Host "Do you want to provide proxy credentials? [Y/N]"
        if ($wantCreds -eq 'Y' -or $wantCreds -eq 'y') {
            $credentialPrefix = Get-ProxyCredentialsFromUser
            if (-not [string]::IsNullOrWhiteSpace($credentialPrefix)) {
                # Insert credentials into proxy URL: http://user:pass@host:port
                $ProxyUrl = $ProxyUrl -replace '://', "://$credentialPrefix"
            }
        }
    }

    # 4. Set NoProxy — prefer existing env var, fall back to default
    $NoProxy = if ($env:NO_PROXY) { $env:NO_PROXY } else { "localhost,127.0.0.1" }

    # 5. Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

    # 6. Detect default user
    $username = Get-WslDefaultUser -DistroName $DistroName
    if (-not $username) {
        throw @"
No default user configured in '$DistroName'.
Proxy setup requires a non-root user.

Please setup a user first:
  .\tools\wsl\wsl-manager.ps1 setup-user $DistroName

Then run setup-proxy again.
"@
    }

    # 7. SupportsShouldProcess
    if ($isDirect) {
        $action = "Remove proxy settings from '$DistroName'"
        $description = "Remove proxy configurations (.bashrc, apt, Docker, Podman)"
    }
    else {
        $action = "Proxy configuration in '$DistroName'"
        $description = "Configure proxy settings (.bashrc, apt, Docker, Podman)"
    }

    if (-not $PSCmdlet.ShouldProcess($action, $description, "Confirm Proxy Setup")) {
        return $false
    }

    if ($isDirect) {
        Write-Information "Removing proxy configuration from '$DistroName' (DIRECT)..."
        Write-Information "  User: $username"
    }
    else {
        Write-Information "Configuring proxy in '$DistroName' ..."
        Write-Information "  Proxy URL: $ProxyUrl"
        Write-Information "  No Proxy:  $NoProxy"
        Write-Information "  User:      $username"
    }
    Write-Information ""

    try {
        $scriptPath = Join-Path $PSScriptRoot "..\scripts\setup-proxy.sh"

        if ($isDirect) {
            $scriptArgs = @(
                "--remove",
                "--username=$username"
            )
        }
        else {
            $scriptArgs = @(
                "--proxy-url=$ProxyUrl",
                "--no-proxy=$NoProxy",
                "--username=$username"
            )
        }

        $exitCode = Invoke-WslDistroScript -ScriptPath $scriptPath -DistroName $DistroName -Arguments $scriptArgs -StopAtError $false -PrintCommand $false -AsRoot $true

        switch ($exitCode) {
            0 {
                Write-Information ""
                if ($isDirect) {
                    Write-Information "Successfully removed proxy configuration from '$DistroName'."
                }
                else {
                    Write-Information "Successfully configured proxy in '$DistroName'."
                }
                Write-Information ""
                Write-Information "Affected targets:"
                Write-Information "  - ~/.bashrc (environment variables)"
                Write-Information "  - /etc/apt/apt.conf.d/99proxy"
                Write-Information "  - ~/.docker/config.json"
                Write-Information "  - ~/.config/containers/containers.conf"
                return $true
            }
            1 {
                throw "Prerequisite check failed. Ensure script has root access."
            }
            2 {
                throw "Configuration failed. Check file system permissions."
            }
            3 {
                throw "Verification failed. Proxy configured but verification checks did not pass."
            }
            4 {
                throw "Argument error. Required proxy parameters missing."
            }
            default {
                throw "Proxy configuration failed with exit code: $exitCode"
            }
        }
    }
    catch {
        Write-Error "Proxy configuration failed: $_"
        return $false
    }
}
