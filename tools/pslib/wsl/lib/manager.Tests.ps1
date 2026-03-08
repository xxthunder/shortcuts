<#
.DESCRIPTION
    Pester tests for manager.ps1
#>

param()

BeforeAll {
    . "$PSScriptRoot\commands.ps1"
    . "$PSScriptRoot\manager.ps1"
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
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Setup Podman*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Quit*" }
        }

        It "Should exit when user selects Q" {
            Mock Test-RunningInCIorTestEnvironment { $false }

            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Q" }

            $result = Show-InteractiveMenu

            $result | Should -Be $true
        }

        It "Should dispatch to Invoke-WslCommand with 'setup-podman' when P is selected" {
            Mock Test-RunningInCIorTestEnvironment { $false }

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { "P" }
                elseif ($script:callCount -eq 2) { "" }  # Press Enter to continue
                else { "Q" }
            }
            Mock Invoke-WslCommand {}

            Show-InteractiveMenu

            Should -Invoke Invoke-WslCommand -ParameterFilter { $Command -eq "setup-podman" } -Times 1
        }

        It "Should dispatch to Invoke-WslCommand with 'setup-proxy' when X is selected" {
            Mock Test-RunningInCIorTestEnvironment { $false }

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { "X" }
                elseif ($script:callCount -eq 2) { "" }  # Press Enter to continue
                else { "Q" }
            }
            Mock Invoke-WslCommand {}

            Show-InteractiveMenu

            Should -Invoke Invoke-WslCommand -ParameterFilter { $Command -eq "setup-proxy" } -Times 1
        }

        It "Should fetch distro list once and pass it to Invoke-WslCommand" {
            Mock Test-RunningInCIorTestEnvironment { $false }

            $mockDistros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )
            Mock Get-WslDistroList { $mockDistros } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { "T" }
                elseif ($script:callCount -eq 2) { "" }  # Press Enter to continue
                else { "Q" }
            }
            Mock Invoke-WslCommand {}

            Show-InteractiveMenu

            Should -Invoke Get-WslDistroList -Times 2  # once per menu loop iteration
            Should -Invoke Invoke-WslCommand -ParameterFilter { $Command -eq "terminate" -and $null -ne $Distros } -Times 1
        }

        It "Should handle Get-WslDistroList errors gracefully" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList { throw "WSL service not available" } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-ErrorMsg {}
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { "Q" }
                else { "Q" }
            }

            Show-InteractiveMenu

            Should -Invoke Write-ErrorMsg -ParameterFilter { $Message -like "*WSL service not available*" }
        }

        It "Should handle Invoke-WslCommand errors gracefully" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-ErrorMsg {}
            Mock Invoke-WslCommand { throw "Command failed" }
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { "I" }
                elseif ($script:callCount -eq 2) { "" }  # Press Enter to continue
                else { "Q" }
            }

            Show-InteractiveMenu

            Should -Invoke Write-ErrorMsg -ParameterFilter { $Message -like "*Command failed*" }
        }

        It "Should show error for invalid menu key" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-ErrorMsg {}
            Mock Start-Sleep {}
            $script:callCount = 0
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { "Z" }
                else { "Q" }
            }

            Show-InteractiveMenu

            Should -Invoke Write-ErrorMsg -ParameterFilter { $Message -like "*Invalid option*" }
            Should -Invoke Start-Sleep -Times 1
        }
    }
}

