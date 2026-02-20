<#
.DESCRIPTION
    Pester tests for wsl-manager.ps1
#>

param()

BeforeAll {
    . "$PSScriptRoot\..\utils\utils.ps1"
    . "$PSScriptRoot\wsl.ps1"
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
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No WSL distributions*" }
        }

        It "Should call Get-WslDistroList with -Detailed switch" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Get-WslDistroList -ParameterFilter { $Detailed -eq $true } -Times 1
        }

        It "Should display distribution name and state" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Running*" }
        }

        It "Should display state with green color when running" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter {
                $ForegroundColor -eq "Green" -and $Object -like "*Running*"
            }
        }

        It "Should display state with gray color when stopped" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter {
                $ForegroundColor -eq "Gray" -and $Object -like "*Stopped*"
            }
        }

        It "Should display WSL version" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*WSL2*" }
        }

        It "Should display default indicator for default distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Default*" }
        }

        It "Should handle mixed running and stopped distributions" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
            Should -Invoke Write-Host -ParameterFilter {
                $ForegroundColor -eq "Green" -and $Object -like "*Running*"
            }
            Should -Invoke Write-Host -ParameterFilter {
                $ForegroundColor -eq "Gray" -and $Object -like "*Stopped*"
            }
        }

        It "Should display header" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Read-Host { "Debian" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
        }

        It "Should support selection by number" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should support selection by name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Alpine" }
        }

        It "Should reject invalid number selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Remove-WslDistro -Times 0
        }

        It "Should remove using provided selection without prompting" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "debian-test"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host {}
            Mock Remove-WslDistro {}

            Invoke-WslManager -Command "remove" -Name "debian-test"

            Should -Invoke Read-Host -Times 0
            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "debian-test" -and $Confirm -eq $false }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone" -Name "Debian" -TargetName "MyDebian"

            Should -Invoke Copy-WslDistro -ParameterFilter {
                $SourceName -eq "Debian" -and $TargetName -eq "MyDebian"
            }
        }

        It "Should prompt for source when only target name provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" } -ParameterFilter { $Prompt -like "*source*" }
            Mock Copy-WslDistro {}

            Invoke-WslManager -Command "clone"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Copy-WslDistro -Times 0
        }

        It "Should cancel when no target name provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
        }

        It "Should support selection by number" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should support selection by name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Alpine" }
        }

        It "Should reject invalid number selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Update-WslDistro -Times 0
        }

        It "Should cancel when no selection provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Update-WslDistro -Times 0
        }

        It "Should warn when no distributions exist" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No WSL distributions*" }
            Should -Invoke Update-WslDistro -Times 0
        }

        It "Should handle Update-WslDistro errors gracefully" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Arch"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Arch" }
            Mock Update-WslDistro { throw "Distribution 'Arch' is not a Debian/Ubuntu distribution" }

            { Invoke-WslManager -Command "update" } | Should -Throw "*not a Debian/Ubuntu*"
        }

        It "Should update using provided selection without prompting" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host {}
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update" -Name "Debian"

            Should -Invoke Read-Host -Times 0
            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Debian" -and $Confirm -eq $false }
        }
    }

    Context "When called with 'setup-user' argument" {
        It "Should call New-WslUser with correct parameters" {
            Mock Write-Host {}
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Debian" -Username "testuser" -Password "pass"

            Should -Invoke New-WslUser -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Username -eq "testuser" -and
                $Confirm -eq $false
            }
        }

        It "Should display success message after user creation" {
            Mock Write-Host {}
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Ubuntu" -Username "developer" -Password "pass"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully created user*" }
        }

        It "Should display restart instructions" {
            Mock Write-Host {}
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Ubuntu" -Username "developer" -Password "pass"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*wsl.exe --terminate*" }
        }

        It "Should handle invalid username with validation error" {
            Mock Write-Host {}
            Mock New-WslUser { throw "Invalid username 'InvalidUser'. Username must start with a lowercase letter" }

            { Invoke-WslManager -Command "setup-user" -Name "Debian" -Username "InvalidUser" -Password "pass" } | Should -Throw "*Invalid username*"
        }

        It "Should handle username that is too long" {
            Mock Write-Host {}
            $longUsername = "a" * 40
            Mock New-WslUser { throw "Username '$longUsername' is too long. Maximum length is 32 characters." }

            { Invoke-WslManager -Command "setup-user" -Name "Debian" -Username $longUsername -Password "pass" } | Should -Throw "*too long*"
        }

        It "Should handle user already exists error" {
            Mock Write-Host {}
            Mock New-WslUser { throw "User 'existinguser' already exists in distribution 'Debian'" }

            { Invoke-WslManager -Command "setup-user" -Name "Debian" -Username "existinguser" -Password "pass" } | Should -Throw "*already exists*"
        }

        It "Should skip when credentials are not provided" {
            Mock Write-Host {}
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Debian"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Skipping user setup in CI*" }
            Should -Invoke New-WslUser -Times 0
        }

        It "Should call New-WslUser without prompting when Username and Password are provided" {
            Mock Write-Host {}
            Mock New-WslUser {}

            Invoke-WslManager -Command "setup-user" -Name "Debian" -Username "testuser" -Password "pass"

            Should -Invoke New-WslUser -ParameterFilter {
                $DistroName -eq "Debian" -and $Username -eq "testuser" -and $Confirm -eq $false
            }
        }
    }

    Context "When called with 'setup-docker' argument" {
        It "Should prompt for distribution when Name is not provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
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

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*wsl.exe --terminate*" }
        }

        It "Should handle WSL1 distribution error" {
            Mock Install-WslDockerEngine { throw "Distribution 'OldDebian' is using WSL1.`nDocker requires WSL2. Upgrade with:`n  wsl.exe --set-version OldDebian 2" }

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
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Install-WslDockerEngine -ParameterFilter { $DistroName -eq "Ubuntu" }
        }

        It "Should support selection by name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Install-WslDockerEngine -ParameterFilter { $DistroName -eq "Alpine" }
        }

        It "Should reject invalid number selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Install-WslDockerEngine -Times 0
        }

        It "Should cancel when no selection provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Install-WslDockerEngine -Times 0
        }
    }

    Context "When called with 'terminate' argument" {
        BeforeEach {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Test-WslDistroRunning { $true }
        }

        It "Should prompt for distribution selection when Name is not provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Stop-WslDistro {}

            Invoke-WslManager -Command "terminate"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Stop-WslDistro {}

            Invoke-WslManager -Command "terminate"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
        }

        It "Should call Stop-WslDistro when Name is provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Stop-WslDistro {}

            Invoke-WslManager -Command "terminate" -Name "Debian"

            Should -Invoke Stop-WslDistro -ParameterFilter {
                $Name -eq "Debian" -and $Confirm -eq $false
            }
        }

        It "Should support selection by number" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Stop-WslDistro {}

            Invoke-WslManager -Command "terminate"

            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should support selection by name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" }
            Mock Stop-WslDistro {}

            Invoke-WslManager -Command "terminate"

            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Alpine" }
        }

        It "Should reject invalid number selection" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Stop-WslDistro {}

            Invoke-WslManager -Command "terminate"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Stop-WslDistro -Times 0
        }

        It "Should cancel when no selection provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Stop-WslDistro {}

            Invoke-WslManager -Command "terminate"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Stop-WslDistro -Times 0
        }

        It "Should warn when no distributions exist" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-WarningMsg {}
            Mock Stop-WslDistro {}

            Invoke-WslManager -Command "terminate"

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No running * distributions*" }
            Should -Invoke Stop-WslDistro -Times 0
        }

        It "Should handle terminate errors gracefully" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Stop-WslDistro { throw "Failed to terminate distribution" }

            { Invoke-WslManager -Command "terminate" } | Should -Throw "*Failed to terminate*"
        }
    }
}

