<#
.DESCRIPTION
    Pester tests for lib/docker.ps1 - WSL Docker Engine installation and detection
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\utils\utils.ps1"
    . "$PSScriptRoot\..\wsl.ps1"
}

Describe "Test-WslDockerInstalled" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Test-WslDockerInstalled -DistroName "Debian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Test-WslDockerInstalled -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When Docker is installed" {
        It "Should return true when docker --version succeeds" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "Docker version 24.0.7, build afdd53b"
            } -ParameterFilter { $Command -like "*docker --version*" }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should execute docker --version command" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
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
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                throw "docker: command not found"
            } -ParameterFilter { $Command -like "*docker --version*" }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when docker --version returns empty output" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter {
                $Command -like "*docker --version*"
            }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslDockerInstalled -DistroName "" } | Should -Throw
        }
    }
}

Describe "Install-WslDockerEngine" {
    Context "Prerequisite validation - WSL installation" {
        It "Should throw when WSL is not installed" {
            Mock Test-WslInstalled { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "Prerequisite validation - Distribution existence" {
        It "Should throw when distribution does not exist" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*does not exist*"
        }
    }

    Context "Prerequisite validation - WSL2 version" {
        It "Should throw when distribution is WSL1" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*WSL2*"
        }

        It "Should provide upgrade command in error message for WSL1" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*wsl.exe --set-version*"
        }
    }

    Context "Prerequisite validation - Systemd configuration" {
        It "Should throw when systemd is not configured in wsl.conf" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*systemd*wsl.conf*"
        }

        It "Should provide wsl.conf configuration instructions in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*[boot]*systemd=true*"
        }

        It "Should provide restart instructions in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*wsl.exe --terminate*"
        }
    }

    Context "Prerequisite validation - Systemd running" {
        It "Should throw when systemd is not running" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*systemd*running*"
        }

        It "Should provide troubleshooting steps in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*systemctl --version*"
        }
    }

    Context "Prerequisite validation - Distribution type" {
        It "Should throw when distribution is not Debian/Ubuntu" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Arch") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "arch" }

            { Install-WslDockerEngine -DistroName "Arch" -Confirm:$false } | Should -Throw "*Debian*Ubuntu*"
        }

        It "Should accept Debian distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw for Debian
            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false -WhatIf } | Should -Not -Throw
        }

        It "Should accept Ubuntu distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "ubuntu" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "ubuntu`njammy`namd64" } -ParameterFilter { $Command -like "*bash << 'EOF'*os-release*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw for Ubuntu
            { Install-WslDockerEngine -DistroName "Ubuntu" -Confirm:$false -WhatIf } | Should -Not -Throw
        }
    }

    Context "Prerequisite validation - Default user" {
        It "Should throw when no default user is configured and Username not provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*default user*"
        }

        It "Should provide setup-user command in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*setup-user*"
        }

        It "Should use provided Username parameter when specified" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw when Username is provided
            { Install-WslDockerEngine -DistroName "Debian" -Username "customuser" -Confirm:$false -WhatIf } | Should -Not -Throw
        }

        It "Should auto-detect default user from wsl.conf when Username not provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "autodetected" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }
            Mock Invoke-WslDistroCommand { }

            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false -WhatIf

            Should -Invoke Get-WslDefaultUser -Times 1 -ParameterFilter { $DistroName -eq "Debian" }
        }
    }

    Context "Prerequisite validation - Docker already installed" {
        It "Should throw when Docker is already installed" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*already installed*"
        }

        It "Should provide uninstall instructions in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*apt-get remove*"
        }
    }

    Context "SupportsShouldProcess" {
        BeforeEach {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Test-Path { $true }
        }

        It "Should support -WhatIf parameter" {
            Install-WslDockerEngine -DistroName "Debian" -WhatIf

            # With -WhatIf, no actual script execution should happen
            Should -Invoke Invoke-WslDistroScript -Times 0
        }

        It "Should execute bash script when -Confirm:false is specified" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            # With -Confirm:$false, bash script should execute
            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*install-docker.sh*"
            }
        }
    }

    Context "Bash script execution (refactored implementation)" {
        BeforeEach {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Test-Path { $true }
        }

        It "Should call Invoke-WslDistroScript with install-docker.sh" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*install-docker.sh*"
            }
        }

        It "Should pass correct distribution parameters to script" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--distro-id=debian" -and
                $Arguments -contains "--codename=bookworm" -and
                $Arguments -contains "--arch=amd64" -and
                $Arguments -contains "--username=developer"
            }
        }

        It "Should pass custom username when provided" {
            Install-WslDockerEngine -DistroName "Debian" -Username "customuser" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--username=customuser"
            }
        }

        It "Should execute script with AsRoot=true (requires sudo for Docker installation)" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $AsRoot -eq $true
            }
        }

        It "Should throw when bash script returns exit code 1 (prerequisite failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 1; return 1 }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } |
                Should -Throw "*Prerequisite check failed*"
        }

        It "Should throw when bash script returns exit code 2 (installation failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } |
                Should -Throw "*Installation failed*"
        }

        It "Should throw when bash script returns exit code 3 (verification failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 3; return 3 }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } |
                Should -Throw "*Verification failed*"
        }

        It "Should throw when bash script returns exit code 4 (argument error)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 4; return 4 }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } |
                Should -Throw "*Argument error*"
        }

        It "Should return true on successful installation (exit code 0)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

            $result = Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            $result | Should -Be $true
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Install-WslDockerEngine -DistroName "" -Confirm:$false } | Should -Throw
        }
    }
}
