<#
.SYNOPSIS
    Proxy settings for PowerShell using PAC resolution (no hardcoded proxy hosts)
.DESCRIPTION
    Reads PAC/Internet Settings from the registry and uses the system web proxy
    to determine the effective proxy. Sets PowerShell's default proxy and common
    environment variables for tools (git, Python, etc.).

    If a local px proxy is detected running on its endpoint, setProxy targets it
    automatically (px handles corporate authentication); pass -NoPx to force the
    corporate proxy, or -UsePx to always target px.
.PARAMETER ProbeUrl
    URL to probe for proxy resolution (default: https://www.microsoft.com)
.PARAMETER FallbackProxyHost
    Fallback proxy host:port when PAC resolution fails or is not configured (default: some.fallback.de:8080)
.PARAMETER UsePx
    Always targets a local px proxy endpoint instead of resolving/using the corporate proxy.
    Use this when running px as a local authenticating proxy (see px-proxy.ps1).
.PARAMETER NoPx
    Forces the corporate-proxy path even when a running px is auto-detected.
.PARAMETER PxEndpoint
    The local px proxy endpoint to target/probe (default: http://127.0.0.1:3128)
.EXAMPLE
    .\setProxy.ps1
    Auto-detects a running px and targets it; otherwise resolves the corporate proxy
.EXAMPLE
    .\setProxy.ps1 -FallbackProxyHost "corporate.proxy.com:8080"
    Uses custom fallback proxy for corporate environment
.EXAMPLE
    .\setProxy.ps1 -askForCreds
    Prompts for credentials and embeds them in proxy environment variables (WARNING: Security risk!)
.EXAMPLE
    .\setProxy.ps1 -UsePx
    Always targets the local px proxy endpoint (http://127.0.0.1:3128) instead of the corporate proxy
.EXAMPLE
    .\setProxy.ps1 -NoPx
    Ignores any running px and forces the corporate-proxy resolution path
#>

Param(
    [Parameter(Mandatory = $false)]
    [string]$ProbeUrl = "https://www.microsoft.com",

    [Parameter(Mandatory = $false)]
    [string]$FallbackProxyHost = "some.fallback.de:8080",

    [Parameter(Mandatory = $false)]
    [switch]$askForCreds,

    [Parameter(Mandatory = $false)]
    [switch]$UsePx,

    [Parameter(Mandatory = $false)]
    [switch]$NoPx,

    [Parameter(Mandatory = $false)]
    [string]$PxEndpoint = "http://127.0.0.1:3128"
)

$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

#region Private Functions

<#
.SYNOPSIS
    Gets Internet Setting from Windows registry
.DESCRIPTION
    Reads proxy configuration from HKCU Internet Settings registry key
.OUTPUTS
    PSCustomObject with registry properties or $null if not found
#>
function Get-InternetSettingsFromRegistry {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $RegistryInternetSettings = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    $settings = Get-ItemProperty -Path $RegistryInternetSettings -ErrorAction SilentlyContinue
    return $settings
}

<#
.SYNOPSIS
    Enables proxy in Windows registry if disabled
.DESCRIPTION
    Sets ProxyEnable to 1 if currently 0
.PARAMETER InternetSettings
    Internet Settings object from registry
.OUTPUTS
    Boolean indicating if change was made
#>
function Enable-ProxyInRegistry {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$InternetSettings
    )

    if (-not $InternetSettings) {
        Write-Warning "Internet Settings registry key not found. Proxy resolution may fail."
        return $false
    }

    if ($InternetSettings.ProxyEnable -eq 0) {
        $RegistryInternetSettings = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        Set-ItemProperty -Path $RegistryInternetSettings -Name ProxyEnable -Value 1
        Write-Verbose "ProxyEnable was 0 and has been set to 1."
        return $true
    }

    Write-Verbose "ProxyEnable currently: $($InternetSettings.ProxyEnable)"
    return $false
}

<#
.SYNOPSIS
    Sets NO_PROXY environment variable
.DESCRIPTION
    Configures NO_PROXY for local
#>
function Set-NoProxyEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess("NO_PROXY environment variable", "Set")) {
        $Env:NO_PROXY = "localhost"
        Write-Verbose "NO_PROXY set to: $Env:NO_PROXY"
    }
}