Describe "Invoke-TerminateDistro" {
    Context "When WSL is not installed" {
        It "Should throw error and return" {
            Mock Test-WslInstalled { $false }

            { Invoke-TerminateDistro } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When no distributions are running" {
        It "Should display informational message and return" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Stopped"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Test-WslDistroRunning { $false }
            Mock Write-Host {}
            Mock Write-WarningMsg {}

            Invoke-TerminateDistro

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No running * distributions*" }
        }
    }

    Context "When running in CI environment" {
        It "Should throw error if Name is not provided" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Test-WslDistroRunning { $true }

            { Invoke-TerminateDistro } | Should -Throw "*Cannot run interactive*"
        }

        It "Should proceed if Name is provided" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Test-WslDistroRunning { $true }
            Mock Stop-WslDistro { }

            Invoke-TerminateDistro -Name "Debian"

            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Debian" -and $Confirm -eq $false }
        }
    }

    Context "When distributions are running" {
        BeforeEach {
            Mock Test-WslInstalled { $true }
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Test-WslDistroRunning {
                param($DistroName)
                if ($DistroName -eq "Debian") { return $true }
                if ($DistroName -eq "Ubuntu") { return $true }
                return $false
            }
            Mock Write-Host {}
            Mock Stop-WslDistro {}
        }

        It "Should list only running distributions" {
            Mock Read-Host { "1" }

            Invoke-TerminateDistro

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
        }

        It "Should handle selection by number (1)" {
            Mock Read-Host { "1" }

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should handle selection by number (2)" {
            Mock Read-Host { "2" }

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should handle selection by name" {
            Mock Read-Host { "Ubuntu" }

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should handle cancellation (empty input)" {
            Mock Read-Host { "" }

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Cancelling*" }
        }

        It "Should handle invalid number" {
            Mock Read-Host { "99" }
            Mock Write-Host {}

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
        }

        It "Should handle non-running distribution name" {
            Mock Read-Host { "Alpine" }
            Mock Write-Host {}

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not in the list*" }
        }
    }
}

