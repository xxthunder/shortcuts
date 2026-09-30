<#
.DESCRIPTION
    Corporate root CA installation into WSL distributions (SC-060). The root certificates
    come from the Windows certificate store, found by URL (Auto: the root of an HTTPS
    site's certificate chain) or by subject pattern (Manual), and scripts/setup-ca.sh
    installs them into the distribution's system trust store.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

# Windows limits a command line to 32767 characters; leave room for wsl.exe, the
# distribution name and the script path in front of the certificate arguments.
$script:WslCaMaxArgumentLength = 30000

# Default URL for Auto: behind TLS inspection its chain ends in the corporate root CA
$script:WslCaDefaultUrl = 'https://www.google.com'

# HttpClient calls its certificate callback on a thread without a PowerShell runspace, so the
# callback is C#. It accepts any certificate: the request is a HEAD, and the caller checks the
# root against the machine store. It returns raw bytes, because the X509Certificate2 byte[]
# constructors are obsolete in .NET 9 and Add-Type turns that warning into an error.
$script:WslCaTlsProbeSource = @'
using System;
using System.Net;
using System.Net.Http;

public static class WslCaTlsProbe
{
    public static byte[] GetChainRootRawData(string url, int timeoutSeconds)
    {
        byte[] root = null;
        using (var handler = new HttpClientHandler())
        {
            handler.DefaultProxyCredentials = CredentialCache.DefaultCredentials;
            handler.ServerCertificateCustomValidationCallback = (message, certificate, chain, errors) =>
            {
                if (chain != null && chain.ChainElements.Count > 0)
                {
                    root = chain.ChainElements[chain.ChainElements.Count - 1].Certificate.RawData;
                }
                return true;
            };
            using (var client = new HttpClient(handler))
            {
                client.Timeout = TimeSpan.FromSeconds(timeoutSeconds);
                using (var request = new HttpRequestMessage(HttpMethod.Head, url))
                using (client.SendAsync(request).GetAwaiter().GetResult())
                {
                }
            }
        }
        if (root == null)
        {
            throw new InvalidOperationException("No certificate chain was received.");
        }
        return root;
    }
}
'@

function ConvertTo-HttpsUrl {
    <#
    .SYNOPSIS
        Turns user input into an absolute HTTPS URL.

    .DESCRIPTION
        A bare host name (with or without a port) gets https:// in front. Anything that is not
        an absolute HTTPS URL with a host is an error: Auto needs a TLS connection.

    .PARAMETER Url
        The URL or host name as entered, e.g. 'www.google.com' or 'https://jira.example.corp'.

    .OUTPUTS
        System.String

    .EXAMPLE
        ConvertTo-HttpsUrl -Url 'www.google.com'
        Returns 'https://www.google.com/'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Url
    )

    $candidate = $Url.Trim()
    if ($candidate -notmatch '^[A-Za-z][A-Za-z0-9+.-]*://') {
        $candidate = "https://$candidate"
    }
    $uri = $null
    if (-not [System.Uri]::TryCreate($candidate, [System.UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or [string]::IsNullOrEmpty($uri.Host)) {
        throw "'$Url' is not an HTTPS URL."
    }
    return $uri.AbsoluteUri
}

function Get-TlsChainRoot {
    <#
    .SYNOPSIS
        Returns the root of the certificate chain Windows builds for an HTTPS site.

    .DESCRIPTION
        Sends a HEAD request through the .NET HttpClient, which uses the system proxy
        (including PAC) and the Windows logon for proxy authentication, or goes direct where
        PAC says so. The last element of the chain built for the server certificate is the
        root: behind TLS inspection the corporate root CA, for an intranet site the root of
        the internal PKI. Whether that root is trusted is checked by the caller.

    .PARAMETER Url
        An absolute HTTPS URL (see ConvertTo-HttpsUrl).

    .PARAMETER TimeoutSeconds
        How long to wait for the site.

    .OUTPUTS
        System.Security.Cryptography.X509Certificates.X509Certificate2

    .EXAMPLE
        Get-TlsChainRoot -Url 'https://www.google.com/'
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [int]$TimeoutSeconds = 30
    )

    if (-not ('WslCaTlsProbe' -as [type])) {
        Add-Type -TypeDefinition $script:WslCaTlsProbeSource
    }
    try {
        $rawData = ('WslCaTlsProbe' -as [type])::GetChainRootRawData($Url, $TimeoutSeconds)
    }
    catch {
        throw "Could not read the certificate chain of $($Url): $($_.Exception.GetBaseException().Message)"
    }
    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]$rawData)
}

