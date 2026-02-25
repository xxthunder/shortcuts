<#
.DESCRIPTION
    Pester tests for lib/podman.ps1 - WSL rootless Podman installation and detection
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\utils\utils.ps1"
    . "$PSScriptRoot\..\wsl.ps1"
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

Describe "Install-WslPodman" {
    Context "Prerequisite validation - Distribution existence" {
        It "Should throw when distribution does not exist" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Install-WslPodman -DistroName "Debian" -Confirm:$false } | Should -Throw "*does not exist*"
        }
    }

    Context "Prerequisite validation - WSL2 version" {
        It "Should throw when distribution is WSL1" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $false }

            { Install-WslPodman -DistroName "Debian" -Confirm:$false } | Should -Throw "*WSL2*"
        }

        It "Should provide upgrade command in error message for WSL1" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $false }

            { Install-WslPodman -DistroName "Debian" -Confirm:$false } | Should -Throw "*wsl.exe --set-version*"
        }
    }

    Context "Prerequisite validation - Distribution type" {
        It "Should throw when distribution is not Debian/Ubuntu" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "arch" }

            { Install-WslPodman -DistroName "Arch" -Confirm:$false } | Should -Throw "*Debian*Ubuntu*"
        }

        It "Should accept Debian distribution" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $false }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw for Debian
            { Install-WslPodman -DistroName "Debian" -Confirm:$false -WhatIf } | Should -Not -Throw
        }

        It "Should accept Ubuntu distribution" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "ubuntu" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $false }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }
            Mock Invoke-WslDistroCommand { "ubuntu`njammy`namd64" } -ParameterFilter { $Command -like "*bash << 'EOF'*os-release*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw for Ubuntu
            { Install-WslPodman -DistroName "Ubuntu" -Confirm:$false -WhatIf } | Should -Not -Throw
        }
    }

    Context "Prerequisite validation - Default user" {
        It "Should throw when no default user is configured and Username not provided" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }

            { Install-WslPodman -DistroName "Debian" -Confirm:$false } | Should -Throw "*default user*"
        }

        It "Should provide setup-user command in error message" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }

            { Install-WslPodman -DistroName "Debian" -Confirm:$false } | Should -Throw "*setup-user*"
        }

        It "Should use provided Username parameter when specified" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $false }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw when Username is provided
            { Install-WslPodman -DistroName "Debian" -Username "customuser" -Confirm:$false -WhatIf } | Should -Not -Throw
        }

        It "Should auto-detect default user from wsl.conf when Username not provided" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "autodetected" }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $false }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }

            Install-WslPodman -DistroName "Debian" -Confirm:$false -WhatIf

            Should -Invoke Get-WslDefaultUser -ParameterFilter { $DistroName -eq "Debian" }
        }
    }

    Context "Mutual exclusion - Docker installed" {
        It "Should throw when Docker is already installed" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }

            { Install-WslPodman -DistroName "Debian" -Confirm:$false } | Should -Throw "*Docker is already installed*"
        }

        It "Should mention mutual exclusion in error message" {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }

            { Install-WslPodman -DistroName "Debian" -Confirm:$false } | Should -Throw "*cannot coexist*"
        }
    }

    Context "Idempotent behavior - Podman already installed" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $true }  # Podman already installed
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*" }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Test-Path { $true }
        }

        It "Should not throw when Podman is already installed" {
            { Install-WslPodman -DistroName "Debian" -Confirm:$false } | Should -Not -Throw
        }

        It "Should still call bash script when Podman installed (for repair)" {
            Install-WslPodman -DistroName "Debian" -Confirm:$false
            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*install-podman.sh*"
            }
        }

        It "Should return true when Podman verification succeeds" {
            $result = Install-WslPodman -DistroName "Debian" -Confirm:$false
            $result | Should -Be $true
        }

        It "Should write informational message when Podman already installed" {
            Mock Write-Information { }
            Install-WslPodman -DistroName "Debian" -Confirm:$false
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
            Mock Test-WslPodmanInstalled { $false }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Test-Path { $true }
        }

        It "Should support -WhatIf parameter" {
            Install-WslPodman -DistroName "Debian" -WhatIf

            # With -WhatIf, no actual script execution should happen
            Should -Invoke Invoke-WslDistroScript -Times 0
        }

        It "Should execute bash script when -Confirm:false is specified" {
            Install-WslPodman -DistroName "Debian" -Confirm:$false

            # With -Confirm:$false, bash script should execute
            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*install-podman.sh*"
            }
        }
    }

    Context "Bash script execution" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $false }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Test-Path { $true }
        }

        It "Should call Invoke-WslDistroScript with install-podman.sh" {
            Install-WslPodman -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*install-podman.sh*"
            }
        }

        It "Should pass correct distribution parameters to script" {
            Install-WslPodman -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--distro-id=debian" -and
                $Arguments -contains "--codename=bookworm" -and
                $Arguments -contains "--arch=amd64" -and
                $Arguments -contains "--username=developer"
            }
        }

        It "Should pass custom username when provided" {
            Install-WslPodman -DistroName "Debian" -Username "customuser" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--username=customuser"
            }
        }

        It "Should execute script with AsRoot=true (requires sudo for Podman installation)" {
            Install-WslPodman -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $AsRoot -eq $true
            }
        }

        It "Should return false and write error when bash script returns exit code 1 (prerequisite failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 1; return 1 }

            $result = Install-WslPodman -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Prerequisite check failed*"
        }

        It "Should return false and write error when bash script returns exit code 2 (installation failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            $result = Install-WslPodman -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Installation failed*"
        }

        It "Should return false and write error when bash script returns exit code 3 (verification failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 3; return 3 }

            $result = Install-WslPodman -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Verification failed*"
        }

        It "Should return false and write error when bash script returns exit code 4 (argument error)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 4; return 4 }

            $result = Install-WslPodman -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Argument error*"
        }

        It "Should return true on successful installation (exit code 0)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

            $result = Install-WslPodman -DistroName "Debian" -Confirm:$false

            $result | Should -Be $true
        }
    }

    Context "Systemd, interop, and boot command configuration" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Test-Wsl2Version { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $false }
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

            Install-WslPodman -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 1 -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Sections.boot.systemd -eq "true"
            }
        }

        It "Should configure boot command for rootless Podman when systemd not configured" {
            Mock Test-WslSystemdConfigured { $false }
            Mock Test-WslInteropConfigured { $false }
            Mock Get-WslDefaultUser { "developer" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslPodman -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 1 -ParameterFilter {
                $Sections.boot.command -eq "mount --make-rshared /"
            }
        }

        It "Should configure interop settings when not configured" {
            Mock Test-WslSystemdConfigured { $false }
            Mock Test-WslInteropConfigured { $false }
            Mock Get-WslDefaultUser { "developer" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslPodman -DistroName "Debian" -Confirm:$false

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

            Install-WslPodman -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 1 -ParameterFilter {
                $Sections.user.default -eq "existinguser"
            }
        }

        It "Should still configure boot command when systemd and interop already configured" {
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $true }
            Mock Get-WslDefaultUser { "developer" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslPodman -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 1 -ParameterFilter {
                $Sections.boot.command -eq "mount --make-rshared /"
            }
        }

        It "Should configure boot command when systemd is configured but interop is not" {
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslInteropConfigured { $false }
            Mock Get-WslDefaultUser { "developer" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslPodman -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -ParameterFilter {
                $Sections.boot.command -eq "mount --make-rshared /"
            }
        }

        It "Should restart distribution after wsl.conf changes" {
            Mock Test-WslSystemdConfigured { $false }
            Mock Test-WslInteropConfigured { $false }
            Mock Get-WslDefaultUser { "developer" }
            Mock Set-WslConf { }
            Mock Invoke-CommandLine { }
            Mock Start-Sleep { }

            Install-WslPodman -DistroName "Debian" -Confirm:$false

            Should -Invoke Set-WslConf -Times 1
            Should -Invoke Start-Sleep -Times 1
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Install-WslPodman -DistroName "" -Confirm:$false } | Should -Throw
        }
    }
}
