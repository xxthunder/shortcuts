<#
.DESCRIPTION
    WSL proxy configuration functions for setting up corporate proxy settings in distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

function Get-NegotiateBootstrapCredential {
    <#
    .SYNOPSIS
        Prompts for temporary Basic-auth credentials used to bootstrap the Negotiate
        Kerberos install. Distinct from Get-ProxyCredentialsFromUser: these creds
        are written to root-owned config files for the install only and are never
        exported to any process environment, so the "stored in env vars" warning
        does not apply.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    Write-Information "These credentials are used only for the one-time tooling install: written to root-owned config, never exported to any environment, and reused for the Kerberos sign-in so you are not asked twice. See 'Setup Proxy' in docs/wsl-manager.md for details."

    # Reuse the shared prompt/encode helper (from setProxy.ps1, dot-sourced by
    # Install-WslProxy). It percent-encodes both username and password so domain/
    # UPN logins splice into the URL safely, and returns "" on a blank username.
    # Pre-fill the username with the Windows account (same value proposed for the
    # Kerberos principal) so the user usually just presses Enter.
    return Get-ProxyCredentialPrefix `
        -NamePrompt "Enter your proxy username (for one-time bootstrap install)" `
        -SecretPrompt "Enter your proxy password" `
        -DefaultUser $env:USERNAME
}

function Get-WindowsKerberosDefault {
    <#
    .SYNOPSIS
        Best-effort discovery of the Kerberos realm, KDC, and principal from the
        Windows domain session, used to pre-fill the Negotiate prompts.

    .DESCRIPTION
        On a domain-joined PC the Kerberos realm equals the AD DNS domain
        ($env:USERDNSDOMAIN, uppercased by convention), the DC that authenticated
        the session ($env:LOGONSERVER) is a guaranteed-reachable KDC, and the
        Kerberos principal is the Windows account name ($env:USERNAME) — NOT the
        WSL Linux user, which is not in the corporate directory. Returns nulls
        off-domain so the caller falls back to manual entry.

    .OUTPUTS
        Hashtable with keys Realm, Kdc, and Principal (any may be $null).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $realm = if (-not [string]::IsNullOrWhiteSpace($env:USERDNSDOMAIN)) {
        $env:USERDNSDOMAIN.ToUpperInvariant()
    }
    else { $null }

    $principal = if (-not [string]::IsNullOrWhiteSpace($env:USERNAME)) { $env:USERNAME } else { $null }

    # LOGONSERVER is "\\HOST" (NetBIOS). Promote to an FQDN under the DNS domain
    # so it resolves inside WSL, which uses the corporate resolver.
    $kdc = $null
    $logonHost = if ($env:LOGONSERVER) { $env:LOGONSERVER -replace '^\\\\', '' } else { $null }
    if (-not [string]::IsNullOrWhiteSpace($logonHost)) {
        $kdc = if (-not [string]::IsNullOrWhiteSpace($env:USERDNSDOMAIN)) {
            "$logonHost.$($env:USERDNSDOMAIN)"
        }
        else { $logonHost }
    }

    return @{ Realm = $realm; Kdc = $kdc; Principal = $principal }
}

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

    # Enter accepts the default (Auto); the capitalized letter marks it, matching
    # the [Y/n] convention used by Get-UserConfirmation. Get-UserChoice re-prompts
    # on invalid input instead of aborting.
    $modeChoice = Get-UserChoice -message "Proxy setup" -options @('Auto', 'Manual', 'Remove') -defaultOption 'Auto'
    switch ($modeChoice) {
        'Auto' {
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
        'Manual' {
            $manualEntry = Read-Host "Enter proxy host:port (e.g. proxy.corp.com:8080)"
            if ([string]::IsNullOrWhiteSpace($manualEntry)) {
                throw "No proxy host:port provided."
            }
            $ProxyUrl = "http://$manualEntry"
            break
        }
        'Remove' {
            $isDirect = $true
            break
        }
    }

    # 3. If a proxy URL resolved, ask for the auth method. Three options:
    #   Anonymous (default) — no credentials; the proxy needs no per-user auth.
    #   Basic               — username/password embedded in the proxy URL.
    #   Negotiate           — Kerberos via a local px proxy (creds handled below).
    # The full explanation lives in docs/wsl-manager.md ("Authentication methods")
    # so the prompt stays terse. Choosing Basic IS the opt-in to credentials, so
    # the old separate "provide credentials?" confirm is gone; Anonymous is the
    # explicit no-credentials choice.
    $authMode = 'anonymous'
    if (-not $isDirect -and -not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
        $authChoice = Get-UserChoice -message "Auth method" -options @('Anonymous', 'Basic', 'Negotiate') -defaultOption 'Anonymous'
        $authMode = $authChoice.ToLower()
    }

    if ($authMode -eq 'basic' -and -not $isDirect -and -not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
        # Pre-fill the username with the Windows account so the user can accept it
        # with Enter (same value proposed for Negotiate/Kerberos). A blank username
        # yields an empty prefix, leaving the URL credential-less.
        $credentialPrefix = Get-ProxyCredentialsFromUser -DefaultUser $env:USERNAME
        if (-not [string]::IsNullOrWhiteSpace($credentialPrefix)) {
            # Insert credentials into proxy URL: http://user:pass@host:port
            $ProxyUrl = $ProxyUrl -replace '://', "://$credentialPrefix"
        }
    }

    # Negotiate: prompt for bootstrap creds. The Basic-auth URL is piped to the
    # script via stdin (not cmdline, not env) so it never appears in /proc/<pid>/*.
    # The clean $ProxyUrl (no creds) is what the long-lived px config will use.
    # Also gather the Kerberos realm + KDC for Phase 2 (krb5.conf). These are not
    # secrets, so they ride on the cmdline of the (separate) activate invocation.
    $bootstrapProxyUrl = $null
    $krbRealm = $null
    $krbKdc = $null
    $krbPrincipal = $null
    if ($authMode -eq 'negotiate' -and -not $isDirect -and -not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
        $bootstrapPrefix = Get-NegotiateBootstrapCredential
        if ([string]::IsNullOrWhiteSpace($bootstrapPrefix)) {
            throw "Bootstrap credentials are required for Negotiate mode setup."
        }
        $bootstrapProxyUrl = $ProxyUrl -replace '://', "://$bootstrapPrefix"

        # Pre-fill realm/KDC from the Windows domain session so the user can press
        # Enter to accept rather than hunting for values they rarely know. The
        # detected value is shown in the prompt, so the choice stays auditable.
        $krbDefaults = Get-WindowsKerberosDefault

        $realmPrompt = if ($krbDefaults.Realm) {
            "Enter your Kerberos realm [$($krbDefaults.Realm)]"
        }
        else { "Enter your Kerberos realm (e.g. CORP.COMPANY.COM)" }
        $krbRealm = Read-Host $realmPrompt
        if ([string]::IsNullOrWhiteSpace($krbRealm)) { $krbRealm = $krbDefaults.Realm }
        if ([string]::IsNullOrWhiteSpace($krbRealm)) {
            throw "A Kerberos realm is required for Negotiate mode setup."
        }

        $kdcPrompt = if ($krbDefaults.Kdc) {
            "Enter your Kerberos KDC hostname [$($krbDefaults.Kdc)]"
        }
        else { "Enter your Kerberos KDC hostname (e.g. kdc.company.com)" }
        $krbKdc = Read-Host $kdcPrompt
        if ([string]::IsNullOrWhiteSpace($krbKdc)) { $krbKdc = $krbDefaults.Kdc }
        if ([string]::IsNullOrWhiteSpace($krbKdc)) {
            throw "A Kerberos KDC hostname is required for Negotiate mode setup."
        }

        # Kerberos principal = the corporate (Windows) account, NOT the WSL Linux
        # user. kinit with no principal defaults to the Linux username (e.g.
        # 'wsluser'), which is not in the AD directory and fails. Default to the
        # Windows username; user can override (e.g. a UPN).
        $principalPrompt = if ($krbDefaults.Principal) {
            "Enter your Kerberos username/principal [$($krbDefaults.Principal)]"
        }
        else { "Enter your Kerberos username/principal (e.g. jdoe)" }
        $krbPrincipal = Read-Host $principalPrompt
        if ([string]::IsNullOrWhiteSpace($krbPrincipal)) { $krbPrincipal = $krbDefaults.Principal }
        if ([string]::IsNullOrWhiteSpace($krbPrincipal)) {
            throw "A Kerberos username/principal is required for Negotiate mode setup."
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

        # Single call; only the Negotiate path adds -StdinInput (the bootstrap URL
        # piped via stdin). Omitting the key on the Basic path keeps the stdin
        # branch in Invoke-WslDistroScript inactive (it gates on ContainsKey).
        $invokeParams = @{
            ScriptPath  = $scriptPath
            DistroName  = $DistroName
            Arguments   = $scriptArgs
            StopAtError = $false
            PrintCommand = $false
        }
        if ($authMode -eq 'negotiate' -and -not $isDirect) {
            $invokeParams['StdinInput'] = $bootstrapProxyUrl
        }
        $exitCode = Invoke-WslDistroScript @invokeParams

        # Negotiate Phases 2-3 (SC-036c): on bootstrap success, run the activate
        # step as a SEPARATE interactive invocation (no stdin pipe) so the script's
        # kinit fallback can prompt on the terminal if the reused bootstrap password
        # is rejected (the happy path reuses it via setsid and does not prompt).
        # Realm/KDC/proxy are not secrets, so they go on the cmdline. The script
        # leaves the Phase-1 Basic state intact on failure (marker 'negotiate-bootstrap').
        if ($authMode -eq 'negotiate' -and -not $isDirect -and $exitCode -eq 0) {
            Write-Information ""
            Write-Information "Phase 1 bootstrap complete. Starting Phases 2-3 (Kerberos config + px activation)..."
            Write-Information "  Your bootstrap password is reused for the Kerberos sign-in (kinit); you'll only be prompted if it isn't accepted."
            Write-Information ""
            $activateArgs = @(
                "--activate",
                "--proxy-url=$ProxyUrl",
                "--realm=$krbRealm",
                "--kdc=$krbKdc",
                "--principal=$krbPrincipal",
                "--username=$username"
            )
            $exitCode = Invoke-WslDistroScript `
                -ScriptPath $scriptPath `
                -DistroName $DistroName `
                -Arguments $activateArgs `
                -StopAtError $false `
                -PrintCommand $false `
                -Interactive
        }

        switch ($exitCode) {
            0 {
                Write-Information ""
                if ($isDirect) {
                    Write-Information "Successfully removed proxy configuration from '$DistroName'."
                }
                elseif ($authMode -eq 'negotiate') {
                    Write-Information "Successfully configured Negotiate proxy (Phases 1-3) in '$DistroName'."
                }
                else {
                    Write-Information "Successfully configured proxy in '$DistroName'."
                }
                Write-Information ""
                Write-Information "Affected targets:"
                if ($authMode -eq 'negotiate' -and -not $isDirect) {
                    Write-Information "  - krb5-user, pipx, px-proxy (installed)"
                    Write-Information "  - /etc/krb5.conf (realm + KDC)"
                    Write-Information "  - ~/.config/px/px.ini (no credentials)"
                    Write-Information "  - Negotiate chain verified end-to-end via px over HTTPS (px started for the test, then stopped)"
                    Write-Information "  - /etc/apt/apt.conf.d/99proxy (bootstrap credentials)"
                    Write-Information "  - /etc/wsl-manager/proxy-mode (= negotiate-bootstrap)"
                    Write-Information "  - ~/.profile, ~/.bashrc (legacy Basic-mode proxy block removed)"
                    Write-Information ""
                    Write-Information "Phase 4 (switch apt/Docker/Podman/.profile to localhost:3128 + px shell auto-start) ships in SC-036d."
                }
                else {
                    Write-Information "  - ~/.profile (environment variables)"
                    Write-Information "  - /etc/apt/apt.conf.d/99proxy"
                    Write-Information "  - ~/.docker/config.json"
                    Write-Information "  - ~/.config/containers/containers.conf"
                }

                # Auto-terminate so a fresh shell loads the updated ~/.profile.
                # Skipped for Negotiate: Phases 1-3 do not change ~/.profile, and a
                # terminate would kill the px instance we just started and verified.
                # Wrapped: a termination failure here must not be reported as a
                # proxy-configuration failure — the proxy was applied successfully.
                if ($authMode -ne 'negotiate') {
                    try {
                        Stop-WslDistro -Name $DistroName -Confirm:$false | Out-Null
                    }
                    catch {
                        Write-Warning "Proxy was configured successfully, but auto-terminate failed: $_. Run 'wsl.exe --terminate $DistroName' manually so a fresh shell picks up the new environment."
                    }
                }
                return $true
            }
            1 {
                throw "Prerequisite check failed. Ensure script has root access."
            }
            2 {
                if ($authMode -eq 'negotiate') {
                    throw "Negotiate setup failed (exit 2): the proxy rejected the bootstrap credentials, the proxy is unreachable, a package install failed, or writing the Kerberos/px config failed. See the script output above for details."
                }
                throw "Configuration failed. Check file system permissions."
            }
            3 {
                if ($authMode -eq 'negotiate') {
                    throw "Negotiate verification failed (exit 3): kinit could not obtain a Kerberos ticket, or the end-to-end proxy check (curl HTTPS via px) failed — a 407 (auth) or a TLS cert error (corporate root CA not trusted in the distro). Your previous proxy configuration was left intact (nothing was switched to localhost). See the output above for the specific cause."
                }
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