function Resolve-TrustedRootCertificate {
    <#
    .SYNOPSIS
        Returns a detected root from Cert:\LocalMachine\Root, or fails when Windows does not trust it.

    .DESCRIPTION
        Only roots the machine trusts are installed into a distribution. A root that is not in
        the local machine root store, or has expired, is an error naming the root and the URL.
        A public site outside TLS inspection yields a public root, which needs no install; the
        message says so.

    .PARAMETER Certificate
        The root read from the site's chain.

    .PARAMETER Url
        The URL the root came from, for the message.

    .OUTPUTS
        System.Security.Cryptography.X509Certificates.X509Certificate2

    .EXAMPLE
        Resolve-TrustedRootCertificate -Certificate (Get-TlsChainRoot -Url $url) -Url $url
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param(
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory)]
        [string]$Url
    )

    $trusted = Get-ChildItem -Path 'Cert:\LocalMachine\Root' |
        Where-Object { $_.Thumbprint -eq $Certificate.Thumbprint } |
        Select-Object -First 1
    if ($null -eq $trusted) {
        throw "The root '$($Certificate.Subject)' ($($Certificate.Thumbprint)) of $Url is not in Cert:\LocalMachine\Root, so it is not installed. A public site outside TLS inspection has a public root, which needs no install."
    }
    if ($trusted.NotAfter -le (Get-Date)) {
        throw "The root '$($trusted.Subject)' of $Url expired on $($trusted.NotAfter.ToString('yyyy-MM-dd'))."
    }
    return $trusted
}

function Get-UrlRootCertificate {
    <#
    .SYNOPSIS
        Returns the trusted roots of one or more HTTPS sites, each root once.

    .DESCRIPTION
        For every URL: normalise it, read the root of its certificate chain and check that
        Windows trusts it. Several sites behind the same TLS inspection share one root, which
        is returned once. The first URL that fails ends the call with its error.

    .PARAMETER Url
        URLs or host names, e.g. 'https://www.google.com', 'jira.example.corp'.

    .OUTPUTS
        System.Security.Cryptography.X509Certificates.X509Certificate2[]

    .EXAMPLE
        Get-UrlRootCertificate -Url 'https://www.google.com', 'https://jira.example.corp'
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2[]])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Url
    )

    $roots = [System.Collections.Generic.List[System.Security.Cryptography.X509Certificates.X509Certificate2]]::new()
    foreach ($entry in $Url) {
        $httpsUrl = ConvertTo-HttpsUrl -Url $entry
        $root = Resolve-TrustedRootCertificate -Certificate (Get-TlsChainRoot -Url $httpsUrl) -Url $httpsUrl
        if (-not ($roots | Where-Object { $_.Thumbprint -eq $root.Thumbprint })) {
            $roots.Add($root)
        }
    }
    return $roots.ToArray()
}

function Get-CorporateRootCertificate {
    <#
    .SYNOPSIS
        Returns the valid root certificates in Cert:\LocalMachine\Root whose subject matches a pattern.

    .DESCRIPTION
        Reads the local machine root store, where group policy deploys corporate root CAs,
        and returns every certificate whose subject matches the wildcard pattern and that
        has not expired. Expired certificates are skipped, so an old root CA that is still
        in the store after a rotation is not installed again. The result is sorted by subject.

    .PARAMETER Subject
        A PowerShell wildcard pattern matched against the whole subject, e.g. '*Contoso*'.
        Without wildcards, only a subject that equals the pattern matches.

    .OUTPUTS
        System.Security.Cryptography.X509Certificates.X509Certificate2

    .EXAMPLE
        Get-CorporateRootCertificate -Subject '*Contoso*'
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Subject
    )

    $now = Get-Date
    Get-ChildItem -Path 'Cert:\LocalMachine\Root' |
        Where-Object { $_.Subject -like $Subject -and $_.NotAfter -gt $now } |
        Sort-Object -Property Subject
}

