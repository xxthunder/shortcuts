<#
.DESCRIPTION
    Pester tests for commands.ps1
#>

# Stub parameters are required for Pester ParameterFilter matching but are not used in the stub body
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Stub function parameters are required for Pester ParameterFilter matching')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation

    # Stub PwshSpectreConsole commands used by commands.ps1
    function Format-SpectreTable { param($Border, $Color, [switch]$AllowMarkup) process { } }

    . "$PSScriptRoot\commands.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Show-WslDistroTable" {
    Context "When distributions exist" {
        BeforeEach {
            Mock Format-SpectreTable { "mocked-table" }
        }

        It "Should call Format-SpectreTable with Rounded border and AllowMarkup" {
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            Show-WslDistroTable -Distros $distros

            Should -Invoke Format-SpectreTable -ParameterFilter {
                $Border -eq "Rounded" -and $Color -eq "Cyan" -and $AllowMarkup -eq $true
            }
        }

        It "Should fetch distros when not provided" {
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }

            Show-WslDistroTable

            Should -Invoke Get-WslDistroList -ParameterFilter { $Detailed -eq $true } -Times 1
            Should -Invoke Format-SpectreTable -Times 1
        }

        It "Should use provided distros without fetching" {
            Mock Get-WslDistroList {}
            $distros = @(
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
            )

            Show-WslDistroTable -Distros $distros

            Should -Invoke Get-WslDistroList -Times 0
            Should -Invoke Format-SpectreTable -Times 1
        }
    }

    Context "When no distributions exist" {
        It "Should return no-distributions message when empty" {
            $result = Show-WslDistroTable -Distros @()

            $result | Should -BeLike "*No WSL distributions*"
        }

        It "Should return no-distributions message when fetched list is empty" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }

            $result = Show-WslDistroTable

            $result | Should -BeLike "*No WSL distributions*"
        }

        It "Should not call Format-SpectreTable when empty" {
            Mock Format-SpectreTable {}

            Show-WslDistroTable -Distros @()

            Should -Invoke Format-SpectreTable -Times 0
        }
    }
}

Describe "Select-WslDistro" {
    Context "When selecting by number" {
        BeforeEach {
            Mock Write-Host {}
        }

        It "Should return the distro name for a valid number" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Read-Host { "2" }

            $result = Select-WslDistro

            $result | Should -Be "Ubuntu"
        }

        It "Should return null for an out-of-range number" {
            Mock Read-Host { "99" }
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            $result = Select-WslDistro -Distros $distros

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When selecting by name" {
        BeforeEach {
            Mock Write-Host {}
        }

        It "Should return the name as-is" {
            Mock Read-Host { "Ubuntu" }
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
            )

            $result = Select-WslDistro -Distros $distros

            $result | Should -Be "Ubuntu"
        }

        It "Should return null for a name not in the list" {
            Mock Read-Host { "NonExistent" }
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            $result = Select-WslDistro -Distros $distros

            $result | Should -BeNullOrEmpty
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not found*" }
        }
    }

    Context "When selection is pre-provided" {
        BeforeEach {
            Mock Read-Host {}
        }

        It "Should resolve a pre-provided number without prompting" {
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
            )

            $result = Select-WslDistro -Selection "1" -Distros $distros

            $result | Should -Be "Debian"
            Should -Invoke Read-Host -Times 0
        }

        It "Should return a pre-provided name without prompting" {
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            $result = Select-WslDistro -Selection "Debian" -Distros $distros

            $result | Should -Be "Debian"
            Should -Invoke Read-Host -Times 0
        }
    }

    Context "When cancelled" {
        It "Should return null on empty input" {
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Write-WarningMsg {}
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            $result = Select-WslDistro -Distros $distros

            $result | Should -BeNullOrEmpty
            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*Cancelling*" }
        }
    }

    Context "When no distributions exist" {
        BeforeEach {
            Mock Write-WarningMsg {}
        }

        It "Should return null and warn" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }

            $result = Select-WslDistro

            $result | Should -BeNullOrEmpty
            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
        }

        It "Should return null when pre-fetched list is empty" {
            $result = Select-WslDistro -Distros @()

            $result | Should -BeNullOrEmpty
            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
        }
    }

    Context "Table display logic" {
        BeforeEach {
            Mock Format-SpectreTable { "mocked-table" }
            Mock Read-Host { "1" }
        }

        It "Should show the table when Distros are not pre-fetched" {
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }

            Select-WslDistro

            Should -Invoke Format-SpectreTable -Times 1
        }

        It "Should not show the table when Distros are pre-fetched" {
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            Select-WslDistro -Distros $distros

            Should -Invoke Format-SpectreTable -Times 0
        }

        It "Should not call Get-WslDistroList when Distros are pre-fetched" {
            Mock Get-WslDistroList {}
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            Select-WslDistro -Distros $distros

            Should -Invoke Get-WslDistroList -Times 0
        }
    }
}

