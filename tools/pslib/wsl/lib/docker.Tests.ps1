<#
.DESCRIPTION
    Pester tests for lib/docker.ps1 - WSL Docker Engine installation and detection
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\wsl.ps1"
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

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslDockerInstalled -DistroName "" } | Should -Throw
        }
    }
}

Describe "Install-WslDockerEngine" {
    Context "Prerequisite validation - Distribution existence" {
        It "Should throw when distribution does not exist" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*does not exist*"
        }
    }

    Context "Prerequisite validation - WSL2 version" {
        It "Should throw when distribution is WSL1" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*WSL2*"
        }

        It "Should provide upgrade command in error message for WSL1" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*wsl.exe --set-version*"
        }
    }


    Context "Prerequisite validation - Distribution type" {
        It "Should throw when distribution is not Debian/Ubuntu" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "arch" }

            { Install-WslDockerEngine -DistroName "Arch" -Confirm:$false } | Should -Throw "*Debian*Ubuntu*"
        }

        It "Should accept Debian distribution" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw for Debian
            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false -WhatIf } | Should -Not -Throw
        }

        It "Should accept Ubuntu distribution" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
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

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*default user*"
        }

        It "Should provide setup-user command in error message" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*setup-user*"
        }

        It "Should use provided Username parameter when specified" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw when Username is provided
            { Install-WslDockerEngine -DistroName "Debian" -Username "customuser" -Confirm:$false -WhatIf } | Should -Not -Throw
        }

        It "Should auto-detect default user from wsl.conf when Username not provided" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
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

    Context "Idempotent behavior - Docker already installed" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }  # Docker already installed
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*" }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Test-Path { $true }
        }

        It "Should not throw when Docker is already installed" {
            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Not -Throw
        }

        It "Should still call bash script when Docker installed (for repair)" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false
            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*install-docker.sh*"
            }
        }

        It "Should return true when Docker verification succeeds" {
            $result = Install-WslDockerEngine -DistroName "Debian" -Confirm:$false
            $result | Should -Be $true
        }

        It "Should write informational message when Docker already installed" {
            Mock Write-Information { }
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false
            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*already installed*"
            }
        }
    }

    Context "SupportsShouldProcess" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
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

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
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

    Context "Auto-terminate after successful install" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Test-Path { $true }
            Mock Stop-WslDistro { }
        }

        It "Should call Stop-WslDistro after successful install" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

            Install-WslDockerEngine -DistroName "TestDistro" -Confirm:$false

            Should -Invoke Stop-WslDistro -Times 1 -ParameterFilter {
                $Name -eq "TestDistro"
            }
        }

        It "Should not call Stop-WslDistro when install fails" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            Install-WslDockerEngine -DistroName "TestDistro" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue

            Should -Invoke Stop-WslDistro -Times 0
        }
    }

    Context "Systemd and interop prerequisite configuration" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Test-WslDockerInstalled { $false }
            Mock Get-WslDefaultUser { "developer" }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Test-Path { $true }
        }

        It "Should configure systemd if not already configured" {
            Mock Test-WslSystemdConfigured { $false } -ParameterFilter { $DistroName -eq "Debian" }
            Mock Test-WslInteropConfigured { $false } -ParameterFilter { $DistroName -eq "Debian" }
            Mock Get-WslDefaultUser { "developer" } -ParameterFilter { $DistroName -eq "Debian" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 1 -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Sections.boot.systemd -eq "true"
            }
        }

        It "Should configure interop settings when systemd is not configured" {
            Mock Test-WslSystemdConfigured { $false }
            Mock Test-WslInteropConfigured { $false }
            Mock Get-WslDefaultUser { "developer" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 1 -ParameterFilter {
                $Sections.interop.enabled -eq "true" -and
                $Sections.interop.appendWindowsPath -eq "true"
            }
        }

        It "Should preserve existing user configuration" {
            Mock Test-WslSystemdConfigured { $false }
            Mock Test-WslInteropConfigured { $false }
            Mock Get-WslDefaultUser { "existinguser" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 1 -ParameterFilter {
                $Sections.user.default -eq "existinguser"
            }
        }

        It "Should configure interop even if systemd already configured" {
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $false }
            Mock Get-WslDefaultUser { "developer" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 1 -ParameterFilter {
                $Sections.interop.enabled -eq "true" -and
                $Sections.interop.appendWindowsPath -eq "true" -and
                -not $Sections.ContainsKey('boot')
            }
        }

        It "Should skip wsl.conf configuration if both systemd and interop are configured" {
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDefaultUser { "developer" }
            Mock Set-WslConf { }

            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 0
        }

        It "Should restart distribution after wsl.conf changes" {
            Mock Test-WslSystemdConfigured { $false }
            Mock Test-WslInteropConfigured { $false }
            Mock Get-WslDefaultUser { "developer" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            # Verify systemd configuration happened and Start-Sleep was called (which only happens after terminate)
            Should -Invoke Set-WslConf -Times 1
            Should -Invoke Start-Sleep -Times 1
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Install-WslDockerEngine -DistroName "" -Confirm:$false } | Should -Throw
        }
    }
}
