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
        Manual (enter host:port), or Remove (tear down existing proxy config).

        In Auto mode both sources are detected first — a local px proxy (see
        tools/proxy/px-proxy.ps1) on the Windows host, and the PAC-resolved
        corporate proxy — and the findings are reported together. When both are
        usable the user picks one; when only one is usable it is confirmed with a
        single yes/no. px (reachable from WSL via mirrored networking) authenticates
        upstream via SSPI, so choosing it stores no credentials.

        When a corporate proxy URL is resolved, the user picks an auth method:
        Anonymous (no credentials) or Basic (username/password embedded in the URL).

        This function is idempotent - safe to run multiple times (overwrites config).

        Configured targets:
        - /etc/profile.d/wsl-manager-proxy.sh (proxy exports, sourced from /etc/zsh/zshenv for zsh)
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

    # px endpoint the Windows-side px (SC-040) listens on. WSL reaches it via
    # mirrored networking; detected in Auto so it can be offered as an alternative
    # to the PAC-resolved corporate proxy.
    $pxEndpoint = "http://127.0.0.1:3128"

    # 2. Top-level mode prompt: Auto / Manual / Remove
    $ProxyUrl = $null
    $isDirect = $false
    $authMode = $null

    $modeChoice = Read-Host "Proxy setup: [A]uto / [M]anual / [R]emove"
    switch -Regex ($modeChoice) {
        '^\s*[Aa]' {
            # Auto: detect BOTH sources up front, report the findings in one place,
            # then present a single selection. Detection output is never interleaved
            # with the prompt, and the resolved values are shown before the user
            # chooses — so there is no hidden option and no redundant confirmation.
            $pxRunning = Test-PxProxyAvailable -PxEndpoint $pxEndpoint

            $internetSettings = Get-InternetSettingsFromRegistry
            $pacResult = Get-ProxyFromPac -InternetSettings $internetSettings -ProbeUrl "https://www.microsoft.com"

            # Classify the PAC outcome for both the findings block and the branching.
            $pacHasProxy = ($null -ne $pacResult) -and (-not $pacResult.IsDirect) -and (-not [string]::IsNullOrWhiteSpace($pacResult.ProxyUrl))
            $pacIsDirect = ($null -ne $pacResult) -and $pacResult.IsDirect

            # Findings block — one place, actual resolved values.
            Write-Information "Detecting proxies..."
            if ($pxRunning) {
                Write-Information "  Local px proxy    $pxEndpoint  (running)"
            }
            else {
                Write-Information "  Local px proxy    (not running)"
            }
            if ($pacHasProxy) {
                Write-Information "  Corporate proxy   $($pacResult.ProxyUrl)  (from PAC)"
            }
            elseif ($pacIsDirect) {
                Write-Information "  Corporate proxy   DIRECT (no proxy needed)"
            }
            else {
                Write-Information "  Corporate proxy   (none detected)"
            }
            Write-Information ""

            # px authenticates upstream itself (SSPI on the Windows host), so when
            # px is the target WSL uses it with no credentials.
            if ($pxRunning -and $pacHasProxy) {
                # Two real sources — a genuine choice. Distinct initials (L/C) so
                # Get-UserChoice's first-letter matching resolves unambiguously.
                $choice = Get-UserChoice -message "Which proxy should WSL use?" -options @('Local', 'Corporate') -defaultOption 'Local'
                if ($choice -ieq 'Local') {
                    $ProxyUrl = $pxEndpoint
                    $authMode = 'anonymous'
                }
                else {
                    $ProxyUrl = $pacResult.ProxyUrl
                }
            }
            elseif ($pxRunning -and $pacIsDirect) {
                # px is available even though the corp network says DIRECT — let the
                # user pick px or honour DIRECT (tear down). Distinct initials (L/D).
                $choice = Get-UserChoice -message "Which proxy should WSL use?" -options @('Local', 'Direct') -defaultOption 'Local'
                if ($choice -ieq 'Local') {
                    $ProxyUrl = $pxEndpoint
                    $authMode = 'anonymous'
                }
                else {
                    $isDirect = $true
                }
            }
            elseif ($pxRunning) {
                # Only px detected (no PAC) — nothing to choose between, just confirm.
                if (-not (Get-UserConfirmation -message "Use the local px proxy?" -defaultValueForUser $true)) {
                    throw "Local px proxy declined. Re-run setup-proxy and choose [M]anual."
                }
                $ProxyUrl = $pxEndpoint
                $authMode = 'anonymous'
            }
            elseif ($pacHasProxy) {
                # Only the corporate proxy detected — confirm, then pick auth below.
                if (-not (Get-UserConfirmation -message "Use the corporate proxy?" -defaultValueForUser $true)) {
                    throw "Corporate proxy declined. Re-run setup-proxy and choose [M]anual."
                }
                $ProxyUrl = $pacResult.ProxyUrl
            }
            elseif ($pacIsDirect) {
                # Corp network needs no proxy and px is down — tear down existing config.
                if (-not (Get-UserConfirmation -message "PAC resolved to DIRECT. Remove proxy config?" -defaultValueForUser $true)) {
                    throw "Proxy teardown declined. Re-run setup-proxy and choose [M]anual."
                }
                $isDirect = $true
            }
            else {
                throw "No PAC/AutoConfigURL detected in registry and no local px proxy running. Re-run setup-proxy and choose [M]anual."
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

    # 3. If a proxy URL resolved and the mode did not already fix the auth (px is
    #    inherently anonymous), ask for the auth method. Basic is the opt-in to
    #    credentials; Anonymous embeds none.
    if (-not $isDirect -and -not [string]::IsNullOrWhiteSpace($ProxyUrl) -and $null -eq $authMode) {
        $authMode = (Get-UserChoice -message "Auth method" -options @('Anonymous', 'Basic') -defaultOption 'Basic').ToLower()
    }

    if ($authMode -eq 'basic' -and -not $isDirect -and -not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
        # Pre-fill the Windows username so the user can accept it with Enter. A
        # blank entry falls back to that username, so choosing Basic always embeds
        # credentials; Anonymous is the way to get a credential-less URL.
        $credentialPrefix = Get-ProxyCredentialsFromUser -DefaultUser $env:USERNAME
        if (-not [string]::IsNullOrWhiteSpace($credentialPrefix)) {
            # Insert credentials into proxy URL: http://user:pass@host:port
            $ProxyUrl = $ProxyUrl -replace '://', "://$credentialPrefix"
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
        $scriptPath = Join-Path $PSScriptRoot "scripts\setup-proxy.sh"

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
                Write-Information "  - /etc/profile.d/wsl-manager-proxy.sh (+ /etc/zsh/zshenv for zsh)"
                Write-Information "  - /etc/apt/apt.conf.d/99proxy"
                Write-Information "  - ~/.docker/config.json"
                Write-Information "  - ~/.config/containers/containers.conf"

                # Auto-terminate so a fresh session picks up the updated proxy exports.
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
