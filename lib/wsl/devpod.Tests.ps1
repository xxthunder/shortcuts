<#
.DESCRIPTION
    Pester tests for lib/devpod.ps1 - WSL DevPod CLI installation and detection
#>

param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\wsl.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Test-WslDevPodInstalled" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Test-WslDevPodInstalled -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When DevPod is installed" {
        It "Should return true when devpod version succeeds" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "v0.5.13"
            } -ParameterFilter { $Command -like "*devpod version*" }

            $result = Test-WslDevPodInstalled -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should execute devpod version command" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "v0.5.13"
            } -ParameterFilter { $Command -like "*devpod version*" }

            Test-WslDevPodInstalled -DistroName "Debian"

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*devpod version*" -and
                $DistroName -eq "Debian" -and
                $StopAtError -eq $false -and
                $PrintCommand -eq $false
            }
        }
    }

    Context "When DevPod is not installed" {
        It "Should return false when devpod command not found" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                throw "devpod: command not found"
            } -ParameterFilter { $Command -like "*devpod version*" }

            $result = Test-WslDevPodInstalled -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when devpod version returns empty output" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter {
                $Command -like "*devpod version*"
            }

            $result = Test-WslDevPodInstalled -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslDevPodInstalled -DistroName "" } | Should -Throw
        }
    }
}