Describe "Invoke-WslCommand" {
    Context "When dispatching commands" {
        It "Should dispatch 'list' to Show-WslDistroTable" {
            Mock Show-WslDistroTable {}

            Invoke-WslCommand -Command "list"

            Should -Invoke Show-WslDistroTable -Times 1
        }

        It "Should dispatch 'install' with Name parameter" {
            Mock Invoke-CreateDistro {}

            Invoke-WslCommand -Command "install" -Name "Debian"

            Should -Invoke Invoke-CreateDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should dispatch 'clone' with SourceName and TargetName" {
            Mock Invoke-CloneDistro {}

            Invoke-WslCommand -Command "clone" -Name "Debian" -TargetName "Debian-Clone"

            Should -Invoke Invoke-CloneDistro -ParameterFilter { $SourceName -eq "Debian" -and $TargetName -eq "Debian-Clone" }
        }

        It "Should dispatch 'remove' with Name" {
            Mock Invoke-RemoveDistro {}

            Invoke-WslCommand -Command "remove" -Name "Debian"

            Should -Invoke Invoke-RemoveDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should dispatch 'update' with Name" {
            Mock Invoke-UpdateDistro {}

            Invoke-WslCommand -Command "update" -Name "Debian"

            Should -Invoke Invoke-UpdateDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should dispatch 'setup-user' with DistroName, Username, and Password" {
            Mock Invoke-SetupUser {}

            Invoke-WslCommand -Command "setup-user" -Name "Debian" -Username "testuser" -Password "pass123"

            Should -Invoke Invoke-SetupUser -ParameterFilter { $DistroName -eq "Debian" -and $Username -eq "testuser" -and $Password -eq "pass123" }
        }

        It "Should dispatch 'setup-proxy' with DistroName" {
            Mock Invoke-SetupProxy {}

            Invoke-WslCommand -Command "setup-proxy" -Name "Debian"

            Should -Invoke Invoke-SetupProxy -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should dispatch 'setup-docker' with DistroName" {
            Mock Invoke-SetupDocker {}

            Invoke-WslCommand -Command "setup-docker" -Name "Debian"

            Should -Invoke Invoke-SetupDocker -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should dispatch 'setup-podman' with DistroName" {
            Mock Invoke-SetupPodman {}

            Invoke-WslCommand -Command "setup-podman" -Name "Debian"

            Should -Invoke Invoke-SetupPodman -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should dispatch 'setup-devpod' with DistroName" {
            Mock Invoke-SetupDevPod {}

            Invoke-WslCommand -Command "setup-devpod" -Name "Debian"

            Should -Invoke Invoke-SetupDevPod -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should dispatch 'repair-interop' with DistroName" {
            Mock Invoke-RepairInterop {}

            Invoke-WslCommand -Command "repair-interop" -Name "Debian"

            Should -Invoke Invoke-RepairInterop -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should dispatch 'terminate' with Name" {
            Mock Invoke-TerminateDistro {}

            Invoke-WslCommand -Command "terminate" -Name "Debian"

            Should -Invoke Invoke-TerminateDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should dispatch 'shutdown'" {
            Mock Invoke-ShutdownWsl {}

            Invoke-WslCommand -Command "shutdown"

            Should -Invoke Invoke-ShutdownWsl -Times 1
        }
    }

    Context "When Distros parameter is provided" {
        It "Should pass Distros to action functions" {
            $testDistros = @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            Mock Invoke-TerminateDistro {}

            Invoke-WslCommand -Command "terminate" -Distros $testDistros

            Should -Invoke Invoke-TerminateDistro -ParameterFilter { $null -ne $Distros }
        }

        It "Should pass Distros to Show-WslDistroTable for list command" {
            $testDistros = @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            Mock Show-WslDistroTable {}

            Invoke-WslCommand -Command "list" -Distros $testDistros

            Should -Invoke Show-WslDistroTable -ParameterFilter { $null -ne $Distros }
        }
    }
}