function ConvertTo-CaCertificateArgument {
    <#
    .SYNOPSIS
        Builds the setup-ca.sh arguments for a set of certificates.

    .DESCRIPTION
        Returns one '--cert=<THUMBPRINT>:<base64 DER>' argument per certificate. The
        certificates travel as arguments, so no temporary file and no Windows path is
        needed inside the distribution. Throws when the arguments would exceed the
        Windows command-line limit, which only a far too broad pattern reaches.

    .PARAMETER Certificate
        The certificates to pass to the script.

    .OUTPUTS
        System.String[]

    .EXAMPLE
        ConvertTo-CaCertificateArgument -Certificate (Get-CorporateRootCertificate -Subject '*Contoso*')
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Certificate
    )

    $arguments = @($Certificate | ForEach-Object {
            "--cert=$($_.Thumbprint.ToUpperInvariant()):$([Convert]::ToBase64String($_.RawData))"
        })

    if (($arguments -join ' ').Length -gt $script:WslCaMaxArgumentLength) {
        throw "The $($Certificate.Count) selected certificates exceed the Windows command-line limit. Narrow the subject pattern."
    }

    return $arguments
}

function Invoke-WslCaScript {
    <#
    .SYNOPSIS
        Runs scripts/setup-ca.sh in a distribution and turns a failure into an error.

    .PARAMETER DistroName
        The distribution to run the script in.

    .PARAMETER Arguments
        The script arguments: '--cert=...' entries, or '--remove'.

    .EXAMPLE
        Invoke-WslCaScript -DistroName 'Debian' -Arguments @('--remove')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DistroName,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $scriptPath = Join-Path $PSScriptRoot "scripts\setup-ca.sh"
    $exitCode = Invoke-WslDistroScript -ScriptPath $scriptPath -DistroName $DistroName -Arguments $Arguments -StopAtError $false -PrintCommand $false

    switch ($exitCode) {
        0 {
            return
        }
        1 {
            throw "Prerequisite check failed in '$DistroName': the ca-certificates package and sudo are required."
        }
        2 {
            throw "Configuration failed in '$DistroName'. Check sudo rights and /usr/local/share/ca-certificates."
        }
        3 {
            throw "Verification failed in '$DistroName': the system CA bundle does not contain the managed certificates."
        }
        4 {
            throw "Argument error. setup-ca.sh rejected the certificate arguments."
        }
        default {
            throw "CA setup failed in '$DistroName' with exit code: $exitCode"
        }
    }
}

function Install-WslCaCertificate {
    <#
    .SYNOPSIS
        Adds the given certificates to the wsl-manager root certificates in a distribution.

    .DESCRIPTION
        Writes each certificate as /usr/local/share/ca-certificates/wsl-manager-<thumbprint>.crt,
        keeps the other wsl-manager certificates, deletes the ones that have expired, and rebuilds
        the system CA bundle. Certificates not named wsl-manager-*.crt are never touched. Running it
        again with the same certificates changes nothing.

    .PARAMETER DistroName
        The name of the WSL distribution.

    .PARAMETER Certificate
        The root certificates to install, e.g. from Get-CorporateRootCertificate.

    .EXAMPLE
        Install-WslCaCertificate -DistroName 'Debian' -Certificate (Get-CorporateRootCertificate -Subject '*Contoso*')
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$Certificate
    )

    Assert-WslDistroExists -DistroName $DistroName
    $arguments = ConvertTo-CaCertificateArgument -Certificate $Certificate

    if (-not $PSCmdlet.ShouldProcess($DistroName, "Install $($Certificate.Count) root CA certificate(s)")) {
        return
    }

    Invoke-WslCaScript -DistroName $DistroName -Arguments $arguments
}

function Remove-WslCaCertificate {
    <#
    .SYNOPSIS
        Removes all wsl-manager root certificates from a distribution.

    .DESCRIPTION
        Deletes /usr/local/share/ca-certificates/wsl-manager-*.crt and rebuilds the system CA
        bundle. Certificates installed by anything else stay.

    .PARAMETER DistroName
        The name of the WSL distribution.

    .EXAMPLE
        Remove-WslCaCertificate -DistroName 'Debian'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName
    )

    Assert-WslDistroExists -DistroName $DistroName

    if (-not $PSCmdlet.ShouldProcess($DistroName, "Remove the wsl-manager root CA certificates")) {
        return
    }

    Invoke-WslCaScript -DistroName $DistroName -Arguments @('--remove')
}
