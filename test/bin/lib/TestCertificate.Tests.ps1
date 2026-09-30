#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.DESCRIPTION
    Pester tests for test/bin/lib/TestCertificate.ps1: in-memory root certificates for tests.
#>

BeforeAll {
    . "$PSScriptRoot\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\TestCertificate.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Get-TestRootCertificate" {
    It "Should create a certificate with the given subject" {
        $certificate = Get-TestRootCertificate -Subject "CN=Test Root, O=Contoso"

        $certificate.Subject | Should -Be "CN=Test Root, O=Contoso"
    }

    It "Should be valid for years by default" {
        $certificate = Get-TestRootCertificate -Subject "CN=Test Root"

        $certificate.NotAfter | Should -BeGreaterThan (Get-Date).AddYears(1)
    }

    It "Should expire at the given time" {
        $certificate = Get-TestRootCertificate -Subject "CN=Old Root" -NotAfter (Get-Date).AddDays(-1)

        $certificate.NotAfter | Should -BeLessThan (Get-Date)
    }

    It "Should mark the certificate as a certificate authority" {
        $certificate = Get-TestRootCertificate -Subject "CN=Test Root"

        $constraints = $certificate.Extensions |
            Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension] }
        $constraints.CertificateAuthority | Should -BeTrue
    }

    It "Should create a different certificate on every call" {
        $first = Get-TestRootCertificate -Subject "CN=Test Root"
        $second = Get-TestRootCertificate -Subject "CN=Test Root"

        $first.Thumbprint | Should -Not -Be $second.Thumbprint
    }
}
