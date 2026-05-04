<#
.DESCRIPTION
    WSL proxy configuration functions for setting up corporate proxy settings in distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

function Install-WslProxy {
    <#
    .SYNOPSIS
        Configures or removes proxy settings inside a WSL distribution with automatic proxy detection.

    .DESCRIPTION
        Prompts the user upfront to choose a setup mode: Auto (PAC-based detection),
        Manual (enter host:port), or Remove (tear down existing proxy config). When a
        proxy URL is resolved, also prompts for auth method (Basic or Negotiate) and
        — for Basic — credentials.

        This function is idempotent - safe to run multiple times (overwrites config).

        Configured targets:
        - ~/.profile (managed block with http_proxy, https_proxy, no_proxy)
        - /etc/apt/apt.conf.d/99proxy
        - ~/.docker/config.json (proxies.default)
        - ~/.config/containers/containers.conf ([engine] env)

    .PARAMETER DistroName
        The name of the WSL distribution to configure.

    .OUTPUTS
        System.Boolean
        Returns $true if configuration succeeds, $false otherwise.

    .EXAMPLE
        Install-WslProxy -DistroName "Debian"
        Interactive mode - prompts for Auto/Manual/Remove, then auth method and credentials.
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
        . "$PSScriptRoot\..\..\tools\proxy\setProxy.ps1"
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

    # 2. Top-level mode prompt: Auto / Manual / Remove
    $ProxyUrl = $null
    $isDirect = $false

    $modeChoice = Read-Host "Proxy setup: [A]uto / [M]anual / [R]emove"
    switch -Regex ($modeChoice) {
        '^\s*[Aa]' {
            # Auto: PAC detection with explicit confirmation
            $internetSettings = Get-InternetSettingsFromRegistry
            $pacResult = Get-ProxyFromPac -InternetSettings $internetSettings -ProbeUrl "https://www.microsoft.com"

            if ($null -eq $pacResult) {
                throw "No PAC/AutoConfigURL detected in registry. Re-run setup-proxy and choose [M]anual."
            }
            if ($pacResult.IsDirect) {
                Write-Information "PAC resolved to DIRECT (no proxy needed). Removing any existing proxy configuration."
                $isDirect = $true
            }
            else {
                Write-Information "Auto-detected proxy: $($pacResult.ProxyUrl)"
                $confirmed = Get-UserConfirmation -message "Use this proxy?" -defaultValueForUser $true
                if (-not $confirmed) {
                    throw "Auto-detected proxy rejected. Re-run setup-proxy and choose [M]anual."
                }
                $ProxyUrl = $pacResult.ProxyUrl
            }
            break
        }
        '^\s*[Mm]' {
            $manualEntry = Read-Host "Enter proxy host:port (e.g. proxy.corp.com:8080)"
            if ([string]::IsNullOrWhiteSpace($manualEntry)) {
                throw "No proxy host:port provided."
            }
            $ProxyUrl = "http://$manualEntry"
            break
        }
        '^\s*[Rr]' {
            $isDirect = $true
            break
        }
        default {
            throw "Invalid choice '$modeChoice'. Expected [A]uto, [M]anual, or [R]emove."
        }
    }

    # 3. If proxy URL resolved, ask for auth method, then (Basic only) credentials
    $authMode = 'basic'
    if (-not $isDirect -and -not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
        $authChoice = Read-Host "Auth method: [B]asic (credentials in env) or [N]egotiate (Kerberos via px)"
        if ($authChoice -eq 'N' -or $authChoice -eq 'n') {
            $authMode = 'negotiate'
        }
    }

    if ($authMode -eq 'basic' -and -not $isDirect -and -not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
        $wantCreds = Get-UserConfirmation -message "Do you want to provide proxy credentials?" -defaultValueForUser $true
        if ($wantCreds) {
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
        $description = "Remove proxy configurations (.profile, apt, Docker, Podman)"
    }
    else {
        $action = "Proxy configuration in '$DistroName'"
        $description = "Configure proxy settings (.profile, apt, Docker, Podman)"
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
        Write-Information "  Proxy URL: $(Get-MaskedProxyUrl -ProxyUrl $ProxyUrl)"
        Write-Information "  No Proxy:  $NoProxy"
        Write-Information "  User:      $username"
        Write-Information "  Auth mode: $authMode"
    }
    Write-Information ""

    try {
        $scriptName = if ($authMode -eq 'negotiate') { 'setup-proxy-negotiate.sh' } else { 'setup-proxy.sh' }
        $scriptPath = Join-Path $PSScriptRoot "scripts\$scriptName"

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

        $exitCode = Invoke-WslDistroScript -ScriptPath $scriptPath -DistroName $DistroName -Arguments $scriptArgs -StopAtError $false -PrintCommand $false

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
                Write-Information "  - ~/.profile (environment variables)"
                Write-Information "  - /etc/apt/apt.conf.d/99proxy"
                Write-Information "  - ~/.docker/config.json"
                Write-Information "  - ~/.config/containers/containers.conf"

                # Auto-terminate so a fresh shell loads the updated ~/.profile.
                # Wrapped: a termination failure here must not be reported as a
                # proxy-configuration failure — the proxy was applied successfully.
                try {
                    Stop-WslDistro -Name $DistroName -Confirm:$false | Out-Null
                }
                catch {
                    Write-Warning "Proxy was configured successfully, but auto-terminate failed: $_. Run 'wsl.exe --terminate $DistroName' manually so a fresh shell picks up the new environment."
                }
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
            10 {
                throw "Negotiate proxy mode is not yet implemented. Full support ships in SC-036b through SC-036e."
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