Describe "Invoke-CreateDistro" {
    Context "When Name is provided" {
        BeforeEach {
            Mock Write-Host {}
            Mock New-WslDistro {}
        }

        It "Should install the named distribution" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "kali-linux") }

            Invoke-CreateDistro -Name "Debian"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should reject an unavailable distribution name" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }

            Invoke-CreateDistro -Name "NonExistent"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not available*" }
            Should -Invoke New-WslDistro -Times 0
        }
    }

    Context "When Name is not provided" {
        BeforeEach {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock New-WslDistro {}
        }

        It "Should prompt and install the selected distribution by number" {
            Mock Read-Host { "1" }

            Invoke-CreateDistro

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should prompt and install the selected distribution by name" {
            Mock Read-Host { "Ubuntu" }

            Invoke-CreateDistro

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Ubuntu" -and $Confirm -eq $false }
        }

        It "Should cancel on empty input" {
            Mock Read-Host { "" }
            Mock Write-WarningMsg {}

            Invoke-CreateDistro

            Should -Invoke New-WslDistro -Times 0
        }

        It "Should reject an invalid number" {
            Mock Read-Host { "99" }

            Invoke-CreateDistro

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke New-WslDistro -Times 0
        }
    }
}

Describe "Invoke-RemoveDistro" {
    Context "When Name is provided" {
        It "Should dispatch to Remove-WslDistro with selected name" {
            Mock Select-WslDistro { "Debian" }
            Mock Remove-WslDistro {}

            Invoke-RemoveDistro -Name "Debian"

            Should -Invoke Select-WslDistro -ParameterFilter { $Selection -eq "Debian" }
            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Debian" -and $Confirm -eq $false }
        }
    }

    Context "When Name is not provided" {
        It "Should prompt via Select-WslDistro and remove selected distro" {
            Mock Select-WslDistro { "Ubuntu" }
            Mock Remove-WslDistro {}

            Invoke-RemoveDistro

            Should -Invoke Select-WslDistro -Times 1
            Should -Invoke Remove-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should return early when selection is cancelled" {
            Mock Select-WslDistro { $null }
            Mock Remove-WslDistro {}

            Invoke-RemoveDistro

            Should -Invoke Remove-WslDistro -Times 0
        }
    }

    Context "When Distros are pre-fetched" {
        It "Should pass Distros to Select-WslDistro" {
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )
            Mock Select-WslDistro { "Debian" }
            Mock Remove-WslDistro {}

            Invoke-RemoveDistro -Distros $distros

            Should -Invoke Select-WslDistro -ParameterFilter { $null -ne $Distros }
        }
    }
}