<#
.SYNOPSIS
    Gets credentials for proxy authentication from user input
.DESCRIPTION
    Prompts user for username and password, percent-encodes both, and returns a
    formatted credentials string for the proxy URL. Encoding the username as well
    as the password lets domain/UPN logins ('DOMAIN\user', 'user@corp.com') and
    special-character passwords splice into a proxy URL without corrupting the
    userinfo segment. The password BSTR is zeroed even on failure.
.PARAMETER DefaultUser
    Optional username to pre-fill. When provided, it is shown in the prompt as
    "[DefaultUser]" and returned when the user presses Enter, so the common case
    (the current Windows account) needs no typing. A blank default preserves the
    original "no username -> empty prefix" behavior.
.OUTPUTS
    String with format "encodedUser:encodedPassword@" or empty string if cancelled
#>
function Get-ProxyCredentialsFromUser {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$DefaultUser = ""
    )

    Write-Warning "SECURITY RISK: Credentials will be stored in environment variables in plain text!"
    Write-Warning "This makes your password visible to any process that reads environment variables."
    Write-Warning "Only use this option when absolutely required by specific tools."

    $namePrompt = "Please enter your Windows user name for proxy authentication"
    if (-not [string]::IsNullOrWhiteSpace($DefaultUser)) {
        $namePrompt = "$namePrompt [$DefaultUser]"
    }

    [string]$username = Read-Host $namePrompt
    if ([string]::IsNullOrEmpty($username)) {
        if (-not [string]::IsNullOrWhiteSpace($DefaultUser)) {
            $username = $DefaultUser
        }
        else {
            Write-Warning "No username provided. Skipping credential embedding."
            return ""
        }
    }
    [string]$encodedUser = [System.Uri]::EscapeDataString($username)

    $userpwd_sec = Read-Host "Please enter your Windows password for proxy authentication" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($userpwd_sec)
    try {
        [string]$encodedPwd = [System.Uri]::EscapeDataString([System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr))
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }

    return "${encodedUser}:${encodedPwd}@"
}

<#
.SYNOPSIS
    Masks credentials in proxy URL for safe display
.DESCRIPTION
    Replaces username and password with asterisks to prevent accidental exposure
.PARAMETER ProxyUrl
    Proxy URL potentially containing credentials (can be empty/null)
.OUTPUTS
    String with credentials masked as ***username:***@host:port or empty if input is empty
#>
function Get-MaskedProxyUrl {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$ProxyUrl
    )

    if ([string]::IsNullOrEmpty($ProxyUrl)) {
        return $ProxyUrl
    }

    try {
        # Simple regex-based masking: find pattern scheme://anything@host and mask the "anything" part
        if ($ProxyUrl -match '^([a-zA-Z0-9+.-]+)://([^@]+)@(.+)$') {
            $scheme = $matches[1]
            $hostPort = $matches[3]
            return "${scheme}://***username:***@${hostPort}"
        }

        # If no @ found, return as-is (no credentials)
        return $ProxyUrl
    }
    catch {
        # If anything fails, return as-is
        return $ProxyUrl
    }
}

<#
.SYNOPSIS
    Gets system web proxy object
.DESCRIPTION
    Returns the system web proxy (WinINET) which honors PAC configuration
.OUTPUTS
    System.Net.IWebProxy object
#>
function Get-SystemWebProxy {
    [CmdletBinding()]
    [OutputType([System.Net.IWebProxy])]
    param()

    return [System.Net.WebRequest]::GetSystemWebProxy()
}