Describe "Install-WslDevPod" {
    Context "Prerequisite validation - Distribution existence" {
        It "Should throw when distribution does not exist" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Install-WslDevPod -DistroName "Debian" -Confirm:$false } | Should -Throw "*does not exist*"
        }
    }

    Context "Prerequisite validation - No container engine" {
        It "Should throw when neither Docker nor Podman is installed" {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $false }

            { Install-WslDevPod -DistroName "Debian" -Confirm:$false } | Should -Throw "*container engine*"
        }

        It "Should mention setup-docker or setup-podman in error message" {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $false }

            { Install-WslDevPod -DistroName "Debian" -Confirm:$false } | Should -Throw "*setup-docker*"
        }
    }

    Context "Prerequisite validation - Default user" {
        It "Should throw when no default user configured and Username not provided" {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { $null }
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $false }

            { Install-WslDevPod -DistroName "Debian" -Confirm:$false } | Should -Throw "*default user*"
        }

        It "Should provide setup-user command in error message" {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { $null }
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $false }

            { Install-WslDevPod -DistroName "Debian" -Confirm:$false } | Should -Throw "*setup-user*"
        }

        It "Should use provided Username parameter when specified" {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { $null }
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $false }
            Mock Test-WslDevPodInstalled { $false }

            # Should not throw when Username is provided
            { Install-WslDevPod -DistroName "Debian" -Username "customuser" -Confirm:$false -WhatIf } | Should -Not -Throw
        }

        It "Should auto-detect default user from wsl.conf when Username not provided" {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "autodetected" }
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $false }
            Mock Test-WslDevPodInstalled { $false }

            Install-WslDevPod -DistroName "Debian" -Confirm:$false -WhatIf

            Should -Invoke Get-WslDefaultUser -ParameterFilter { $DistroName -eq "Debian" }
        }
    }

    Context "Engine detection - Docker preferred" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDevPodInstalled { $false }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Stop-WslDistro { }
        }

        It "Should detect Docker when both Docker and Podman are installed" {
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $true }

            Install-WslDevPod -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--engine=docker"
            }
        }

        It "Should detect Docker when only Docker is installed" {
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $false }

            Install-WslDevPod -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--engine=docker"
            }
        }
    }

    Context "Engine detection - Podman fallback" {
        It "Should detect Podman when only Podman is installed" {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Test-WslPodmanInstalled { $true }
            Mock Test-WslDevPodInstalled { $false }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Stop-WslDistro { }

            Install-WslDevPod -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--engine=podman"
            }
        }
    }

    Context "Idempotent behavior - DevPod already installed" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $false }
            Mock Test-WslDevPodInstalled { $true }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Stop-WslDistro { }
        }

        It "Should not throw when DevPod is already installed" {
            { Install-WslDevPod -DistroName "Debian" -Confirm:$false } | Should -Not -Throw
        }

        It "Should still call bash script when DevPod installed (for repair)" {
            Install-WslDevPod -DistroName "Debian" -Confirm:$false
            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*install-devpod.sh*"
            }
        }

        It "Should return true when DevPod verification succeeds" {
            $result = Install-WslDevPod -DistroName "Debian" -Confirm:$false
            $result | Should -Be $true
        }

        It "Should write informational message when DevPod already installed" {
            Mock Write-Information { }
            Install-WslDevPod -DistroName "Debian" -Confirm:$false
            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*already installed*"
            }
        }
    }

    Context "SupportsShouldProcess" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $false }
            Mock Test-WslDevPodInstalled { $false }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Stop-WslDistro { }
        }

        It "Should support -WhatIf parameter" {
            Install-WslDevPod -DistroName "Debian" -WhatIf

            # With -WhatIf, no actual script execution should happen
            Should -Invoke Invoke-WslDistroScript -Times 0
        }

        It "Should execute bash script when -Confirm:false is specified" {
            Install-WslDevPod -DistroName "Debian" -Confirm:$false

            # With -Confirm:$false, bash script should execute
            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*install-devpod.sh*"
            }
        }
    }

    Context "Bash script execution" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $false }
            Mock Test-WslDevPodInstalled { $false }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
            Mock Stop-WslDistro { }
        }

        It "Should call Invoke-WslDistroScript with install-devpod.sh" {
            Install-WslDevPod -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*install-devpod.sh*"
            }
        }

        It "Should pass engine and username arguments to script" {
            Install-WslDevPod -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--engine=docker" -and
                $Arguments -contains "--username=developer"
            }
        }

        It "Should pass custom username when provided" {
            Install-WslDevPod -DistroName "Debian" -Username "customuser" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--username=customuser"
            }
        }

        It "Should execute script with AsRoot=true" {
            Install-WslDevPod -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $AsRoot -eq $true
            }
        }

        It "Should return false and write error when bash script returns exit code 1 (prerequisite failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 1; return 1 }

            $result = Install-WslDevPod -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Prerequisite check failed*"
        }

        It "Should return false and write error when bash script returns exit code 2 (installation failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            $result = Install-WslDevPod -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Installation failed*"
        }

        It "Should return false and write error when bash script returns exit code 3 (verification failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 3; return 3 }

            $result = Install-WslDevPod -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Verification failed*"
        }

        It "Should return false and write error when bash script returns exit code 4 (argument error)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 4; return 4 }

            $result = Install-WslDevPod -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Argument error*"
        }

        It "Should return false and write error when bash script returns exit code 5 (no container engine)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 5; return 5 }

            $result = Install-WslDevPod -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*container engine*"
        }

        It "Should return true on successful installation (exit code 0)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

            $result = Install-WslDevPod -DistroName "Debian" -Confirm:$false

            $result | Should -Be $true
        }
    }

    Context "Auto-terminate after successful install" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }
            Mock Test-WslPodmanInstalled { $false }
            Mock Test-WslDevPodInstalled { $false }
            Mock Stop-WslDistro { }
        }

        It "Should call Stop-WslDistro after successful install" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

            Install-WslDevPod -DistroName "TestDistro" -Confirm:$false

            Should -Invoke Stop-WslDistro -Times 1 -ParameterFilter {
                $Name -eq "TestDistro"
            }
        }

        It "Should not call Stop-WslDistro when install fails" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            Install-WslDevPod -DistroName "TestDistro" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue

            Should -Invoke Stop-WslDistro -Times 0
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Install-WslDevPod -DistroName "" -Confirm:$false } | Should -Throw
        }
    }
}
