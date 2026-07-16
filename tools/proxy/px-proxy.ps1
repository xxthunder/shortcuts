#Requires -Version 7.4

<#
.SYNOPSIS
    Manage a local px authenticating proxy for Windows and WSL.

.DESCRIPTION
    px authenticates to a corporate upstream proxy using the current Windows
    logon session (SSPI: NTLM or Negotiate/Kerberos) and exposes a plain local
    proxy on http://127.0.0.1:3128. Native CLI tools (git, pip, node, curl,
    Claude Code) and WSL distros (mirrored networking) point at that endpoint
    and reach the internet with no credentials stored anywhere.

    Actions:
      install  Install px via Scoop (only if not already present) and create
               the px data directory. Does NOT resolve the proxy or write config.
      start    Resolve the upstream proxy fresh, (re)write the px config, and
               (re)start px so the running instance always reflects the current
               network. Exactly one px instance results.
      stop     Stop any running px cleanly.
      test     Send an HTTPS request through the local px endpoint and report a
               clear diagnostic (auth vs TLS/cert vs revocation).
      remove   Stop px, uninstall it (only if this tool installed it), and delete
               the px config and log files.

.PARAMETER Action
    One of: install, start, stop, test, remove. Defaults to 'start'.

.PARAMETER ProxyHost
    Optional manual upstream proxy 'host:port'. When provided, overrides
    PAC/klist discovery for the 'start' action.

.EXAMPLE
    .\px-proxy.ps1 install

.EXAMPLE
    .\px-proxy.ps1 start

.EXAMPLE
    .\px-proxy.ps1 test
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('install', 'start', 'stop', 'test', 'remove')]
    [string]$Action = 'start',

    [Parameter(Mandatory = $false)]
    [string]$ProxyHost
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Dependencies ---------------------------------------------------------
. "$PSScriptRoot\..\..\lib\utils\utils.ps1"

# Source setProxy.ps1 in library mode to reuse its PAC-resolution helpers
# (Get-InternetSettingsFromRegistry, Get-ProxyFromPac) without executing main.
$script:PreviousSetProxyLibMode = $env:SETPROXY_LIBRARY_MODE
$env:SETPROXY_LIBRARY_MODE = '1'
try {
    . "$PSScriptRoot\setProxy.ps1"
}
finally {
    if ($null -eq $script:PreviousSetProxyLibMode) {
        Remove-Item Env:\SETPROXY_LIBRARY_MODE -ErrorAction SilentlyContinue
    }
    else {
        $env:SETPROXY_LIBRARY_MODE = $script:PreviousSetProxyLibMode
    }
}

# --- Constants ------------------------------------------------------------
$script:PxListen = '127.0.0.1'
$script:PxPort = 3128
$script:PxEndpoint = "http://${script:PxListen}:${script:PxPort}"
$script:PxDefaultUpstreamPort = 8080
$script:PxInstalledMarkerName = 'installed-by-px-proxy.marker'

# --- Path helpers ---------------------------------------------------------
function Get-PxDataDir {
    <#
    .SYNOPSIS
        Returns the px data directory (config and logs), creating nothing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return (Join-Path $env:USERPROFILE '.config\px')
}

function Get-PxConfigPath {
    <#
    .SYNOPSIS
        Returns the full path to the px config file (px.ini).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return (Join-Path (Get-PxDataDir) 'px.ini')
}

function Get-PxInstalledMarkerPath {
    <#
    .SYNOPSIS
        Returns the path to the marker written when this tool installed px.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return (Join-Path (Get-PxDataDir) $script:PxInstalledMarkerName)
}

# --- px discovery ---------------------------------------------------------
function Test-PxInstalled {
    <#
    .SYNOPSIS
        Returns $true when a px executable is available (Scoop shim or pipx).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Get-Command 'px' -ErrorAction SilentlyContinue)
}

function Get-PxExecutable {
    <#
    .SYNOPSIS
        Resolves the px (or windowless pxw) executable path.

    .PARAMETER Windowless
        Prefer the windowless 'pxw' variant (no console window).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Windowless
    )

    $name = if ($Windowless) { 'pxw' } else { 'px' }

    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    # Fallback: look for the requested variant next to px, else use px itself.
    $px = Get-Command 'px' -ErrorAction SilentlyContinue
    if ($px) {
        $candidate = Join-Path (Split-Path $px.Source -Parent) "$name.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
        return $px.Source
    }

    return $null
}