# Proxy env vars that .NET's system web proxy honours ahead of the WinINET PAC.
$script:ProxyEnvVarNames = @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')

<#
.SYNOPSIS
    Clears the proxy env vars for the process and returns a snapshot to restore.
.DESCRIPTION
    In PowerShell 7 (.NET) GetSystemWebProxy() honours HTTP_PROXY/HTTPS_PROXY/
    ALL_PROXY ahead of the WinINET PAC, and the result is resolved ONCE per
    process and cached as a static singleton (HttpClient.DefaultProxy). Once that
    first resolution happens with the vars set, no later env change can rebuild
    it -- clearing the vars afterward has no effect. Callers that need the PAC to
    win must therefore clear these vars BEFORE the process's first
    GetSystemWebProxy() call, not merely around a later one. Pair with
    Resume-ProxyEnvVar in a finally block.
.OUTPUTS
    Hashtable mapping each proxy env var name to its prior value ($null if unset).
#>
function Suspend-ProxyEnvVar {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $saved = @{}
    foreach ($name in $script:ProxyEnvVarNames) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name)
        Remove-Item "Env:\$name" -ErrorAction SilentlyContinue
    }
    return $saved
}

<#
.SYNOPSIS
    Restores proxy env vars from a Suspend-ProxyEnvVar snapshot.
.PARAMETER Saved
    The hashtable returned by Suspend-ProxyEnvVar.
#>
function Resume-ProxyEnvVar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Saved
    )

    foreach ($name in $script:ProxyEnvVarNames) {
        if ($null -eq $Saved[$name]) {
            Remove-Item "Env:\$name" -ErrorAction SilentlyContinue
        }
        else {
            Set-Item "Env:\$name" -Value $Saved[$name]
        }
    }
}

<#
.SYNOPSIS
    Resolves proxy URL from PAC configuration
.DESCRIPTION
    Uses system web proxy to resolve effective proxy for a probe URL
.PARAMETER InternetSettings
    Internet Settings object from registry
.PARAMETER ProbeUrl
    URL to probe for proxy resolution
.OUTPUTS
    Hashtable with ProxyUrl and IsDirect properties, or $null if no PAC
.NOTES
    Neutralises the inherited proxy env vars (see Suspend-ProxyEnvVar) so a px
    override exported by the setProxy profile is not reported back as the
    "corporate" proxy. This is only sufficient when Get-ProxyFromPac is the
    process's first system-proxy resolution; callers that resolve the system
    proxy earlier (e.g. Initialize-DefaultWebProxy) must suspend the vars around
    that earlier call themselves, because .NET caches the first result.
#>
function Get-ProxyFromPac {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$InternetSettings,

        [Parameter(Mandatory = $true)]
        [string]$ProbeUrl
    )

    # Check if AutoConfigURL property exists and has a value
    if (-not ($InternetSettings.PSObject.Properties.Name -contains 'AutoConfigURL') -or
        [string]::IsNullOrEmpty($InternetSettings.AutoConfigURL)) {
        return $null
    }

    Write-Verbose "AutoConfigURL detected: $($InternetSettings.AutoConfigURL)"

    # Clear the inherited proxy env vars before resolving so the PAC (not a px
    # override) wins; restore them in finally. See Suspend-ProxyEnvVar for why
    # this must precede the process's first GetSystemWebProxy() call.
    $savedProxyEnv = Suspend-ProxyEnvVar

    try {
        $systemProxy = Get-SystemWebProxy
        $targetUri = [Uri]$ProbeUrl

        $resolvedProxyUri = $systemProxy.GetProxy($targetUri)
        $isBypassed = $systemProxy.IsBypassed($targetUri)

        # Determine if we have a proxy or DIRECT
        $usingDirect = $isBypassed -or -not $resolvedProxyUri -or ($resolvedProxyUri.AbsoluteUri -eq $targetUri.AbsoluteUri)

        if ($usingDirect) {
            Write-Verbose "PAC/System proxy indicates DIRECT for '$targetUri'. Clearing HTTP(S)_PROXY environment variables."
            return @{
                ProxyUrl = $null
                IsDirect = $true
            }
        }
        else {
            # Build proxy host:port from resolved URI
            $proxyScheme = $resolvedProxyUri.Scheme
            $proxyAuthority = $resolvedProxyUri.Authority
            $proxyUrl = "${proxyScheme}://$proxyAuthority"

            return @{
                ProxyUrl = $proxyUrl
                IsDirect = $false
            }
        }
    }
    catch {
        Write-Warning "Failed to resolve proxy via system settings (PAC/WinINET). $_"
        return $null
    }
    finally {
        Resume-ProxyEnvVar -Saved $savedProxyEnv
    }
}

