<#
.DESCRIPTION
    Pester tests for lib/podman.ps1 - WSL rootless Podman installation and detection
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\wsl.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Test-WslPodmanInstalled" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Test-WslPodmanInstalled -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When Podman is installed" {
        It "Should return true when podman --version succeeds" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "podman version 4.3.1"
            } -ParameterFilter { $Command -like "*podman --version*" }

            $result = Test-WslPodmanInstalled -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should execute podman --version command" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "podman version 4.3.1"
            } -ParameterFilter { $Command -like "*podman --version*" }

            Test-WslPodmanInstalled -DistroName "Debian"

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*podman --version*" -and
                $DistroName -eq "Debian" -and
                $StopAtError -eq $false -and
                $PrintCommand -eq $false
            }
        }
    }

    Context "When Podman is not installed" {
        It "Should return false when podman command not found" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                throw "podman: command not found"
            } -ParameterFilter { $Command -like "*podman --version*" }

            $result = Test-WslPodmanInstalled -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when podman --version returns empty output" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter {
                $Command -like "*podman --version*"
            }

            $result = Test-WslPodmanInstalled -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslPodmanInstalled -DistroName "" } | Should -Throw
        }
    }
}
