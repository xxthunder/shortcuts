<#
.SYNOPSIS
    MQ proxy settings for PowerShell using PAC resolution (no hardcoded proxy hosts)
.DESCRIPTION
    Reads PAC/Internet Settings from the registry and uses the system web proxy
    to determine the effective proxy. Sets PowerShell's default proxy and common
    environment variables for tools (git, Python, etc.).
#>

Param(
    [string]$ProbeUrl         # Optional: URL to probe for proxy resolution (defaults if not provided)
)

Set-StrictMode -Version Latest
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
function Get-InternetSetting {
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
#>
function Set-ProxyEnvironment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProxyUrl,

        [Parameter(Mandatory = $false)]
        [bool]$IsDirect = $false,

        [Parameter(Mandatory = $false)]
        [bool]$UseFallback = $false
    )

    if ($PSCmdlet.ShouldProcess("HTTP_PROXY and HTTPS_PROXY environment variables", "Set")) {
        if ($UseFallback) {
            $fallbackHost = 'some.fallback.de:8080'
            $Env:HTTP_PROXY = "http://$fallbackHost"
            Write-Output "Using fallback proxy: $Env:HTTP_PROXY"
        }
        elseif ($IsDirect) {
            $Env:HTTP_PROXY = $null
            $Env:HTTPS_PROXY = $null
        }
        else {
            $Env:HTTP_PROXY = $ProxyUrl
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
        [string]$FallbackProxyHost = 'some.fallback.de:8080'
    )

    if ($UseSystemProxy) {
        $systemProxy = Get-SystemWebProxy
        [System.Net.WebRequest]::DefaultWebProxy = $systemProxy
    }
    else {
        $noProxyList = ($Env:NO_PROXY).Split(',')
        [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy("http://$FallbackProxyHost", $true, $noProxyList)
    }

    # Use current Windows credentials for proxy (Kerberos/NTLM/Negotiate)
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
}

<#
.SYNOPSIS
    Main orchestration function for proxy configuration
.DESCRIPTION
    Coordinates all proxy setup functions
.PARAMETER ProbeUrl
    Optional URL to probe for proxy resolution
#>
function Initialize-ProxyConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProbeUrl = "https://www.microsoft.com"
    )

    # Get Internet Setting from registry
    $inetSettings = Get-InternetSetting

    # Enable proxy in registry if needed
    $null = Enable-ProxyInRegistry -InternetSettings $inetSettings

    # Always set NO_PROXY
    Set-NoProxyEnvironment

    # Check for PAC configuration
    if ($inetSettings -and
        ($inetSettings.PSObject.Properties.Name -contains 'AutoConfigURL') -and
        $inetSettings.AutoConfigURL) {
        Write-Output "AutoConfigURL detected: $($inetSettings.AutoConfigURL)"

        # Initialize DefaultWebProxy with system proxy
        Initialize-DefaultWebProxy -UseSystemProxy $true

        # Resolve proxy from PAC
        $proxyInfo = Get-ProxyFromPac -InternetSettings $inetSettings -ProbeUrl $ProbeUrl

        if ($proxyInfo -and $proxyInfo.ContainsKey('IsDirect')) {
            if ($proxyInfo.IsDirect) {
                Write-Output "PAC/System proxy indicates DIRECT for '$ProbeUrl'. Clearing HTTP(S)_PROXY environment variables."
            }
            Set-ProxyEnvironment -ProxyUrl $proxyInfo.ProxyUrl -IsDirect $proxyInfo.IsDirect
        }
        else {
            # PAC resolution failed, use fallback
            Write-Warning "PAC resolution failed. Using fallback proxy."
            Initialize-DefaultWebProxy -UseSystemProxy $false
            Set-ProxyEnvironment -UseFallback $true
        }
    }
    else {
        # No PAC, use fallback configuration
        Write-Warning "No AutoConfigURL (PAC) detected in registry. System may rely on manual or direct settings."
        Initialize-DefaultWebProxy -UseSystemProxy $false
        Set-ProxyEnvironment -UseFallback $true
    }

    # Show summary
    Write-Output "HTTP_PROXY/HTTPS_PROXY: $Env:HTTPS_PROXY"
    Write-Output "NO_PROXY: $Env:NO_PROXY"
}

#endregion

#region Main

# Execute main logic unless explicitly in test mode
# Set environment variable SETPROXY_TEST_MODE=1 in tests to prevent auto-execution
if (-not $env:SETPROXY_TEST_MODE) {
    if ($ProbeUrl) {
        Initialize-ProxyConfiguration -ProbeUrl $ProbeUrl
    }
    else {
        Initialize-ProxyConfiguration
    }
}

#endregion