Describe "Invoke-UpdateDistro" {
    Context "When Name is provided" {
        It "Should dispatch to Update-WslDistro with selected name" {
            Mock Select-WslDistro { "Debian" }
            Mock Update-WslDistro {}

            Invoke-UpdateDistro -Name "Debian"

            Should -Invoke Select-WslDistro -ParameterFilter { $Selection -eq "Debian" }
            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Debian" -and $Confirm -eq $false }
        }
    }

    Context "When Name is not provided" {
        It "Should prompt via Select-WslDistro and update selected distro" {
            Mock Select-WslDistro { "Ubuntu" }
            Mock Update-WslDistro {}

            Invoke-UpdateDistro

            Should -Invoke Select-WslDistro -Times 1
            Should -Invoke Update-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }

        It "Should return early when selection is cancelled" {
            Mock Select-WslDistro { $null }
            Mock Update-WslDistro {}

            Invoke-UpdateDistro

            Should -Invoke Update-WslDistro -Times 0
        }
    }

    Context "When Distros are pre-fetched" {
        It "Should pass Distros to Select-WslDistro" {
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )
            Mock Select-WslDistro { "Debian" }
            Mock Update-WslDistro {}

            Invoke-UpdateDistro -Distros $distros

            Should -Invoke Select-WslDistro -ParameterFilter { $null -ne $Distros }
        }
    }
}

Describe "Invoke-TerminateDistro" {
    Context "When no distributions are running" {
        It "Should display informational message and return" {
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
        BeforeEach {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }
            Mock Test-WslDistroRunning { $true }
        }

        It "Should throw error if Name is not provided" {
            $act = { Invoke-TerminateDistro }

            $act | Should -Throw "*Cannot run interactive*"
        }

        It "Should proceed if Name is provided" {
            Mock Stop-WslDistro { }

            Invoke-TerminateDistro -Name "Debian"

            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Debian" -and $Confirm -eq $false }
        }
    }

    Context "When distributions are running" {
        BeforeEach {
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

        It "Should list all distributions (not just running)" {
            Mock Read-Host { "1" }
            Mock Show-WslDistroTable {}

            Invoke-TerminateDistro

            Should -Invoke Show-WslDistroTable -Times 1
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

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
        }

        It "Should handle non-running distribution name" {
            Mock Read-Host { "Alpine" }

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not in the list*" }
        }

        It "Should error when selecting stopped distro by number" {
            Mock Read-Host { "3" }

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not in the list of running*" }
        }
    }

    Context "When called with pre-fetched Distros" {
        BeforeEach {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Stop-WslDistro {}
            Mock Get-WslDistroList {}
        }

        It "Should not call Get-WslDistroList when Distros are provided" {
            Mock Read-Host { "1" }
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
            )

            Invoke-TerminateDistro -Distros $distros

            Should -Invoke Get-WslDistroList -Times 0
            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should use full list numbering consistent with menu" {
            Mock Read-Host { "3" }
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Stopped"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                [PSCustomObject]@{ Name = "Fedora"; State = "Running"; Version = 2; IsDefault = $false }
            )

            Invoke-TerminateDistro -Distros $distros

            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Fedora" }
        }

        It "Should error when stopped distro selected by number from full list" {
            Mock Read-Host { "1" }
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Stopped"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
            )

            Invoke-TerminateDistro -Distros $distros

            Should -Invoke Stop-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not in the list of running*" }
        }

        It "Should not reprint the distro table when Distros are provided" {
            Mock Read-Host { "Ubuntu" }
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
            )

            Invoke-TerminateDistro -Distros $distros

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Available distributions*" } -Times 0
            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Ubuntu" }
        }
    }
}

