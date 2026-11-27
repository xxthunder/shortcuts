<#
.DESCRIPTION
    Pester tests for lib/docker.ps1 - WSL Docker Engine installation and detection
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

Describe "Test-WslDockerInstalled" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Test-WslDockerInstalled -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When Docker is installed" {
        It "Should return true when docker --version succeeds" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "Docker version 24.0.7, build afdd53b"
            } -ParameterFilter { $Command -like "*docker --version*" }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should execute docker --version command" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "Docker version 24.0.7, build afdd53b"
            } -ParameterFilter { $Command -like "*docker --version*" }

            Test-WslDockerInstalled -DistroName "Debian"

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*docker --version*" -and
                $DistroName -eq "Debian" -and
                $StopAtError -eq $false -and
                $PrintCommand -eq $false
            }
        }
    }

    Context "When Docker is not installed" {
        It "Should return false when docker command not found" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                throw "docker: command not found"
            } -ParameterFilter { $Command -like "*docker --version*" }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when docker --version returns empty output" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter {
                $Command -like "*docker --version*"
            }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When docker is the podman-docker wrapper" {
        It "Should return false when docker --version prints the podman version" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "podman version 5.4.2" } -ParameterFilter {
                $Command -like "*docker --version*"
            }

            $result = Test-WslDockerInstalled -DistroName "Ubuntu"

            $result | Should -Be $false
        }

        It "Should return false when the Docker emulation notice precedes the podman version" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "Emulate Docker CLI using podman. Create /etc/containers/nodocker to quiet msg.`npodman version 5.4.2"
            } -ParameterFilter { $Command -like "*docker --version*" }

            $result = Test-WslDockerInstalled -DistroName "Ubuntu"

            $result | Should -Be $false
        }
    }

    Context "When Docker Engine prints its release version" {
        It "Should return true for Docker version 27.3.1" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "Docker version 27.3.1, build ce12230" } -ParameterFilter {
                $Command -like "*docker --version*"
            }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $true
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslDockerInstalled -DistroName "" } | Should -Throw
        }
    }
}
