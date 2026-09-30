<#
.DESCRIPTION
    Pester tests for lib/wsl/ca.ps1 - corporate root CA installation into WSL distributions
#>

param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\wsl.ps1"
    . "$PSScriptRoot\..\..\test\bin\lib\TestCertificate.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Get-CorporateRootCertificate" {
    BeforeAll {
        $script:rootA = Get-TestRootCertificate -Subject "CN=Contoso Root CA A, O=Contoso"
        $script:rootB = Get-TestRootCertificate -Subject "CN=Contoso Root CA B, O=Contoso"
        $script:other = Get-TestRootCertificate -Subject "CN=Public Root, O=Somebody"
        $script:expired = Get-TestRootCertificate -Subject "CN=Contoso Old Root, O=Contoso" -NotAfter (Get-Date).AddDays(-1)
    }

    BeforeEach {
        Mock Get-ChildItem { @($script:rootB, $script:other, $script:expired, $script:rootA) } -ParameterFilter { $Path -eq 'Cert:\LocalMachine\Root' }
    }

    It "Should read the local machine root store" {
        Get-CorporateRootCertificate -Subject "*Contoso*" | Out-Null

        Should -Invoke Get-ChildItem -Times 1 -ParameterFilter { $Path -eq 'Cert:\LocalMachine\Root' }
    }

    It "Should return every valid certificate whose subject matches, sorted by subject" {
        $result = @(Get-CorporateRootCertificate -Subject "*Contoso Root*")

        $result.Thumbprint | Should -Be @($script:rootA.Thumbprint, $script:rootB.Thumbprint)
    }

    It "Should skip expired certificates" {
        $result = @(Get-CorporateRootCertificate -Subject "*Old Root*")

        $result.Count | Should -Be 0
    }

    It "Should match the whole subject when the pattern has no wildcard" {
        $result = @(Get-CorporateRootCertificate -Subject "Contoso")

        $result.Count | Should -Be 0
    }
}

Describe "ConvertTo-CaCertificateArgument" {
    BeforeAll {
        $script:certA = Get-TestRootCertificate -Subject "CN=A"
        $script:certB = Get-TestRootCertificate -Subject "CN=B"
    }

    It "Should build one --cert argument per certificate from thumbprint and DER" {
        $result = @(ConvertTo-CaCertificateArgument -Certificate @($script:certA, $script:certB))

        $result | Should -Be @(
            "--cert=$($script:certA.Thumbprint):$([Convert]::ToBase64String($script:certA.RawData))",
            "--cert=$($script:certB.Thumbprint):$([Convert]::ToBase64String($script:certB.RawData))"
        )
    }

    It "Should build identical arguments on a repeated run" {
        $first = ConvertTo-CaCertificateArgument -Certificate $script:certA
        $second = ConvertTo-CaCertificateArgument -Certificate $script:certA

        $first | Should -Be $second
    }

    It "Should pass only the selected certificates, so the script drops the others" {
        $result = @(ConvertTo-CaCertificateArgument -Certificate $script:certB)

        $result.Count | Should -Be 1
        $result[0] | Should -Not -BeLike "*$($script:certA.Thumbprint)*"
    }

    It "Should refuse a selection that exceeds the command-line limit" {
        $many = 1..80 | ForEach-Object { Get-TestRootCertificate -Subject "CN=Root $_" }

        { ConvertTo-CaCertificateArgument -Certificate $many } | Should -Throw "*Narrow the subject pattern*"
    }
}

Describe "Install-WslCaCertificate" {
    BeforeAll {
        $script:cert = Get-TestRootCertificate -Subject "CN=Contoso Root CA"
    }

    BeforeEach {
        Mock Assert-WslDistroExists { }
        Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
    }

    It "Should run setup-ca.sh with the certificate argument" {
        Install-WslCaCertificate -DistroName "Debian" -Certificate $script:cert -Confirm:$false

        Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
            $ScriptPath -like "*scripts?setup-ca.sh" -and
            $DistroName -eq "Debian" -and
            @($Arguments).Count -eq 1 -and
            $Arguments[0] -like "--cert=$($script:cert.Thumbprint):*"
        }
    }

    It "Should throw '<Message>' when the script exits with <Code>" -ForEach @(
        @{ Code = 1; Message = "*Prerequisite check failed*ca-certificates*" }
        @{ Code = 2; Message = "*Configuration failed*" }
        @{ Code = 3; Message = "*Verification failed*" }
        @{ Code = 4; Message = "*Argument error*" }
        @{ Code = 9; Message = "*exit code: 9*" }
    ) {
        $exitCode = $Code
        Mock Invoke-WslDistroScript { $global:LASTEXITCODE = $exitCode; return $exitCode }

        { Install-WslCaCertificate -DistroName "Debian" -Certificate $script:cert -Confirm:$false } | Should -Throw $Message
    }

    It "Should not run the script when the distribution does not exist" {
        Mock Assert-WslDistroExists { throw "Distribution 'Nope' not found" }

        { Install-WslCaCertificate -DistroName "Nope" -Certificate $script:cert -Confirm:$false } | Should -Throw "*not found*"

        Should -Invoke Invoke-WslDistroScript -Times 0
    }

    It "Should not run the script with -WhatIf" {
        Install-WslCaCertificate -DistroName "Debian" -Certificate $script:cert -WhatIf

        Should -Invoke Invoke-WslDistroScript -Times 0
    }
}

