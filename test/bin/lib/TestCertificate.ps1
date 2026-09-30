<#
.DESCRIPTION
    In-memory root certificates for tests that need real X509Certificate2 objects
    (e.g. lib/wsl/ca.ps1). Nothing is written to a certificate store.
#>

function Get-TestRootCertificate {
    <#
    .SYNOPSIS
        Creates an in-memory, self-signed certificate authority certificate for tests.

    .DESCRIPTION
        Uses an ECDsa key (fast to generate) and marks the certificate as a CA via the
        basic constraints extension. Each call creates a new key, so two certificates
        with the same subject still have different thumbprints. The certificate lives
        only in memory; no certificate store is touched.

    .PARAMETER Subject
        Distinguished name of the certificate, e.g. "CN=Contoso Root CA, O=Contoso".

    .PARAMETER NotAfter
        End of the validity period. Defaults to five years from now; pass a past date
        for an expired certificate. The validity starts ten years before NotAfter.

    .OUTPUTS
        System.Security.Cryptography.X509Certificates.X509Certificate2

    .EXAMPLE
        $expired = Get-TestRootCertificate -Subject "CN=Old Root" -NotAfter (Get-Date).AddDays(-1)
    #>
    [CmdletBinding()]
    [OutputType([System.Security.Cryptography.X509Certificates.X509Certificate2])]
    param(
        [Parameter(Mandatory)]
        [string]$Subject,

        [datetime]$NotAfter = (Get-Date).AddYears(5)
    )

    $key = [System.Security.Cryptography.ECDsa]::Create()
    $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        $Subject, $key, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    $request.CertificateExtensions.Add(
        [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($true, $false, 0, $true))
    return $request.CreateSelfSigned([DateTimeOffset]$NotAfter.AddYears(-10), [DateTimeOffset]$NotAfter)
}
