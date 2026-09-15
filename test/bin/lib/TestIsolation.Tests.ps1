#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.DESCRIPTION
    Pester tests for test/bin/lib/TestIsolation.ps1: the wsl.exe shim that keeps unit tests hermetic.
#>

Describe "Start-SutIsolation wsl.exe shim" {
    BeforeAll {
        . "$PSScriptRoot\TestIsolation.ps1"
    }

    Context "When called from a unit test file" {
        BeforeAll {
            Start-SutIsolation
        }

        AfterAll {
            Stop-SutIsolation
        }

        It "Should replace wsl.exe with a function" {
            (Get-Command wsl.exe).CommandType | Should -Be "Function"
        }

        It "Should route wsl to the same shim" {
            $wsl = Get-Command wsl
            $wsl.CommandType | Should -Be "Alias"
            $wsl.Definition | Should -Be "wsl.exe"
        }

        It "Should throw naming the arguments when wsl.exe is invoked" {
            { wsl.exe --list --verbose } | Should -Throw -ExpectedMessage "*real wsl.exe*--list --verbose*"
        }

        It "Should throw when invoked through wsl" {
            { wsl --version } | Should -Throw -ExpectedMessage "*real wsl.exe*"
        }
    }

    Context "When called from an integration test file" {
        It "Should leave the real wsl.exe in place" {
            $probe = Join-Path $TestDrive "probe.Integration.Tests.ps1"
            $isolation = Join-Path $PSScriptRoot "TestIsolation.ps1"
            Set-Content -Path $probe -Value @"
. '$isolation'
Start-SutIsolation
`$type = (Get-Command wsl.exe).CommandType
Stop-SutIsolation
`$type
"@

            & $probe | Should -Be "Application"
        }
    }

    Context "When Stop-SutIsolation runs" {
        It "Should restore the real wsl.exe and remove the wsl alias" {
            Start-SutIsolation

            Stop-SutIsolation

            (Get-Command wsl.exe).CommandType | Should -Be "Application"
            Get-Alias wsl -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }
}