Describe "Remove-WslCaCertificate" {
    BeforeEach {
        Mock Assert-WslDistroExists { }
        Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
    }

    It "Should run setup-ca.sh with --remove only" {
        Remove-WslCaCertificate -DistroName "Debian" -Confirm:$false

        Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
            $ScriptPath -like "*scripts?setup-ca.sh" -and (@($Arguments) -join ' ') -eq '--remove'
        }
    }

    It "Should throw when the script fails" {
        Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

        { Remove-WslCaCertificate -DistroName "Debian" -Confirm:$false } | Should -Throw "*Configuration failed*"
    }

    It "Should not run the script with -WhatIf" {
        Remove-WslCaCertificate -DistroName "Debian" -WhatIf

        Should -Invoke Invoke-WslDistroScript -Times 0
    }
}

Describe "ConvertTo-HttpsUrl" {
    It "Should turn '<Given>' into '<Expected>'" -ForEach @(
        @{ Given = 'www.google.com'; Expected = 'https://www.google.com/' }
        @{ Given = ' https://jira.example.corp/browse '; Expected = 'https://jira.example.corp/browse' }
        @{ Given = 'git.example.corp:8443'; Expected = 'https://git.example.corp:8443/' }
    ) {
        ConvertTo-HttpsUrl -Url $Given | Should -Be $Expected
    }

    It "Should reject '<Given>'" -ForEach @(
        @{ Given = 'http://jira.example.corp' }
        @{ Given = 'ftp://files.example.corp' }
        @{ Given = 'https://' }
    ) {
        { ConvertTo-HttpsUrl -Url $Given } | Should -Throw "*is not an HTTPS URL*"
    }
}

Describe "Get-TlsChainRoot" {
    It "Should name the URL when the host cannot be reached" {
        { Get-TlsChainRoot -Url 'https://localhost:1/' -TimeoutSeconds 5 } | Should -Throw "*Could not read the certificate chain of https://localhost:1/*"
    }
}

Describe "Resolve-TrustedRootCertificate" {
    BeforeAll {
        $script:trustedRoot = Get-TestRootCertificate -Subject "CN=Contoso Root CA"
        $script:expiredRoot = Get-TestRootCertificate -Subject "CN=Contoso Old Root" -NotAfter (Get-Date).AddDays(-1)
        $script:publicRoot = Get-TestRootCertificate -Subject "CN=Public Root"
    }

    BeforeEach {
        Mock Get-ChildItem { @($script:trustedRoot, $script:expiredRoot) } -ParameterFilter { $Path -eq 'Cert:\LocalMachine\Root' }
    }

    It "Should return the certificate from the machine root store" {
        $result = Resolve-TrustedRootCertificate -Certificate $script:trustedRoot -Url 'https://www.google.com/'
        $result.Thumbprint | Should -Be $script:trustedRoot.Thumbprint
    }

    It "Should refuse a root that is not in the machine root store, and say that a public root needs no install" {
        { Resolve-TrustedRootCertificate -Certificate $script:publicRoot -Url 'https://www.google.com/' } |
            Should -Throw "*CN=Public Root*not in Cert:\LocalMachine\Root*public*"
    }

    It "Should refuse an expired root" {
        { Resolve-TrustedRootCertificate -Certificate $script:expiredRoot -Url 'https://www.google.com/' } |
            Should -Throw "*expired*"
    }
}

Describe "Get-UrlRootCertificate" {
    BeforeAll {
        $script:rootA = Get-TestRootCertificate -Subject "CN=Contoso Inspection Root"
        $script:rootB = Get-TestRootCertificate -Subject "CN=Contoso PKI Root"
    }

    BeforeEach {
        Mock Get-ChildItem { @($script:rootA, $script:rootB) } -ParameterFilter { $Path -eq 'Cert:\LocalMachine\Root' }
        Mock Get-TlsChainRoot { if ($Url -like '*jira*') { $script:rootB } else { $script:rootA } }
    }

    It "Should normalise each URL and return its trusted root" {
        $result = @(Get-UrlRootCertificate -Url 'www.google.com')

        $result.Thumbprint | Should -Be @($script:rootA.Thumbprint)
        Should -Invoke Get-TlsChainRoot -Times 1 -ParameterFilter { $Url -eq 'https://www.google.com/' }
    }

    It "Should return each root once when several URLs share it" {
        $result = @(Get-UrlRootCertificate -Url 'https://www.google.com', 'https://github.com', 'https://jira.example.corp')

        $result.Thumbprint | Should -Be @($script:rootA.Thumbprint, $script:rootB.Thumbprint)
    }

    It "Should fail on the first URL whose root is not trusted" {
        Mock Get-ChildItem { @($script:rootA) } -ParameterFilter { $Path -eq 'Cert:\LocalMachine\Root' }

        { Get-UrlRootCertificate -Url 'https://www.google.com', 'https://jira.example.corp' } | Should -Throw "*jira.example.corp*"
    }
}