function Test-PxRunning {
    <#
    .SYNOPSIS
        Returns $true when a px or pxw process is currently running.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $procs = Get-Process -Name 'px', 'pxw' -ErrorAction SilentlyContinue
    return [bool]$procs
}

# --- Upstream proxy resolution -------------------------------------------
function Get-KlistOutput {
    <#
    .SYNOPSIS
        Thin wrapper around the external 'klist' command (mockable in tests).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return (klist 2>$null)
}

function Get-KerberosProxyHost {
    <#
    .SYNOPSIS
        Extracts an 'HTTP/<host>' service-ticket host from klist output.

    .DESCRIPTION
        Returns '<host>:<default port>' when a Kerberos HTTP SPN is present in
        the current logon session, otherwise $null. Used as a fallback when PAC
        evaluation yields no proxy.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $output = $null
    try {
        $output = Get-KlistOutput
    }
    catch {
        return $null
    }

    if (-not $output) {
        return $null
    }

    foreach ($line in $output) {
        if ($line -match 'HTTP/(?<host>[A-Za-z0-9._-]+)') {
            $candidate = "{0}:{1}" -f $Matches['host'], $script:PxDefaultUpstreamPort
            # The ticket cache holds an HTTP/ SPN for every intranet site this
            # session has touched, not just the proxy. Take the first one, but
            # never let the guess pass silently -- a wrong host surfaces as a 407.
            Write-Warning "Guessing the upstream proxy is '$candidate': it is the first HTTP/ ticket in your klist cache and the port is a default. If requests fail, re-run with -ProxyHost '<host:port>'."
            return $candidate
        }
    }

    return $null
}

function Resolve-PxUpstreamProxy {
    <#
    .SYNOPSIS
        Resolves the real upstream proxy 'host:port' for px.

    .DESCRIPTION
        Resolution order:
          1. Explicit -ProxyHost override.
          2. PAC evaluation via setProxy.ps1's Get-ProxyFromPac (the real proxy
             the PAC hands out, which carries the Kerberos SPN).
          3. klist-derived HTTP/<host> SPN fallback.
          4. Manual prompt (interactive sessions only).

    .PARAMETER ProxyHost
        Optional manual override.

    .PARAMETER ProbeUrl
        URL used to evaluate the PAC (default: https://www.google.com).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProxyHost,

        [Parameter(Mandatory = $false)]
        [string]$ProbeUrl = 'https://www.google.com'
    )

    if (-not [string]::IsNullOrWhiteSpace($ProxyHost)) {
        return $ProxyHost.Trim()
    }

    # 1. PAC evaluation (reuse setProxy.ps1 helpers)
    $settings = Get-InternetSettingsFromRegistry
    if ($settings) {
        $pac = Get-ProxyFromPac -InternetSettings $settings -ProbeUrl $ProbeUrl
        if ($pac -and $pac.ContainsKey('IsDirect') -and -not $pac.IsDirect -and $pac.ProxyUrl) {
            $authority = ([Uri]$pac.ProxyUrl).Authority
            if (-not [string]::IsNullOrWhiteSpace($authority)) {
                Write-Information "Resolved upstream proxy via PAC: $authority"
                return $authority
            }
        }
    }

    # 2. klist SPN fallback
    $spnHost = Get-KerberosProxyHost
    if ($spnHost) {
        return $spnHost
    }

    # 3. Manual prompt (interactive only)
    if (-not (Test-RunningInCIorTestEnvironment)) {
        $manual = Read-Host "Could not auto-resolve the upstream proxy. Enter proxy host:port (e.g. proxy.corp:8080)"
        if (-not [string]::IsNullOrWhiteSpace($manual)) {
            return $manual.Trim()
        }
    }

    throw "Could not resolve an upstream proxy host (PAC returned DIRECT/none, no Kerberos SPN found, no manual entry). Re-run with -ProxyHost '<host:port>'."
}