<#
.SYNOPSIS
    Sets HTTP_PROXY and HTTPS_PROXY environment variables
.DESCRIPTION
    Configures proxy environment variables or clears them for DIRECT connection
.PARAMETER ProxyUrl
    Proxy URL to set (e.g., http://proxy.server.com:8080)
.PARAMETER IsDirect
    Whether connection is direct (no proxy)
.PARAMETER UseFallback
    Use fallback proxy configuration
.PARAMETER FallbackProxyHost
    Fallback proxy host:port (e.g., proxy.company.com:8080)
.PARAMETER CredentialPrefix
    Credential string with format "username:password@" to embed in proxy URL
#>
function Set-ProxyEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialPrefix', Justification = 'CredentialPrefix is a pre-formatted URI component (user:encodedPass@), not a raw password')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProxyUrl,

        [Parameter(Mandatory = $false)]
        [bool]$IsDirect = $false,

        [Parameter(Mandatory = $false)]
        [bool]$UseFallback = $false,

        [Parameter(Mandatory = $false)]
        [string]$FallbackProxyHost,

        [Parameter(Mandatory = $false)]
        [string]$CredentialPrefix = ""
    )

    if ($PSCmdlet.ShouldProcess("HTTP_PROXY and HTTPS_PROXY environment variables", "Set")) {
        if ($UseFallback) {
            $Env:HTTP_PROXY = "http://${CredentialPrefix}$FallbackProxyHost"
            Write-Output "Using fallback proxy: http://$FallbackProxyHost"
        }
        elseif ($IsDirect) {
            $Env:HTTP_PROXY = $null
            $Env:HTTPS_PROXY = $null
        }
        else {
            # Insert credentials into proxy URL if provided
            if ($CredentialPrefix -and $ProxyUrl) {
                $uri = [Uri]$ProxyUrl
                $Env:HTTP_PROXY = "$($uri.Scheme)://${CredentialPrefix}$($uri.Authority)"
            }
            else {
                $Env:HTTP_PROXY = $ProxyUrl
            }
        }

        # Mirror to HTTPS (most tooling uses the same endpoint)
        $Env:HTTPS_PROXY = $Env:HTTP_PROXY
    }
}

<#
.SYNOPSIS
    Initializes DefaultWebProxy for .NET applications
.DESCRIPTION
    Configures [System.Net.WebRequest]::DefaultWebProxy with system or fallback proxy
.PARAMETER UseSystemProxy
    Use system web proxy (PAC-based)
.PARAMETER FallbackProxyHost
    Fallback proxy host:port if not using system proxy
#>
function Initialize-DefaultWebProxy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$UseSystemProxy = $true,

        [Parameter(Mandatory = $false)]
        [string]$FallbackProxyHost
    )

    if ($UseSystemProxy) {
        $systemProxy = Get-SystemWebProxy
        [System.Net.WebRequest]::DefaultWebProxy = $systemProxy
    }
    else {
        $noProxyList = if ($Env:NO_PROXY) { ($Env:NO_PROXY).Split(',') } else { @() }
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy("http://$FallbackProxyHost", $true, $noProxyList)
    }

    # Use current Windows credentials for proxy (Kerberos/NTLM/Negotiate)
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
}

