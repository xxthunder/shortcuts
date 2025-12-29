<#
.DESCRIPTION
    Pester tests for wsl-manager.ps1
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test code uses ConvertTo-SecureString with -AsPlainText for mocking secure password input in Pester tests.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\pslib\utils.ps1"
    . "$PSScriptRoot\..\pslib\wsl.ps1"
    . "$PSScriptRoot\wsl-manager.ps1"

    # Import Security module explicitly for PowerShell 5.1 compatibility
    # Errors are silently ignored if module is already loaded or unavailable
    Import-Module Microsoft.PowerShell.Security -ErrorAction SilentlyContinue

    # Create SecureString objects at top level for PowerShell 5.1 compatibility
    $script:testSecurePass = ConvertTo-SecureString "testpass" -AsPlainText -Force
    $script:devSecurePass = ConvertTo-SecureString "password123" -AsPlainText -Force
}

Describe "Show-WslDistroList" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Show-WslDistroList } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When WSL is installed" {
        It "Should display message when no distributions are installed" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No WSL distributions*" }
        }

        It "Should display each distribution when distributions exist" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
        }

        It "Should display header" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Installed*Distributions*" }
        }
    }
}

Describe "Show-InteractiveMenu" {
    Context "When in CI environment" {
        It "Should display message and exit" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Write-Host {}

            $result = Show-InteractiveMenu

            $result | Should -Be $false
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Interactive mode*not available*" }
        }
    }

    Context "When running interactively" {
        BeforeEach {
            Mock Clear-Host {}
        }

        It "Should display menu options" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Write-Host {}
            Mock Read-Host { "Q" }

            Show-InteractiveMenu

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Install*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Remove*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Quit*" }
        }

        It "Should exit when user selects Q" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() }
            Mock Write-Host {}
            Mock Read-Host { "Q" }

            $result = Show-InteractiveMenu

            $result | Should -Be $true
        }
    }
}