Describe "Invoke-WslManager" {
    BeforeEach {
        Mock Assert-Wsl2Installed { }
    }

    Context "When WSL 2 is not available" {
        It "Should throw for any command when Assert-Wsl2Installed fails" {
            Mock Assert-Wsl2Installed { throw "WSL is not installed. Please install WSL first." }

            { Invoke-WslManager -Command "list" } | Should -Throw "*WSL is not installed*"
        }

        It "Should throw for interactive mode when Assert-Wsl2Installed fails" {
            Mock Assert-Wsl2Installed { throw "WSL 2 is required but only WSL 1 was detected. Please upgrade: wsl --update" }

            { Invoke-WslManager } | Should -Throw "*WSL 2 is required*"
        }
    }

    Context "When called with 'list' argument" {
        It "Should call Show-WslDistroList" {
            Mock Show-WslDistroList {}

            Invoke-WslManager -Command "list"

            Should -Invoke Show-WslDistroList -Times 1
        }
    }

    Context "When called with 'remove' argument" {
        It "Should prompt for distribution selection" {

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

            Invoke-WslManager -Command "install" -Name "Debian"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should support any available distribution" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "install" -Name "Ubuntu-22.04"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Ubuntu-22.04" }
        }

        It "Should prompt for distribution when name not provided" {

            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "install"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should support selection by number" {

            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock Write-Host {}
            Mock Read-Host { "1" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "install"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions dynamically" {

            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04", "kali-linux") }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "install"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu-22.04*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*kali-linux*" }
        }

        It "Should reject distribution not in available list" {

            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock New-WslDistro {}

            Invoke-WslManager -Command "install" -Name "InvalidDistro"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not available*" }
            Should -Invoke New-WslDistro -Times 0
        }

        It "Should reject invalid number selection" {

            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock New-WslDistro {}

            Invoke-WslManager -Command "install"

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

            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Update-WslDistro {}

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No WSL distributions*" }
            Should -Invoke Update-WslDistro -Times 0
        }

        It "Should handle Update-WslDistro errors gracefully" {

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

    Context "When called with 'setup-podman' argument" {
        It "Should prompt for distribution when Name is not provided" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Install-WslPodman { $true }

            Invoke-WslManager -Command "setup-podman"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Install-WslPodman -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should call Install-WslPodman when Name is provided" {
            Mock Install-WslPodman { $true }

            Invoke-WslManager -Command "setup-podman" -Name "Debian"

            Should -Invoke Install-WslPodman -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Confirm -eq $false
            }
        }

        It "Should display success message after Podman installation" {
            Mock Write-Host {}
            Mock Install-WslPodman { $true }

            Invoke-WslManager -Command "setup-podman" -Name "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully installed Podman*" }
        }

        It "Should handle WSL1 distribution error" {
            Mock Install-WslPodman { throw "Distribution 'OldDebian' is using WSL1.`nPodman requires WSL2. Upgrade with:`n  wsl.exe --set-version OldDebian 2" }

            { Invoke-WslManager -Command "setup-podman" -Name "OldDebian" } | Should -Throw "*WSL1*"
        }

        It "Should handle Docker already installed (mutual exclusion) error" {
            Mock Install-WslPodman { throw "Docker is already installed in 'Debian'. Podman and Docker cannot coexist." }

            { Invoke-WslManager -Command "setup-podman" -Name "Debian" } | Should -Throw "*Docker is already installed*"
        }

        It "Should handle no default user error" {
            Mock Install-WslPodman { throw "No default user configured in 'Debian'.`nPodman setup requires a non-root user" }

            { Invoke-WslManager -Command "setup-podman" -Name "Debian" } | Should -Throw "*default user*"
        }

        It "Should support selection by number" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Install-WslPodman { $true }

            Invoke-WslManager -Command "setup-podman"

            Should -Invoke Install-WslPodman -ParameterFilter { $DistroName -eq "Ubuntu" }
        }

        It "Should support selection by name" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" }
            Mock Install-WslPodman { $true }

            Invoke-WslManager -Command "setup-podman"

            Should -Invoke Install-WslPodman -ParameterFilter { $DistroName -eq "Alpine" }
        }

        It "Should reject invalid number selection" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Install-WslPodman { $true }

            Invoke-WslManager -Command "setup-podman"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Install-WslPodman -Times 0
        }

        It "Should cancel when no selection provided" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Install-WslPodman { $true }

            Invoke-WslManager -Command "setup-podman"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Install-WslPodman -Times 0
        }
    }

    Context "When called with 'setup-proxy' argument" {
        It "Should prompt for distribution when Name is not provided" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Install-WslProxy { $true }

            Invoke-WslManager -Command "setup-proxy"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Install-WslProxy -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should call Install-WslProxy when Name is provided" {
            Mock Write-Host {}
            Mock Install-WslProxy { $true }

            Invoke-WslManager -Command "setup-proxy" -Name "Debian"

            Should -Invoke Install-WslProxy -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Confirm -eq $false
            }
        }

        It "Should display success message after proxy configuration" {
            Mock Write-Host {}
            Mock Install-WslProxy { $true }

            Invoke-WslManager -Command "setup-proxy" -Name "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully configured proxy*" }
        }

        It "Should propagate errors from Install-WslProxy" {
            Mock Write-Host {}
            Mock Install-WslProxy { throw "Proxy configuration failed: Prerequisite check failed." }

            { Invoke-WslManager -Command "setup-proxy" -Name "Debian" } | Should -Throw "*Prerequisite check failed*"
        }

        It "Should support selection by number" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Install-WslProxy { $true }

            Invoke-WslManager -Command "setup-proxy"

            Should -Invoke Install-WslProxy -ParameterFilter { $DistroName -eq "Ubuntu" }
        }

        It "Should support selection by name" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Alpine" }
            Mock Install-WslProxy { $true }

            Invoke-WslManager -Command "setup-proxy"

            Should -Invoke Install-WslProxy -ParameterFilter { $DistroName -eq "Alpine" }
        }

        It "Should reject invalid number selection" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Install-WslProxy { $true }

            Invoke-WslManager -Command "setup-proxy"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Install-WslProxy -Times 0
        }

        It "Should cancel when no selection provided" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Install-WslProxy { $true }

            Invoke-WslManager -Command "setup-proxy"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Install-WslProxy -Times 0
        }
    }

    Context "When called with 'repair-interop' argument" {
        It "Should prompt for distribution when Name is not provided" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}

            Invoke-WslManager -Command "repair-interop"

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should call repair when Name is provided" {
            Mock Write-Host {}
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}

            Invoke-WslManager -Command "repair-interop" -Name "Debian"

            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should skip when interop is already configured" {
            Mock Write-Host {}
            Mock Test-WslInteropConfigured { $true }
            Mock Set-WslConf {}

            Invoke-WslManager -Command "repair-interop" -Name "Debian"

            Should -Invoke Test-WslInteropConfigured -ParameterFilter { $DistroName -eq "Debian" }
            Should -Invoke Set-WslConf -Times 0
        }

        It "Should support selection by number" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                    [PSCustomObject]@{ Name = "Alpine"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}

            Invoke-WslManager -Command "repair-interop"

            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Ubuntu" }
        }

        It "Should reject invalid number selection" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}

            Invoke-WslManager -Command "repair-interop"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Set-WslConf -Times 0
        }

        It "Should cancel when no selection provided" {

            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}

            Invoke-WslManager -Command "repair-interop"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Set-WslConf -Times 0
        }
    }

    Context "When called with 'terminate' argument" {
        BeforeEach {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Test-WslDistroRunning { $true }
        }

        It "Should prompt for distribution selection when Name is not provided" {

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

            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-WarningMsg {}
            Mock Stop-WslDistro {}

            Invoke-WslManager -Command "terminate"

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No running * distributions*" }
            Should -Invoke Stop-WslDistro -Times 0
        }

        It "Should handle terminate errors gracefully" {

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