Describe "Invoke-SetupUser" {
    Context "When DistroName is provided with credentials" {
        BeforeEach {
            Mock Write-Host {}
            Mock New-WslUser {}
        }

        It "Should call New-WslUser directly without prompting" {
            Invoke-SetupUser -DistroName "Debian" -Username "testuser" -Password "pass"

            Should -Invoke New-WslUser -ParameterFilter {
                $DistroName -eq "Debian" -and $Username -eq "testuser" -and $Confirm -eq $false
            }
        }

        It "Should display success message after user creation" {
            Invoke-SetupUser -DistroName "Ubuntu" -Username "developer" -Password "pass"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully created user*" }
        }
    }

    Context "When DistroName is not provided" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock New-WslUser {}
        }

        It "Should prompt for distribution selection by name" {
            Mock Read-Host { "Debian" }
            Mock Test-RunningInCIorTestEnvironment { $true }

            Invoke-SetupUser -Username "testuser" -Password "pass"

            Should -Invoke New-WslUser -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should prompt for distribution selection by number" {
            Mock Read-Host { "2" }
            Mock Test-RunningInCIorTestEnvironment { $true }

            Invoke-SetupUser -Username "testuser" -Password "pass"

            Should -Invoke New-WslUser -ParameterFilter { $DistroName -eq "Ubuntu" }
        }

        It "Should cancel when no selection provided" {
            Mock Read-Host { "" }

            Invoke-SetupUser -Username "testuser" -Password "pass"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke New-WslUser -Times 0
        }

        It "Should reject invalid number selection" {
            Mock Read-Host { "99" }

            Invoke-SetupUser -Username "testuser" -Password "pass"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke New-WslUser -Times 0
        }

        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-WarningMsg {}

            Invoke-SetupUser -Username "testuser" -Password "pass"

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
            Should -Invoke New-WslUser -Times 0
        }
    }

    Context "When called with pre-fetched Distros" {
        It "Should not call Get-WslDistroList when Distros are provided" {
            Mock Get-WslDistroList {}
            Mock Write-Host {}
            Mock Read-Host { "1" }
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock New-WslUser {}
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
            )

            Invoke-SetupUser -Distros $distros -Username "testuser" -Password "pass"

            Should -Invoke Get-WslDistroList -Times 0
            Should -Invoke New-WslUser -ParameterFilter { $DistroName -eq "Debian" }
        }
    }

    Context "When credentials are missing in CI environment" {
        It "Should skip user setup in CI" {
            Mock Write-Host {}
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock New-WslUser {}

            Invoke-SetupUser -DistroName "Debian"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Skipping user setup in CI*" }
            Should -Invoke New-WslUser -Times 0
        }
    }
}

Describe "Invoke-SetupDocker" {
    Context "When DistroName is provided" {
        BeforeEach {
            Mock Write-Host {}
            Mock Install-WslDockerEngine { $true }
        }

        It "Should call Install-WslDockerEngine directly" {
            Invoke-SetupDocker -DistroName "Debian"

            Should -Invoke Install-WslDockerEngine -ParameterFilter { $DistroName -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should display success message" {
            Invoke-SetupDocker -DistroName "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully installed Docker*" }
        }

        It "Should propagate errors" {
            Mock Install-WslDockerEngine { throw "Docker install failed" }

            $act = { Invoke-SetupDocker -DistroName "Debian" }

            $act | Should -Throw "*Docker install failed*"
        }
    }

    Context "When DistroName is not provided" {
        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-WarningMsg {}
            Mock Install-WslDockerEngine {}

            Invoke-SetupDocker

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
            Should -Invoke Install-WslDockerEngine -Times 0
        }
    }
}

Describe "Invoke-SetupPodman" {
    Context "When DistroName is provided" {
        BeforeEach {
            Mock Write-Host {}
            Mock Install-WslPodman { $true }
        }

        It "Should call Install-WslPodman directly" {
            Invoke-SetupPodman -DistroName "Debian"

            Should -Invoke Install-WslPodman -ParameterFilter { $DistroName -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should display success message" {
            Invoke-SetupPodman -DistroName "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully installed Podman*" }
        }

        It "Should propagate errors" {
            Mock Install-WslPodman { throw "Podman install failed" }

            $act = { Invoke-SetupPodman -DistroName "Debian" }

            $act | Should -Throw "*Podman install failed*"
        }
    }

    Context "When DistroName is not provided" {
        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-WarningMsg {}
            Mock Install-WslPodman {}

            Invoke-SetupPodman

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
            Should -Invoke Install-WslPodman -Times 0
        }
    }
}