# --- px config ------------------------------------------------------------
function Write-PxConfig {
    <#
    .SYNOPSIS
        (Re)writes the px config from the resolved upstream proxy.

    .DESCRIPTION
        Overwrites px.ini every call. Enables logging (log = 3: unique
        debug-<pid>.log in px's working directory, which start sets to the px
        data directory). Raises idle/socktimeout above px's defaults so long
        AI agent requests (e.g. Copilot CLI, Claude Code) don't get dropped
        mid-response.

    .PARAMETER UpstreamProxy
        The upstream proxy 'host:port' px authenticates to.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UpstreamProxy
    )

    $dir = Get-PxDataDir
    New-Directory -Path $dir

    $configPath = Get-PxConfigPath

    $content = @"
[proxy]
server = $UpstreamProxy
listen = $script:PxListen
port = $script:PxPort
auth =

[settings]
log = 3
idle = 60
socktimeout = 300.0
"@

    if ($PSCmdlet.ShouldProcess($configPath, "Write px config")) {
        Set-Content -Path $configPath -Value $content -Encoding ascii
    }

    return $configPath
}

# --- Actions --------------------------------------------------------------
function Install-PxProxy {
    <#
    .SYNOPSIS
        Installs px via Scoop when absent and ensures the data directory exists.
    #>
    [CmdletBinding()]
    param()

    New-Directory -Path (Get-PxDataDir)

    if (Test-PxInstalled) {
        Write-Information "px is already installed; skipping Scoop install."
        return
    }

    Write-Information "Installing px via Scoop ..."
    Invoke-CommandLine -CommandLine 'scoop install px' -StopAtError $true
    Set-Content -Path (Get-PxInstalledMarkerPath) -Value (Get-Date -Format 'o') -Encoding ascii
    Write-Information "px installed."
}

function Stop-PxProxy {
    <#
    .SYNOPSIS
        Stops any running px instance cleanly.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not (Test-PxRunning)) {
        Write-Information "px is not running."
        return
    }

    if (-not $PSCmdlet.ShouldProcess('px', 'Stop running px instance')) {
        return
    }

    $px = Get-PxExecutable
    if ($px) {
        Invoke-CommandLine -CommandLine "& `"$px`" --quit" -StopAtError $false -PrintCommand $false
    }

    Start-Sleep -Milliseconds 300

    if (Test-PxRunning) {
        Get-Process -Name 'px', 'pxw' -ErrorAction SilentlyContinue |
            ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
    }

    Write-Information "px stopped."
}

function Start-PxProxy {
    <#
    .SYNOPSIS
        Resolves the proxy, rewrites config, and (re)starts px.

    .PARAMETER ProxyHost
        Optional manual upstream 'host:port' override.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProxyHost
    )

    # Fail before resolving (which may prompt) or writing a config we cannot use.
    $exe = Get-PxExecutable -Windowless
    if (-not $exe) {
        throw "px executable not found. Run 'px-proxy install' first."
    }

    $upstream = Resolve-PxUpstreamProxy -ProxyHost $ProxyHost

    if (-not $PSCmdlet.ShouldProcess("px ($upstream)", 'Rewrite config and restart px')) {
        return
    }

    $configPath = Write-PxConfig -UpstreamProxy $upstream

    # Always restart so the running instance reflects the fresh config.
    if (Test-PxRunning) {
        Stop-PxProxy
    }

    $dir = Get-PxDataDir
    Start-Process -FilePath $exe -ArgumentList "--config=`"$configPath`"" -WorkingDirectory $dir -WindowStyle Hidden | Out-Null

    Write-Information "px started (upstream $upstream). Listening on $script:PxEndpoint. Log: $dir\debug-*.log"
}