function Test-PxProxyAvailable {
    <#
    .SYNOPSIS
        Returns $true when a TCP listener answers at the px proxy endpoint.

    .DESCRIPTION
        Performs a short, decoupled TCP connect to the host:port parsed from the
        px endpoint. Used to auto-detect a running px so setProxy can target it
        without requiring the explicit -UsePx switch.

    .PARAMETER PxEndpoint
        The px proxy endpoint to probe (e.g. http://127.0.0.1:3128).

    .PARAMETER TimeoutMs
        Connect timeout in milliseconds (default: 500).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$PxEndpoint = "http://127.0.0.1:3128",

        [Parameter(Mandatory = $false)]
        [int]$TimeoutMs = 500
    )

    $client = $null
    try {
        $uri = [Uri]$PxEndpoint
        $client = [System.Net.Sockets.TcpClient]::new()
        $asyncResult = $client.BeginConnect($uri.Host, $uri.Port, $null, $null)
        $connected = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs)
        if ($connected -and $client.Connected) {
            $client.EndConnect($asyncResult)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        if ($client) {
            $client.Close()
        }
    }
}

<#
.SYNOPSIS
    Main orchestration function for proxy configuration
.DESCRIPTION
    Coordinates all proxy setup functions
.PARAMETER ProbeUrl
    URL to probe for proxy resolution (uses script-level default if not provided)
.PARAMETER FallbackProxyHost
    Fallback proxy host:port (uses script-level default if not provided)
.PARAMETER AskForCreds
    If set, prompts user for credentials to embed in proxy environment variables
.PARAMETER UsePx
    If set, always targets the local px proxy endpoint instead of resolving/using the corporate proxy
.PARAMETER NoPx
    If set, forces the corporate-proxy path even when a running px is auto-detected