Describe "Invoke-SetupDevPod" {
    Context "When DistroName is provided" {
        BeforeEach {
            Mock Write-Host {}
            Mock Install-WslDevPod { $true }
        }

        It "Should call Install-WslDevPod directly" {
            Invoke-SetupDevPod -DistroName "Debian"

            Should -Invoke Install-WslDevPod -ParameterFilter { $DistroName -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should display success message" {
            Invoke-SetupDevPod -DistroName "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully installed DevPod*" }
        }

        It "Should propagate errors" {
            Mock Install-WslDevPod { throw "DevPod install failed" }

            $act = { Invoke-SetupDevPod -DistroName "Debian" }

            $act | Should -Throw "*DevPod install failed*"
        }
    }

    Context "When DistroName is not provided" {
        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-WarningMsg {}
            Mock Install-WslDevPod {}

            Invoke-SetupDevPod

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
            Should -Invoke Install-WslDevPod -Times 0
        }
    }
}

Describe "Invoke-SetupProxy" {
    Context "When DistroName is provided" {
        BeforeEach {
            Mock Write-Host {}
            Mock Install-WslProxy { $true }
        }

        It "Should call Install-WslProxy directly" {
            Invoke-SetupProxy -DistroName "Debian"

            Should -Invoke Install-WslProxy -ParameterFilter { $DistroName -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should display success message" {
            Invoke-SetupProxy -DistroName "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully configured proxy*" }
        }

        It "Should propagate errors" {
            Mock Install-WslProxy { throw "Proxy config failed" }

            $act = { Invoke-SetupProxy -DistroName "Debian" }

            $act | Should -Throw "*Proxy config failed*"
        }
    }

    Context "When DistroName is not provided" {
        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-WarningMsg {}
            Mock Install-WslProxy {}

            Invoke-SetupProxy

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
            Should -Invoke Install-WslProxy -Times 0
        }
    }
}

Describe "Invoke-RepairInterop" {
    Context "When DistroName is provided" {
        BeforeEach {
            Mock Write-Host {}
        }

        It "Should check interop configuration and repair if needed" {
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}

            Invoke-RepairInterop -DistroName "Debian"

            Should -Invoke Test-WslInteropConfigured -ParameterFilter { $DistroName -eq "Debian" }
            Should -Invoke Set-WslConf -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Sections.interop.enabled -eq "true" -and
                $Sections.interop.appendWindowsPath -eq "true"
            }
        }

        It "Should skip repair when interop is already configured" {
            Mock Test-WslInteropConfigured { $true }
            Mock Set-WslConf {}

            Invoke-RepairInterop -DistroName "Debian"

            Should -Invoke Test-WslInteropConfigured -ParameterFilter { $DistroName -eq "Debian" }
            Should -Invoke Set-WslConf -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*already configured*" }
        }
    }

    Context "When DistroName is not provided" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}
        }

        It "Should prompt for distribution selection" {
            Mock Read-Host { "Debian" }

            Invoke-RepairInterop

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should handle selection by number" {
            Mock Read-Host { "2" }

            Invoke-RepairInterop

            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Ubuntu" }
        }

        It "Should cancel when no selection provided" {
            Mock Read-Host { "" }

            Invoke-RepairInterop

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Set-WslConf -Times 0
        }

        It "Should reject invalid number selection" {
            Mock Read-Host { "99" }

            Invoke-RepairInterop

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Set-WslConf -Times 0
        }

        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-WarningMsg {}

            Invoke-RepairInterop

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
            Should -Invoke Set-WslConf -Times 0
        }
    }

    Context "When called with pre-fetched Distros" {
        It "Should not call Get-WslDistroList when Distros are provided" {
            Mock Get-WslDistroList {}
            Mock Write-Host {}
            Mock Read-Host { "1" }
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Running"; Version = 2; IsDefault = $false }
            )

            Invoke-RepairInterop -Distros $distros

            Should -Invoke Get-WslDistroList -Times 0
            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Debian" }
        }
    }
}

