<#
.DESCRIPTION
    Pester tests for manager.ps1
#>

# Stub functions mirror PwshSpectreConsole cmdlet names which use state-changing verbs
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Stub functions mirror PwshSpectreConsole cmdlet names')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation

    # Define stub functions for PwshSpectreConsole commands so Pester can mock them
    # without triggering module auto-import (which causes UTF-8 encoding warnings).
    # manager.ps1 skips Import-Module in test environments, so these stubs provide
    # the command names that Pester needs for Mock/Should -Invoke.
    # Note: Format-SpectreColumns and Format-SpectreRows use plural nouns to match
    # the real PwshSpectreConsole cmdlet names; renaming is not possible.
    function Read-SpectreSelection { param($Message, $Choices, $PageSize, [switch]$EnableSearch) $null = $Message, $Choices, $PageSize, $EnableSearch }
    function Read-SpectreConfirm { param($Message, $DefaultAnswer) $null = $Message, $DefaultAnswer }
    function Format-SpectrePanel { param($Header, $Border, $Color, [switch]$Expand) process { $null = $Header, $Border, $Color, $Expand; $_ } }
    function Format-SpectreTable { param($Border, $Color, [switch]$AllowMarkup) process { $null = $Border, $Color, $AllowMarkup; $_ } }
    function Format-SpectreColumns {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Must match PwshSpectreConsole cmdlet name')]
        param() process { $_ }
    }
    function Format-SpectreRows {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Must match PwshSpectreConsole cmdlet name')]
        param() process { $_ }
    }
    function Write-SpectreFigletText { param($Text, $Alignment, $Color, [switch]$PassThru) $null = $Text, $Alignment, $Color, $PassThru }

    . "$PSScriptRoot\commands.ps1"
    . "$PSScriptRoot\manager.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Get-WslManagerPanel" {
    BeforeEach {
        Mock Format-SpectrePanel { "mocked-panel" }
    }

    It "Should wrap content in a panel with WSL Manager header, dark blue border and full width" {
        Get-WslManagerPanel -DistroContent "mocked-table"

        Should -Invoke Format-SpectrePanel -Times 1 -ParameterFilter {
            $Header -like "*WSL Manager*" -and
            $Border -eq "Rounded" -and $Color -eq "DarkBlue" -and $Expand -eq $true
        }
    }
}

Describe "Show-WslMenu" {
    It "Should call Read-SpectreSelection with menu choices" {
        Mock Read-SpectreSelection { "Quit" }

        Show-WslMenu

        Should -Invoke Read-SpectreSelection -Times 1 -ParameterFilter {
            $Message -eq "Select command" -and
            $Choices -contains "Install new distribution" -and
            $Choices -contains "Remove distribution" -and
            $Choices -contains "Setup Podman" -and
            $Choices -contains "Quit" -and
            $EnableSearch -eq $true
        }
    }

    It "Should return command string for selected menu option" {
        Mock Read-SpectreSelection { "Setup Podman" }

        $result = Show-WslMenu

        $result | Should -Be "setup-podman"
    }

    It "Should return 'quit' when Quit is selected" {
        Mock Read-SpectreSelection { "Quit" }

        $result = Show-WslMenu

        $result | Should -Be "quit"
    }

    It "Should return null when user cancels with Ctrl+C" {
        Mock Read-SpectreSelection { $null }

        $result = Show-WslMenu

        $result | Should -Be $null
    }
}

