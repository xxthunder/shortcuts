#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.DESCRIPTION
    Integration tests for lib/wsl/ca.ps1: the root CA detection reads a real certificate
    chain over the network (SC-060). The trust check against the machine store is covered
    by unit tests and the UAT; whether a public root sits in the runner's store is not
    guaranteed.
#>

Describe "Root CA detection against a real site" -Tag "Integration" {
    BeforeAll {
        . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
        Start-SutIsolation
        . "$PSScriptRoot\wsl.ps1"
    }

    AfterAll {
        Stop-SutIsolation
    }

    It "Should read a self-signed root from the chain of https://www.google.com" {
        $root = Get-TlsChainRoot -Url 'https://www.google.com/'

        $root.Subject | Should -Be $root.Issuer
        $root.Thumbprint | Should -Match '^[0-9A-F]{40}$'
    }
}