Describe "Invoke-CloneDistro" {
    Context "When SourceName and TargetName are provided" {
        It "Should clone the distribution directly" {
            Mock Copy-WslDistro {}

            Invoke-CloneDistro -SourceName "Debian" -TargetName "Debian-Clone"

            Should -Invoke Copy-WslDistro -ParameterFilter { $SourceName -eq "Debian" -and $TargetName -eq "Debian-Clone" -and $Confirm -eq $false }
        }
    }

    Context "When SourceName is not provided" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Copy-WslDistro {}
        }

        It "Should prompt for source distribution" {
            Mock Read-Host { "1" }

            Invoke-CloneDistro -TargetName "MyClone"

            Should -Invoke Copy-WslDistro -ParameterFilter { $SourceName -eq "Debian" -and $TargetName -eq "MyClone" }
        }

        It "Should cancel when no source selection provided" {
            Mock Read-Host { "" }

            Invoke-CloneDistro -TargetName "MyClone"

            Should -Invoke Copy-WslDistro -Times 0
        }
    }

    Context "When TargetName is not provided" {
        BeforeEach {
            Mock Write-Host {}
            Mock Copy-WslDistro {}
        }

        It "Should prompt for target name" {
            Mock Read-Host { "MyClone" }
            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            Invoke-CloneDistro -SourceName "Debian" -Distros $distros

            Should -Invoke Copy-WslDistro -ParameterFilter { $SourceName -eq "Debian" -and $TargetName -eq "MyClone" }
        }

        It "Should cancel when no target name provided" {
            Mock Read-Host { "" }
            Mock Write-WarningMsg {}

            Invoke-CloneDistro -SourceName "Debian"

            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No target name*" }
            Should -Invoke Copy-WslDistro -Times 0
        }
    }
}

Describe "Invoke-ShutdownWsl" {
    Context "When distributions are running" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Stop-WslSubsystem { }
            Mock Write-Host { }
        }

        It "Should warn about running distributions" {
            Invoke-ShutdownWsl

            Should -Invoke Write-Host -ParameterFilter {
                $Object -like "*Debian*" -and $ForegroundColor -eq "Yellow"
            }
        }

        It "Should call Stop-WslSubsystem" {
            Invoke-ShutdownWsl

            Should -Invoke Stop-WslSubsystem -Times 1
        }
    }

    Context "When no distributions are running" {
        BeforeEach {
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Stopped"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }
            Mock Stop-WslSubsystem { }
            Mock Write-Host { }
        }

        It "Should not display warning" {
            Invoke-ShutdownWsl

            Should -Invoke Write-Host -ParameterFilter {
                $ForegroundColor -eq "Yellow" -and $Object -like "*will be stopped*"
            } -Times 0
        }

        It "Should still call Stop-WslSubsystem" {
            Invoke-ShutdownWsl

            Should -Invoke Stop-WslSubsystem -Times 1
        }
    }

    Context "When no distributions are installed" {
        BeforeEach {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Stop-WslSubsystem { }
            Mock Write-Host { }
        }

        It "Should call Stop-WslSubsystem" {
            Invoke-ShutdownWsl

            Should -Invoke Stop-WslSubsystem -Times 1
        }
    }
}

Describe "Invoke-ConfigureWslDefault" {
    BeforeEach {
        Mock Write-Host { }
        Mock Invoke-ConfigureWsl { }
    }

    It "Should call Invoke-ConfigureWsl" {
        Invoke-ConfigureWslDefault

        Should -Invoke Invoke-ConfigureWsl -Times 1
    }

    It "Should pass -Confirm:false to Invoke-ConfigureWsl" {
        Invoke-ConfigureWslDefault

        Should -Invoke Invoke-ConfigureWsl -ParameterFilter { $Confirm -eq $false }
    }

    It "Should display a status message before calling Invoke-ConfigureWsl" {
        Invoke-ConfigureWslDefault

        Should -Invoke Write-Host -ParameterFilter {
            $Object -like "*Applying default WSL global settings*"
        }
    }

    It "Should call Write-Success when done" {
        Invoke-ConfigureWslDefault

        Should -Invoke Write-Host -ParameterFilter {
            $Object -like "*Done*" -and $ForegroundColor -eq "Green"
        }
    }
}