Describe "Start-InteractiveMode" {
    Context "When in CI environment" {
        It "Should display message and exit" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Write-Host {}

            $result = Start-InteractiveMode

            $result | Should -Be $false
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Interactive mode*not available*" }
        }
    }

    Context "When running interactively" {
        BeforeEach {
            Mock Clear-Host {}
            Mock Read-Host {}
            Mock Show-WslDistroTable { "mocked-table" }
            Mock Get-WslManagerPanel {}
        }

        It "Should exit when user selects Quit" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Show-WslMenu { "quit" }

            $result = Start-InteractiveMode

            $result | Should -Be $true
        }

        It "Should exit when user cancels with Ctrl+C" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Show-WslMenu { $null }

            $result = Start-InteractiveMode

            $result | Should -Be $true
        }

        It "Should build single manager panel with distro content" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Show-WslMenu { "quit" }

            Start-InteractiveMode

            Should -Invoke Get-WslManagerPanel -Times 1
        }

        It "Should pause for Enter after a command completes" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            $script:callCount = 0
            Mock Show-WslMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { "update" }
                else { "quit" }
            }
            Mock Invoke-WslCommand {}

            Start-InteractiveMode

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*Press Enter*" } -Times 1
        }

        It "Should return straight to the menu when the picker went back" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            $script:callCount = 0
            Mock Show-WslMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { "update" }
                else { "quit" }
            }
            Mock Invoke-WslCommand { $script:WslSkipContinuePause = $true }

            Start-InteractiveMode

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*Press Enter*" } -Times 0
        }

        It "Should reset the went-back flag before each command" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            $script:WslSkipContinuePause = $true
            $script:callCount = 0
            Mock Show-WslMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { "update" }
                else { "quit" }
            }
            Mock Invoke-WslCommand {}

            Start-InteractiveMode

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*Press Enter*" } -Times 1
        }

        It "Should dispatch to Invoke-WslCommand with 'setup-podman'" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }
            $script:callCount = 0
            Mock Show-WslMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { "setup-podman" }
                else { "quit" }
            }
            Mock Invoke-WslCommand {}

            Start-InteractiveMode

            Should -Invoke Invoke-WslCommand -ParameterFilter { $Command -eq "setup-podman" } -Times 1
        }

        It "Should dispatch to Invoke-WslCommand with 'setup-devpod'" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }
            $script:callCount = 0
            Mock Show-WslMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { "setup-devpod" }
                else { "quit" }
            }
            Mock Invoke-WslCommand {}

            Start-InteractiveMode

            Should -Invoke Invoke-WslCommand -ParameterFilter { $Command -eq "setup-devpod" } -Times 1
        }

        It "Should dispatch to Invoke-WslCommand with 'sync-ssh-config'" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }
            $script:callCount = 0
            Mock Show-WslMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { "sync-ssh-config" }
                else { "quit" }
            }
            Mock Invoke-WslCommand {}

            Start-InteractiveMode

            Should -Invoke Invoke-WslCommand -ParameterFilter { $Command -eq "sync-ssh-config" } -Times 1
        }

        It "Should dispatch to Invoke-WslCommand with 'setup-proxy'" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }
            $script:callCount = 0
            Mock Show-WslMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { "setup-proxy" }
                else { "quit" }
            }
            Mock Invoke-WslCommand {}

            Start-InteractiveMode

            Should -Invoke Invoke-WslCommand -ParameterFilter { $Command -eq "setup-proxy" } -Times 1
        }

        It "Should fetch distro list once per loop and pass it to Invoke-WslCommand" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            $mockDistros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )
            Mock Get-WslDistroList { $mockDistros } -ParameterFilter { $Detailed }
            $script:callCount = 0
            Mock Show-WslMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { "terminate" }
                else { "quit" }
            }
            Mock Invoke-WslCommand {}

            Start-InteractiveMode

            Should -Invoke Get-WslDistroList -Times 2  # once per menu loop iteration
            Should -Invoke Invoke-WslCommand -ParameterFilter { $Command -eq "terminate" -and $null -ne $Distros } -Times 1
        }

        It "Should handle Get-WslDistroList errors gracefully" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList { throw "WSL service not available" } -ParameterFilter { $Detailed }
            Mock Write-ErrorMsg {}
            Mock Show-WslMenu { "quit" }

            Start-InteractiveMode

            Should -Invoke Write-ErrorMsg -ParameterFilter { $Message -like "*WSL service not available*" }
        }

        It "Should handle Invoke-WslCommand errors gracefully" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }
            Mock Write-ErrorMsg {}
            Mock Invoke-WslCommand { throw "Command failed" }
            $script:callCount = 0
            Mock Show-WslMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { "install" }
                else { "quit" }
            }

            Start-InteractiveMode

            Should -Invoke Write-ErrorMsg -ParameterFilter { $Message -like "*Command failed*" }
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
        It "Should call Show-WslDistroTable" {
            Mock Show-WslDistroTable {}

            Invoke-WslManager -Command "list"

            Should -Invoke Show-WslDistroTable -Times 1
        }
    }

    Context "When called with 'remove' argument" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Remove-WslDistro {}
            Mock Read-SpectreConfirm { $true }
        }

        It "Should prompt for distribution selection" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "remove"

            Should -Invoke Read-SpectreSelection -Times 1
            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should ask for confirmation defaulting to No before removing" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "remove"

            Should -Invoke Read-SpectreConfirm -Times 1 -ParameterFilter {
                $Message -like "*Debian*" -and $DefaultAnswer -eq "n"
            }
        }

        It "Should not remove when confirmation is denied" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreSelection { "Debian" }
            Mock Read-SpectreConfirm { $false }

            Invoke-WslManager -Command "remove"

            Should -Invoke Remove-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Cancelled*" }
        }

        It "Should not ask for confirmation when the name is given" {
            Mock Test-RunningInCIorTestEnvironment { $false }

            Invoke-WslManager -Command "remove" -Name "Debian"

            Should -Invoke Read-SpectreConfirm -Times 0
            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Show-WslDistroTable {}
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "remove"

            Should -Invoke Show-WslDistroTable -Times 1
        }

        It "Should cancel when selection is cancelled" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreSelection { $null }

            Invoke-WslManager -Command "remove"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Remove-WslDistro -Times 0
        }

        It "Should warn and skip in CI when no name is provided" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Read-SpectreSelection { "Debian" }
            Mock Write-WarningMsg {}

            Invoke-WslManager -Command "remove"

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*CI*" -and $Message -like "*-Name*" }
            Should -Invoke Read-SpectreSelection -Times 0
            Should -Invoke Remove-WslDistro -Times 0
        }

        It "Should remove using provided selection without prompting" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "debian-test"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "remove" -Name "debian-test"

            Should -Invoke Read-SpectreSelection -Times 0
            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "debian-test" -and $Confirm -eq $false }
        }
    }

    Context "When called with 'create' argument" {
        BeforeEach {
            Mock Write-Host {}
            Mock New-WslDistro {}
        }

        It "Should create distribution when name is provided" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }

            Invoke-WslManager -Command "install" -Name "Debian"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should support any available distribution" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }

            Invoke-WslManager -Command "install" -Name "Ubuntu-22.04"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Ubuntu-22.04" }
        }

        It "Should prompt for distribution when name not provided" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "install"

            Should -Invoke Read-SpectreSelection -Times 1
            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should offer available distributions dynamically" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04", "kali-linux") }
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "install"

            Should -Invoke Read-SpectreSelection -ParameterFilter {
                $Choices.Count -eq 5 -and $Choices -contains "kali-linux"
            }
        }

        It "Should cancel when selection is cancelled" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Read-SpectreSelection { $null }

            Invoke-WslManager -Command "install"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke New-WslDistro -Times 0
        }

        It "Should warn and skip in CI when no name is provided" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Read-SpectreSelection { "Debian" }
            Mock Write-WarningMsg {}

            Invoke-WslManager -Command "install"

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*CI*" -and $Message -like "*-Name*" }
            Should -Invoke Read-SpectreSelection -Times 0
            Should -Invoke New-WslDistro -Times 0
        }

        It "Should reject distribution not in available list" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }

            Invoke-WslManager -Command "install" -Name "InvalidDistro"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not available*" }
            Should -Invoke New-WslDistro -Times 0
        }
    }

    Context "When called without arguments" {
        It "Should call Start-InteractiveMode" {
            Mock Start-InteractiveMode { $true }

            Invoke-WslManager

            Should -Invoke Start-InteractiveMode -Times 1
        }
    }

    Context "When called with 'clone' argument" {
        BeforeEach {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Copy-WslDistro {}
        }

        It "Should clone distribution when both names are provided" {
            Mock Read-SpectreSelection { "Ubuntu" }
            Mock Read-Host { "Other" }

            Invoke-WslManager -Command "clone" -Name "Debian" -TargetName "MyDebian"

            Should -Invoke Read-SpectreSelection -Times 0
            Should -Invoke Read-Host -Times 0
            Should -Invoke Copy-WslDistro -ParameterFilter {
                $SourceName -eq "Debian" -and $TargetName -eq "MyDebian"
            }
        }

        It "Should prompt for source when only target name provided" {
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "clone" -Name "" -TargetName "MyProject"

            Should -Invoke Read-SpectreSelection -Times 1
            Should -Invoke Copy-WslDistro -ParameterFilter {
                $SourceName -eq "Debian" -and $TargetName -eq "MyProject"
            }
        }

        It "Should prompt for target name when only source provided" {
            Mock Read-Host { "MyDebian" } -ParameterFilter { $Prompt -like "*target*" }

            Invoke-WslManager -Command "clone" -Name "Debian" -TargetName ""

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*target*" }
            Should -Invoke Copy-WslDistro -ParameterFilter {
                $SourceName -eq "Debian" -and $TargetName -eq "MyDebian"
            }
        }

        It "Should prompt for both names when neither provided" {
            Mock Read-SpectreSelection { "Debian" }
            Mock Read-Host { "MyDebian" } -ParameterFilter { $Prompt -like "*target*" }

            Invoke-WslManager -Command "clone" -Name "" -TargetName ""

            Should -Invoke Read-SpectreSelection -Times 1
            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*target*" }
        }

        It "Should display installed distributions when prompting for source" {
            Mock Show-WslDistroTable {}
            Mock Read-SpectreSelection { "Debian" }
            Mock Read-Host { "MyProject" } -ParameterFilter { $Prompt -like "*target*" }

            Invoke-WslManager -Command "clone"

            Should -Invoke Show-WslDistroTable -Times 1
        }

        It "Should cancel when source selection is cancelled" {
            Mock Read-SpectreSelection { $null }

            Invoke-WslManager -Command "clone"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Copy-WslDistro -Times 0
        }

        It "Should cancel when no target name provided" {
            Mock Read-SpectreSelection { "Debian" }
            Mock Read-Host { "" } -ParameterFilter { $Prompt -like "*target*" }

            Invoke-WslManager -Command "clone"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Copy-WslDistro -Times 0
        }
    }

    Context "When called with 'update' argument" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Update-WslDistro {}
        }

        It "Should prompt for distribution selection" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "update"

            Should -Invoke Read-SpectreSelection -Times 1
            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Show-WslDistroTable {}
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "update"

            Should -Invoke Show-WslDistroTable -Times 1
        }

        It "Should cancel when selection is cancelled" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreSelection { $null }

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Update-WslDistro -Times 0
        }

        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }

            Invoke-WslManager -Command "update"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No WSL distributions*" }
            Should -Invoke Update-WslDistro -Times 0
        }

        It "Should handle Update-WslDistro errors gracefully" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Arch"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Read-SpectreSelection { "Arch" }
            Mock Update-WslDistro { throw "Distribution 'Arch' is not a Debian/Ubuntu distribution" }

            { Invoke-WslManager -Command "update" } | Should -Throw "*not a Debian/Ubuntu*"
        }

        It "Should update using provided selection without prompting" {
            Mock Read-SpectreSelection { "Ubuntu" }

            Invoke-WslManager -Command "update" -Name "Debian"

            Should -Invoke Read-SpectreSelection -Times 0
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
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
        }

        It "Should prompt for distribution when Name is not provided" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { "Debian" }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Read-SpectreSelection -Times 1
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

        It "Should cancel when selection is cancelled" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { $null }
            Mock Install-WslDockerEngine { $true }

            Invoke-WslManager -Command "setup-docker"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Install-WslDockerEngine -Times 0
        }
    }

    Context "When called with 'setup-podman' argument" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
        }

        It "Should prompt for distribution when Name is not provided" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { "Debian" }
            Mock Install-WslPodman { $true }

            Invoke-WslManager -Command "setup-podman"

            Should -Invoke Read-SpectreSelection -Times 1
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

        It "Should cancel when selection is cancelled" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { $null }
            Mock Install-WslPodman { $true }

            Invoke-WslManager -Command "setup-podman"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Install-WslPodman -Times 0
        }
    }

    Context "When called with 'setup-devpod' argument" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
        }

        It "Should prompt for distribution when Name is not provided" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { "Debian" }
            Mock Install-WslDevPod { $true }

            Invoke-WslManager -Command "setup-devpod"

            Should -Invoke Read-SpectreSelection -Times 1
            Should -Invoke Install-WslDevPod -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should call Install-WslDevPod when Name is provided" {
            Mock Install-WslDevPod { $true }

            Invoke-WslManager -Command "setup-devpod" -Name "Debian"

            Should -Invoke Install-WslDevPod -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Confirm -eq $false
            }
        }

        It "Should display success message after DevPod installation" {
            Mock Write-Host {}
            Mock Install-WslDevPod { $true }

            Invoke-WslManager -Command "setup-devpod" -Name "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully installed DevPod*" }
        }

        It "Should handle no container engine error" {
            Mock Install-WslDevPod { throw "Neither Docker nor Podman is installed in 'Debian'." }

            { Invoke-WslManager -Command "setup-devpod" -Name "Debian" } | Should -Throw "*Neither Docker nor Podman*"
        }

        It "Should handle no default user error" {
            Mock Install-WslDevPod { throw "No default user configured in 'Debian'." }

            { Invoke-WslManager -Command "setup-devpod" -Name "Debian" } | Should -Throw "*default user*"
        }

        It "Should cancel when selection is cancelled" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { $null }
            Mock Install-WslDevPod { $true }

            Invoke-WslManager -Command "setup-devpod"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Install-WslDevPod -Times 0
        }
    }

    Context "When called with 'sync-ssh-config' argument" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
        }

        It "Should call Invoke-WslSyncSshConfig when Name is provided" {
            Mock Invoke-WslSyncSshConfig { $true }

            Invoke-WslManager -Command "sync-ssh-config" -Name "Debian"

            Should -Invoke Invoke-WslSyncSshConfig -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Confirm -eq $false
            }
        }

        It "Should display success message after SSH setup" {
            Mock Write-Host {}
            Mock Invoke-WslSyncSshConfig { $true }

            Invoke-WslManager -Command "sync-ssh-config" -Name "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully synced SSH config*" }
        }

        It "Should prompt for distribution when Name is not provided" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { "Debian" }
            Mock Invoke-WslSyncSshConfig { $true }

            Invoke-WslManager -Command "sync-ssh-config"

            Should -Invoke Read-SpectreSelection -Times 1
            Should -Invoke Invoke-WslSyncSshConfig -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should cancel when selection is cancelled" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { $null }
            Mock Invoke-WslSyncSshConfig { $true }

            Invoke-WslManager -Command "sync-ssh-config"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Invoke-WslSyncSshConfig -Times 0
        }
    }

    Context "When called with 'setup-proxy' argument" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
        }

        It "Should prompt for distribution when Name is not provided" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { "Debian" }
            Mock Install-WslProxy { $true }

            Invoke-WslManager -Command "setup-proxy"

            Should -Invoke Read-SpectreSelection -Times 1
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

        It "Should cancel when selection is cancelled" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Read-SpectreSelection { $null }
            Mock Install-WslProxy { $true }

            Invoke-WslManager -Command "setup-proxy"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Install-WslProxy -Times 0
        }
    }

    Context "When called with 'repair-interop' argument" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Set-WslConf {}
            Mock Stop-WslDistro {}
        }

        It "Should prompt for distribution when Name is not provided" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreSelection { "Debian" }
            Mock Test-WslInteropConfigured { $false }

            Invoke-WslManager -Command "repair-interop"

            Should -Invoke Read-SpectreSelection -Times 1
            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should call repair when Name is provided" {
            Mock Test-WslInteropConfigured { $false }

            Invoke-WslManager -Command "repair-interop" -Name "Debian"

            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should skip when interop is already configured" {
            Mock Test-WslInteropConfigured { $true }

            Invoke-WslManager -Command "repair-interop" -Name "Debian"

            Should -Invoke Test-WslInteropConfigured -ParameterFilter { $DistroName -eq "Debian" }
            Should -Invoke Set-WslConf -Times 0
        }

        It "Should cancel when selection is cancelled" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreSelection { $null }
            Mock Test-WslInteropConfigured { $false }

            Invoke-WslManager -Command "repair-interop"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Set-WslConf -Times 0
        }
    }

    Context "When called with 'terminate' argument" {
        BeforeEach {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Test-WslDistroRunning { $true }
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Stop-WslDistro {}
            Mock Read-SpectreConfirm { $true }
        }

        It "Should prompt for distribution selection when Name is not provided" {
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "terminate"

            Should -Invoke Read-SpectreSelection -Times 1
            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should ask for confirmation defaulting to No before terminating" {
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "terminate"

            Should -Invoke Read-SpectreConfirm -Times 1 -ParameterFilter {
                $Message -like "*Debian*" -and $DefaultAnswer -eq "n"
            }
        }

        It "Should not terminate when confirmation is denied" {
            Mock Read-SpectreSelection { "Debian" }
            Mock Read-SpectreConfirm { $false }

            Invoke-WslManager -Command "terminate"

            Should -Invoke Stop-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Cancelled*" }
        }

        It "Should not ask for confirmation when the name is given" {
            Invoke-WslManager -Command "terminate" -Name "Debian"

            Should -Invoke Read-SpectreConfirm -Times 0
            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should display available distributions" {
            Mock Show-WslDistroTable {}
            Mock Read-SpectreSelection { "Debian" }

            Invoke-WslManager -Command "terminate"

            Should -Invoke Show-WslDistroTable -Times 1
        }

        It "Should call Stop-WslDistro when Name is provided" {
            Mock Read-SpectreSelection { "Ubuntu" }

            Invoke-WslManager -Command "terminate" -Name "Debian"

            Should -Invoke Read-SpectreSelection -Times 0
            Should -Invoke Stop-WslDistro -ParameterFilter {
                $Name -eq "Debian" -and $Confirm -eq $false
            }
        }

        It "Should cancel when selection is cancelled" {
            Mock Read-SpectreSelection { $null }

            Invoke-WslManager -Command "terminate"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Stop-WslDistro -Times 0
        }

        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-WarningMsg {}

            Invoke-WslManager -Command "terminate"

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No running * distributions*" }
            Should -Invoke Stop-WslDistro -Times 0
        }

        It "Should handle terminate errors gracefully" {
            Mock Read-SpectreSelection { "Debian" }
            Mock Stop-WslDistro { throw "Failed to terminate distribution" }

            { Invoke-WslManager -Command "terminate" } | Should -Throw "*Failed to terminate*"
        }
    }

    Context "When called with 'shutdown' argument" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Stop-WslSubsystem {}
        }

        It "Should ask for confirmation naming the running distributions" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreConfirm { $true }

            Invoke-WslManager -Command "shutdown"

            Should -Invoke Read-SpectreConfirm -Times 1 -ParameterFilter {
                $Message -like "*Debian*" -and $Message -notlike "*Ubuntu*" -and $DefaultAnswer -eq "n"
            }
            Should -Invoke Stop-WslSubsystem -Times 1
        }

        It "Should not shut down when confirmation is denied" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-SpectreConfirm { $false }

            Invoke-WslManager -Command "shutdown"

            Should -Invoke Stop-WslSubsystem -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Cancelled*" }
        }

        It "Should shut down without prompting in CI" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Read-SpectreConfirm { $false }

            Invoke-WslManager -Command "shutdown"

            Should -Invoke Read-SpectreConfirm -Times 0
            Should -Invoke Stop-WslSubsystem -Times 1
        }
    }
}
