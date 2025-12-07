<#
.DESCRIPTION
    Pester tests for wsl-manager.ps1
#>

BeforeAll {
    . "$PSScriptRoot\..\pslib\utils.ps1"
    . "$PSScriptRoot\..\pslib\wsl.ps1"
    . "$PSScriptRoot\wsl-manager.ps1"
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

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Create*" }
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
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create" -Name "Debian"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should support Ubuntu" {
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create" -Name "Ubuntu"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should prompt for distribution when name not provided" {
            Mock Test-WslInstalled { $true }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should support selection by number" {
            Mock Test-WslInstalled { $true }
            Mock Write-Host {}
            Mock Read-Host { "1" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should reject unsupported distributions" {
            Mock Test-WslInstalled { $true }
            Mock Write-Host {}
            Mock New-WslDistro {}

            Invoke-WslManager -Command "create" -Name "Alpine"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Unsupported distribution*" }
            Should -Invoke New-WslDistro -Times 0
        }

        It "Should reject invalid number selection" {
            Mock Test-WslInstalled { $true }
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
}