.PARAMETER PxEndpoint
    The local px proxy endpoint to target/probe (e.g., http://127.0.0.1:3128)
#>
function Initialize-ProxyConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProbeUrl,

        [Parameter(Mandatory = $false)]
        [string]$FallbackProxyHost,

        [Parameter(Mandatory = $false)]
        [switch]$AskForCreds,

        [Parameter(Mandatory = $false)]
        [switch]$UsePx,

        [Parameter(Mandatory = $false)]
        [switch]$NoPx,

        [Parameter(Mandatory = $false)]
        [string]$PxEndpoint = "http://127.0.0.1:3128"
    )

    # Decide whether to target a local px proxy. px is used when explicitly
    # requested (-UsePx) or auto-detected as running, unless -NoPx forces the
    # corporate-proxy path. px handles authentication itself, so no proxy
    # credentials are configured in this branch.
    $shouldUsePx = $false
    if ($NoPx) {
        $shouldUsePx = $false
    } elseif ($UsePx) {
        $shouldUsePx = $true
    } elseif (Test-PxProxyAvailable -PxEndpoint $PxEndpoint) {
        Write-Output "Detected running px proxy at $PxEndpoint; using it automatically (pass -NoPx to override)."
        $shouldUsePx = $true
    }

    if ($shouldUsePx) {
        Write-Output "Using local px proxy: $PxEndpoint"

        $Env:HTTP_PROXY = $PxEndpoint
        $Env:HTTPS_PROXY = $PxEndpoint

        # Always set NO_PROXY
        Set-NoProxyEnvironment

        $noProxyList = if ($Env:NO_PROXY) { ($Env:NO_PROXY).Split(',') } else { @() }
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($PxEndpoint, $true, $noProxyList)

        # Show summary
        Write-Output "HTTP_PROXY/HTTPS_PROXY: $Env:HTTPS_PROXY"
        Write-Output "NO_PROXY: $Env:NO_PROXY"
        return
    }

    # Get credentials if requested. Pre-fill the username with the Windows
    # account so the user can accept it with Enter; the prompt shows it as "[user]".
    $credentialPrefix = ""
    if ($AskForCreds) {
        $credentialPrefix = Get-ProxyCredentialsFromUser -DefaultUser $env:USERNAME
    }

    # Get Internet Setting from registry
    $inetSettings = Get-InternetSettingsFromRegistry

    # Enable proxy in registry if needed
    $null = Enable-ProxyInRegistry -InternetSettings $inetSettings

    # Always set NO_PROXY
    Set-NoProxyEnvironment

    # Check for PAC configuration
    if ($inetSettings -and
        ($inetSettings.PSObject.Properties.Name -contains 'AutoConfigURL') -and
        $inetSettings.AutoConfigURL) {
        Write-Output "AutoConfigURL detected: $($inetSettings.AutoConfigURL)"

        # Initialize-DefaultWebProxy performs the process's FIRST system-proxy
        # resolution, and .NET caches that result for the process lifetime (see
        # Suspend-ProxyEnvVar). If the inherited px override is still set here it
        # seeds the cache, and Get-ProxyFromPac's own clear/restore comes too late
        # to dislodge it -- px would be reported as the corporate proxy. Suspend
        # the vars around both calls so the cache is seeded from the PAC.
        $savedProxyEnv = Suspend-ProxyEnvVar
        try {
            # Initialize DefaultWebProxy with system proxy
            Initialize-DefaultWebProxy -UseSystemProxy $true -FallbackProxyHost $FallbackProxyHost

            # Resolve proxy from PAC
            $proxyInfo = Get-ProxyFromPac -InternetSettings $inetSettings -ProbeUrl $ProbeUrl
        }
        finally {
            Resume-ProxyEnvVar -Saved $savedProxyEnv
        }

        if ($proxyInfo -and $proxyInfo.ContainsKey('IsDirect')) {
            if ($proxyInfo.IsDirect) {
                Write-Output "PAC/System proxy indicates DIRECT for '$ProbeUrl'. Clearing HTTP(S)_PROXY environment variables."
            }
            Set-ProxyEnvironment -ProxyUrl $proxyInfo.ProxyUrl -IsDirect $proxyInfo.IsDirect -FallbackProxyHost $FallbackProxyHost -CredentialPrefix $credentialPrefix
        }
        else {
            # PAC resolution failed, use fallback
            Write-Warning "PAC resolution failed. Using fallback proxy."
            Initialize-DefaultWebProxy -UseSystemProxy $false -FallbackProxyHost $FallbackProxyHost
            Set-ProxyEnvironment -UseFallback $true -FallbackProxyHost $FallbackProxyHost -CredentialPrefix $credentialPrefix
        }
    }
    else {
        # No PAC, use fallback configuration
        Write-Warning "No AutoConfigURL (PAC) detected in registry. System may rely on manual or direct settings."
        Initialize-DefaultWebProxy -UseSystemProxy $false -FallbackProxyHost $FallbackProxyHost
        Set-ProxyEnvironment -UseFallback $true -FallbackProxyHost $FallbackProxyHost -CredentialPrefix $credentialPrefix
    }

    # Show summary (mask credentials if present)
    $maskedProxyUrl = Get-MaskedProxyUrl -ProxyUrl $Env:HTTPS_PROXY
    Write-Output "HTTP_PROXY/HTTPS_PROXY: $maskedProxyUrl"
    Write-Output "NO_PROXY: $Env:NO_PROXY"
}

#endregion

#region Main

# Execute main logic unless in library mode (dot-sourced for function access only)
# Set environment variable SETPROXY_LIBRARY_MODE=1 to expose functions without executing main logic
if (-not $env:SETPROXY_LIBRARY_MODE) {
    Initialize-ProxyConfiguration -ProbeUrl $ProbeUrl -FallbackProxyHost $FallbackProxyHost -AskForCreds:$askForCreds -UsePx:$UsePx -NoPx:$NoPx -PxEndpoint $PxEndpoint
}

#endregion