Describe "Invoke-WslManager" {
    Context "When called with 'list' argument" {
        It "Should call Show-WslDistroList" {
            Mock Show-WslDistroList {}

            Invoke-WslManager -Command "list"

            Should -Invoke Show-WslDistroList -Times 1
        }
    }

    Context "When called with 'remove' argument" {
        It "Should prompt for distribution selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Read-Host { "Debian" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
        }

        It "Should support selection by number" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu", "Alpine") }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should support selection by name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu", "Alpine") }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Alpine" }
        }

        It "Should reject invalid number selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Remove-WslDistro -Times 0
        }
    }

    Context "When called with 'create' argument" {
        It "Should create distribution when name is provided" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create" -Name "Debian"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should support any available distribution" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create" -Name "Ubuntu-22.04"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Ubuntu-22.04" }
        }

        It "Should prompt for distribution when name not provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should support selection by number" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock Write-Host {}
            Mock Read-Host { "1" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions dynamically" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04", "kali-linux") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu-22.04*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*kali-linux*" }
        }

        It "Should reject distribution not in available list" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create" -Name "InvalidDistro"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not available*" }
            Should -Invoke New-WslDistro -Times 0
        }

        It "Should reject invalid number selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke New-WslDistro -Times 0
        }
    }

    Context "When called without arguments" {
        It "Should call Show-InteractiveMenu" {
            Mock Show-InteractiveMenu { $true }

            Invoke-WslManager

            Should -Invoke Show-InteractiveMenu -Times 1
        }
    }

    Context "When called with 'clone' argument" {
        It "Should clone distribution when both names are provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone" -Name "Debian" -TargetName "MyDebian"

            Should -Invoke Copy-WslDistro -ParameterFilter {
                $SourceName -eq "Debian" -and $TargetName -eq "MyDebian"
            }
        }

        It "Should prompt for source when only target name provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" } -ParameterFilter { $Prompt -like "*source*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone" -Name "" -TargetName "MyProject"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*source*" }
            Should -Invoke Copy-WslDistro -ParameterFilter {
                $SourceName -eq "Debian" -and $TargetName -eq "MyProject"
            }
        }

        It "Should prompt for target name when only source provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "MyDebian" } -ParameterFilter { $Prompt -like "*target*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone" -Name "Debian" -TargetName ""

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*target*" }
            Should -Invoke Copy-WslDistro -ParameterFilter {
                $SourceName -eq "Debian" -and $TargetName -eq "MyDebian"
            }
        }

        It "Should prompt for both names when neither provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" } -ParameterFilter { $Prompt -like "*source*" }
            Mock Read-Host { "MyDebian" } -ParameterFilter { $Prompt -like "*target*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone" -Name "" -TargetName ""

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*source*" }
            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*target*" }
        }

        It "Should display installed distributions when prompting for source" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu", "Alpine") }
            Mock Write-Host {}
            Mock Read-Host { "1" } -ParameterFilter { $Prompt -like "*source*" }
            Mock Read-Host { "MyProject" } -ParameterFilter { $Prompt -like "*target*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Alpine*" }
        }

        It "Should support selection by number for source" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu", "Alpine") }
            Mock Write-Host {}
            Mock Read-Host { "2" } -ParameterFilter { $Prompt -like "*source*" }
            Mock Read-Host { "MyProject" } -ParameterFilter { $Prompt -like "*target*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone"

            Should -Invoke Copy-WslDistro -ParameterFilter {
                $SourceName -eq "Ubuntu" -and $TargetName -eq "MyProject"
            }
        }

        It "Should support selection by name for source" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu", "Alpine") }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" } -ParameterFilter { $Prompt -like "*source*" }
            Mock Read-Host { "MyProject" } -ParameterFilter { $Prompt -like "*target*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone"

            Should -Invoke Copy-WslDistro -ParameterFilter {
                $SourceName -eq "Alpine" -and $TargetName -eq "MyProject"
            }
        }

        It "Should cancel when no source selection provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Write-Host {}
            Mock Read-Host { "" } -ParameterFilter { $Prompt -like "*source*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Copy-WslDistro -Times 0
        }

        It "Should cancel when no target name provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" } -ParameterFilter { $Prompt -like "*source*" }
            Mock Read-Host { "" } -ParameterFilter { $Prompt -like "*target*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Copy-WslDistro -Times 0
        }

        It "Should reject invalid number selection for source" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "99" } -ParameterFilter { $Prompt -like "*source*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Copy-WslDistro -Times 0
        }
    }

    Context "When called with 'update' argument" {
        It "Should prompt for distribution selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
        }

        It "Should support selection by number" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu", "Alpine") }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should support selection by name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu", "Alpine") }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Alpine" }
        }

        It "Should reject invalid number selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Update-WslDistro -Times 0
        }

        It "Should cancel when no selection provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Update-WslDistro -Times 0
        }

        It "Should warn when no distributions exist" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() }
            Mock Write-Host {}
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No WSL distributions*" }
            Should -Invoke Update-WslDistro -Times 0
        }

        It "Should handle Update-WslDistro errors gracefully" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Arch") }
            Mock Write-Host {}
            Mock Read-Host { "Arch" }
            Mock Update-WslDistro { throw "Distribution 'Arch' is not a Debian/Ubuntu distribution" }

            { Invoke-WslManager -Command "update" } | Should -Throw "*not a Debian/Ubuntu*"
        }
    }

    Context "When called with 'setup-user' argument" {
        It "Should prompt for username" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-Host { "testuser" } -ParameterFilter { $Prompt -like "*username*" }
            Mock Read-Host { $script:testSecurePass } -ParameterFilter { $AsSecureString }
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Debian"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*username*" }
        }

        It "Should prompt for password securely" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-Host { "testuser" } -ParameterFilter { $Prompt -like "*username*" }
            Mock Read-Host { $script:testSecurePass } -ParameterFilter { $AsSecureString }
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Debian"

            Should -Invoke Read-Host -ParameterFilter { $AsSecureString -eq $true }
        }

        It "Should call New-WslUser with correct parameters" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-Host { "testuser" } -ParameterFilter { $Prompt -like "*username*" }
            Mock Read-Host { $script:testSecurePass } -ParameterFilter { $AsSecureString }
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Debian"

            Should -Invoke New-WslUser -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Username -eq "testuser" -and
                $Confirm -eq $false
            }
        }

        It "Should display success message after user creation" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-Host { "developer" } -ParameterFilter { $Prompt -like "*username*" }
            Mock Read-Host { $script:devSecurePass } -ParameterFilter { $AsSecureString }
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully created user*" }
        }

        It "Should display restart instructions" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-Host { "developer" } -ParameterFilter { $Prompt -like "*username*" }
            Mock Read-Host { $script:devSecurePass } -ParameterFilter { $AsSecureString }
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*wsl --terminate*" }
        }

        It "Should handle invalid username with validation error" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-Host { "InvalidUser" } -ParameterFilter { $Prompt -like "*username*" }
            Mock Read-Host { $script:testSecurePass } -ParameterFilter { $AsSecureString }
            Mock New-WslUser { throw "Invalid username 'InvalidUser'. Username must start with a lowercase letter" }

            { Invoke-WslManager -Command "setup-user" -Name "Debian" } | Should -Throw "*Invalid username*"
        }

        It "Should handle username that is too long" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            $longUsername = "a" * 40
            Mock Read-Host { $longUsername } -ParameterFilter { $Prompt -like "*username*" }
            Mock Read-Host { $script:testSecurePass } -ParameterFilter { $AsSecureString }
            Mock New-WslUser { throw "Username '$longUsername' is too long. Maximum length is 32 characters." }

            { Invoke-WslManager -Command "setup-user" -Name "Debian" } | Should -Throw "*too long*"
        }

        It "Should handle user already exists error" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-Host { "existinguser" } -ParameterFilter { $Prompt -like "*username*" }
            Mock Read-Host { $script:testSecurePass } -ParameterFilter { $AsSecureString }
            Mock New-WslUser { throw "User 'existinguser' already exists in distribution 'Debian'" }

            { Invoke-WslManager -Command "setup-user" -Name "Debian" } | Should -Throw "*already exists*"
        }

        It "Should cancel when username is empty" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-Host { "" } -ParameterFilter { $Prompt -like "*username*" }
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Debian"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke New-WslUser -Times 0
        }

        It "Should skip in CI environment" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Write-Host {}
            Mock Read-Host {}
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Debian"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Skipping user setup in CI*" }
            Should -Invoke Read-Host -Times 0
            Should -Invoke New-WslUser -Times 0
        }
    }

    Context "When called with 'setup-docker' argument" {
        It "Should prompt for distribution when Name is not provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Install-WslDockerEngine -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should call Install-WslDockerEngine when Name is provided" {
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker" -Name "Debian"

            Should -Invoke Install-WslDockerEngine -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Confirm -eq $false
            }
        }

        It "Should display success message after Docker installation" {
            Mock Write-Host {}
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker" -Name "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully installed Docker*" }
        }

        It "Should display restart instructions" {
            Mock Write-Host {}
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker" -Name "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*wsl --terminate*" }
        }

        It "Should handle WSL1 distribution error" {
            Mock Install-WslDockerEngine { throw "Distribution 'OldDebian' is using WSL1.`nDocker requires WSL2. Upgrade with:`n  wsl --set-version OldDebian 2" }

            { Invoke-WslManager -Command "setup-docker" -Name "OldDebian" } | Should -Throw "*WSL1*"
        }

        It "Should handle missing systemd error" {
            Mock Install-WslDockerEngine { throw "Distribution 'CustomDistro' does not support systemd" }

            { Invoke-WslManager -Command "setup-docker" -Name "CustomDistro" } | Should -Throw "*systemd*"
        }

        It "Should handle Docker already installed error" {
            Mock Install-WslDockerEngine { throw "Docker is already installed in 'Debian'" }

            { Invoke-WslManager -Command "setup-docker" -Name "Debian" } | Should -Throw "*already installed*"
        }

        It "Should handle no default user error" {
            Mock Install-WslDockerEngine { throw "No default user configured in 'Debian'.`nDocker setup requires a non-root user" }

            { Invoke-WslManager -Command "setup-docker" -Name "Debian" } | Should -Throw "*default user*"
        }

        It "Should support selection by number" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu", "Alpine") }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Install-WslDockerEngine -ParameterFilter { $DistroName -eq "Ubuntu" }
        }

        It "Should support selection by name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu", "Alpine") }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Install-WslDockerEngine -ParameterFilter { $DistroName -eq "Alpine" }
        }

        It "Should reject invalid number selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Install-WslDockerEngine -Times 0
        }

        It "Should cancel when no selection provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Install-WslDockerEngine -Times 0
        }
    }
}