function Test-PxProxy {
    <#
    .SYNOPSIS
        Sends an HTTPS request through the local px endpoint and diagnoses.

    .PARAMETER Url
        HTTPS URL to probe (default: https://www.google.com).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Url = 'https://www.google.com'
    )

    $logHint = "px log: $(Get-PxDataDir)\debug-*.log"

    try {
        $response = Invoke-WebRequest -Uri $Url -Proxy $script:PxEndpoint -UseBasicParsing -TimeoutSec 20
        Write-Information "SUCCESS: $Url returned HTTP $($response.StatusCode) via $script:PxEndpoint. No credentials were entered."
        return $true
    }
    catch {
        $message = $_.Exception.Message
        $status = $null
        if (($_.Exception.PSObject.Properties.Name -contains 'Response') -and $_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = $null }
        }

        if ($status -eq 407) {
            Write-Warning "FAILED (407 Proxy Authentication Required): px could not authenticate to the upstream proxy. Confirm the resolved proxy host carries a Kerberos SPN (klist should list HTTP/<host>). $logHint"
        }
        elseif ($message -match 'revocation|revoc|CRL') {
            Write-Warning "TLS revocation check failed: Schannel could not reach the certificate revocation endpoint. This is often benign behind TLS inspection (the 'curl --ssl-no-revoke' scenario). Ensure the corporate root CA is trusted. $logHint"
        }
        elseif ($message -match 'certificate|trust|SSL|TLS|cert') {
            Write-Warning "TLS/certificate error: import the corporate root CA into the Windows trust store. $logHint"
        }
        else {
            Write-Warning "FAILED: $message. Is px running? (px-proxy start). $logHint"
        }

        return $false
    }
}

function Remove-PxProxy {
    <#
    .SYNOPSIS
        Stops px, uninstalls it if this tool installed it, and deletes config/logs.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess('px', 'Stop, uninstall (if installed by this tool), and delete config/logs')) {
        return
    }

    Stop-PxProxy

    $marker = Get-PxInstalledMarkerPath
    if (Test-Path $marker) {
        if (Test-PxInstalled) {
            Write-Information "Uninstalling px via Scoop ..."
            Invoke-CommandLine -CommandLine 'scoop uninstall px' -StopAtError $false
            # Keep the marker unless the uninstall actually ran, so a later
            # 'remove' from a shell with px on PATH can still clean it up.
            Remove-Item $marker -ErrorAction SilentlyContinue
        }
        else {
            Write-Warning "px is not on PATH, so it was not uninstalled. Keeping the install marker at '$marker'; re-run 'px-proxy remove' from a shell where 'px' resolves."
        }
    }

    $configPath = Get-PxConfigPath
    if (Test-Path $configPath) {
        Remove-Item $configPath -ErrorAction SilentlyContinue
    }

    $dir = Get-PxDataDir
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Filter 'debug-*.log' -ErrorAction SilentlyContinue |
            Remove-Item -ErrorAction SilentlyContinue
    }

    Write-Information "px removed (config and logs deleted)."
}

function Invoke-PxProxy {
    <#
    .SYNOPSIS
        Dispatches a px-proxy action.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('install', 'start', 'stop', 'test', 'remove')]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$ProxyHost
    )

    switch ($Action) {
        'install' { Install-PxProxy }
        'start' { Start-PxProxy -ProxyHost $ProxyHost }
        'stop' { Stop-PxProxy }
        'test' {
            if (-not (Test-PxProxy)) {
                throw "the HTTPS probe through $script:PxEndpoint did not succeed (see the warning above)."
            }
        }
        'remove' { Remove-PxProxy }
    }
}

function Invoke-PxProxyMain {
    <#
    .SYNOPSIS
        Runs an action and maps the outcome to a process exit code.

    .DESCRIPTION
        Split from the entry-point guard so the error handling is reachable from
        tests: the guard itself can only ever run when the script is invoked as a
        program, never when it is dot-sourced.

    .OUTPUTS
        0 on success, 1 on failure.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('install', 'start', 'stop', 'test', 'remove')]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$ProxyHost
    )

    try {
        Invoke-PxProxy -Action $Action -ProxyHost $ProxyHost
        return 0
    }
    catch {
        # -ErrorAction Continue: the script sets $ErrorActionPreference = 'Stop',
        # which would otherwise make Write-Error terminating and skip the exit.
        Write-Error "px-proxy '$Action' failed: $_" -ErrorAction Continue
        return 1
    }
}

# --- Main -----------------------------------------------------------------
if (-not $env:PXPROXY_LIBRARY_MODE) {
    exit (Invoke-PxProxyMain -Action $Action -ProxyHost $ProxyHost)
}
