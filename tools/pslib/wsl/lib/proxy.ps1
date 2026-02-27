<#
.DESCRIPTION
    WSL proxy configuration functions for setting up corporate proxy settings in distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\..\utils\utils.ps1"

function Install-WslProxy {
    <#
    .SYNOPSIS
        Configures proxy settings inside a WSL distribution.

    .DESCRIPTION
        Reads proxy settings from PowerShell environment variables and configures
        proxy for .bashrc, apt, Docker client, and Podman inside the distribution.

        This function is idempotent - safe to run multiple times (overwrites config).

        Configured targets:
        - ~/.bashrc (managed block with http_proxy, https_proxy, no_proxy)
        - /etc/apt/apt.conf.d/99proxy
        - ~/.docker/config.json (proxies.default)
        - ~/.config/containers/containers.conf ([engine] env)

    .PARAMETER DistroName
        The name of the WSL distribution to configure.

    .PARAMETER ProxyUrl
        The proxy URL. If not provided, reads from $Env:HTTPS_PROXY.

    .PARAMETER NoProxy
        Comma-separated list of hosts to bypass proxy. If not provided, reads
        from $Env:NO_PROXY. Falls back to 'localhost,127.0.0.1'.

    .OUTPUTS
        System.Boolean
        Returns $true if configuration succeeds, $false otherwise.

    .EXAMPLE
        Install-WslProxy -DistroName "Debian" -Confirm:$false
        Configures proxy in Debian using $Env:HTTPS_PROXY and $Env:NO_PROXY.

    .EXAMPLE
        Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -NoProxy "localhost,127.0.0.1" -Confirm:$false
        Configures proxy in Debian with explicit values.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory = $false)]
        [string]$ProxyUrl,

        [Parameter(Mandatory = $false)]
        [string]$NoProxy
    )

    # 1. Resolve proxy URL
    if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
        $ProxyUrl = $Env:HTTPS_PROXY
    }
    if ([string]::IsNullOrWhiteSpace($ProxyUrl)) {
        throw @"
No proxy URL provided and `$Env:HTTPS_PROXY is not set.

Either pass -ProxyUrl or set the environment variable first:
  `$Env:HTTPS_PROXY = 'http://your-proxy:8080'

Or run setProxy.ps1 -askForCreds to configure proxy environment variables.
"@
    }

    # 2. Resolve no-proxy list
    if ([string]::IsNullOrWhiteSpace($NoProxy)) {
        $NoProxy = $Env:NO_PROXY
    }
    if ([string]::IsNullOrWhiteSpace($NoProxy)) {
        $NoProxy = "localhost,127.0.0.1"
        Write-Information "NO_PROXY not set, using default: $NoProxy"
    }

    # 3. Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

    # 4. Detect default user
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

    # 5. SupportsShouldProcess
    if (-not $PSCmdlet.ShouldProcess(
            "Proxy configuration in '$DistroName'",
            "Configure proxy settings (.bashrc, apt, Docker, Podman)",
            "Confirm Proxy Setup"
        )) {
        return $false
    }

    Write-Information "Configuring proxy in '$DistroName' ..."
    Write-Information "  Proxy URL: $ProxyUrl"
    Write-Information "  No Proxy:  $NoProxy"
    Write-Information "  User:      $username"
    Write-Information ""

    try {
        $scriptPath = Join-Path $PSScriptRoot "..\scripts\setup-proxy.sh"

        $scriptArgs = @(
            "--proxy-url=$ProxyUrl",
            "--no-proxy=$NoProxy",
            "--username=$username"
        )

        $exitCode = Invoke-WslDistroScript -ScriptPath $scriptPath -DistroName $DistroName -Arguments $scriptArgs -StopAtError $false -PrintCommand $false -AsRoot $true

        switch ($exitCode) {
            0 {
                Write-Information ""
                Write-Information "Successfully configured proxy in '$DistroName'."
                Write-Information ""
                Write-Information "Configured targets:"
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
