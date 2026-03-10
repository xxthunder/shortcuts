<#
.DESCRIPTION
    Pester tests for commands.ps1
#>

param()

BeforeAll {
    . "$PSScriptRoot\commands.ps1"
}

Describe "Show-WslDistroList" {
    Context "When WSL is installed" {
        It "Should display message when no distributions are installed" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No WSL distributions*" }
        }

        It "Should call Get-WslDistroList with -Detailed switch" {

            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}

            Show-WslDistroList

            Should -Invoke Get-WslDistroList -ParameterFilter { $Detailed -eq $true } -Times 1
        }

        It "Should display distribution name and state" {

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

    Context "When pre-fetched Distros are provided" {
        It "Should use provided distros and not call Get-WslDistroList" {
            Mock Get-WslDistroList {}
            Mock Write-Host {}

            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            Show-WslDistroList -Distros $distros

            Should -Invoke Get-WslDistroList -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
        }

        It "Should display provided distros without re-fetching" {
            Mock Get-WslDistroList {}
            Mock Write-Host {}

            $distros = @(
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false },
                [PSCustomObject]@{ Name = "Fedora"; State = "Running"; Version = 2; IsDefault = $false }
            )

            Show-WslDistroList -Distros $distros

            Should -Invoke Get-WslDistroList -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Fedora*" }
        }

        It "Should display no-distributions message when provided empty list" {
            Mock Get-WslDistroList {}
            Mock Write-Host {}

            Show-WslDistroList -Distros @()

            Should -Invoke Get-WslDistroList -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*No WSL distributions*" }
        }
    }
}

Describe "Select-WslDistro" {
    Context "When selecting by number" {
        It "Should return the distro name for a valid number" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }

            $result = Select-WslDistro

            $result | Should -Be "Ubuntu"
        }

        It "Should return null for an out-of-range number" {
            Mock Write-Host {}
            Mock Read-Host { "99" }

            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            $result = Select-WslDistro -Distros $distros

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When selecting by name" {
        It "Should return the name as-is" {
            Mock Write-Host {}
            Mock Read-Host { "Ubuntu" }

            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
            )

            $result = Select-WslDistro -Distros $distros

            $result | Should -Be "Ubuntu"
        }

        It "Should return null for a name not in the list" {
            Mock Write-Host {}
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
        It "Should resolve a pre-provided number without prompting" {
            Mock Read-Host {}

            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
            )

            $result = Select-WslDistro -Selection "1" -Distros $distros

            $result | Should -Be "Debian"
            Should -Invoke Read-Host -Times 0
        }

        It "Should return a pre-provided name without prompting" {
            Mock Read-Host {}

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
        It "Should return null and warn" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-WarningMsg {}

            $result = Select-WslDistro

            $result | Should -BeNullOrEmpty
            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
        }

        It "Should return null when pre-fetched list is empty" {
            Mock Write-WarningMsg {}

            $result = Select-WslDistro -Distros @()

            $result | Should -BeNullOrEmpty
            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like "*No WSL distributions*" }
        }
    }

    Context "Table display logic" {
        It "Should show the table when Distros are not pre-fetched" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "1" }

            Select-WslDistro

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Available distributions*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
        }

        It "Should not show the table when Distros are pre-fetched" {
            Mock Write-Host {}
            Mock Read-Host { "1" }

            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            Select-WslDistro -Distros $distros

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Available distributions*" } -Times 0
        }

        It "Should not call Get-WslDistroList when Distros are pre-fetched" {
            Mock Get-WslDistroList {}
            Mock Read-Host { "1" }

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
        It "Should dispatch 'list' to Show-WslDistroList" {
            Mock Show-WslDistroList {}

            Invoke-WslCommand -Command "list"

            Should -Invoke Show-WslDistroList -Times 1
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

        It "Should dispatch 'remove' with Selection" {
            Mock Invoke-RemoveDistro {}

            Invoke-WslCommand -Command "remove" -Name "Debian"

            Should -Invoke Invoke-RemoveDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should dispatch 'update' with Selection" {
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

        It "Should pass Distros to Show-WslDistroList for list command" {
            $testDistros = @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            Mock Show-WslDistroList {}

            Invoke-WslCommand -Command "list" -Distros $testDistros

            Should -Invoke Show-WslDistroList -ParameterFilter { $null -ne $Distros }
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
        It "Should throw error if Name is not provided" {
            Mock Test-RunningInCIorTestEnvironment { $true }

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

            Invoke-TerminateDistro

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Debian*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Ubuntu*" }
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Alpine*" }
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

        It "Should error when selecting stopped distro by number" {
            Mock Read-Host { "3" }
            Mock Write-Host {}

            Invoke-TerminateDistro

            Should -Invoke Stop-WslDistro -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not in the list of running*" }
        }
    }

    Context "When called with pre-fetched Distros (interactive menu mode)" {
        BeforeEach {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Write-Host {}
            Mock Stop-WslDistro {}
        }

        It "Should not call Get-WslDistroList when Distros are provided" {
            Mock Get-WslDistroList {}
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
            Mock Get-WslDistroList {}
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
            Mock Get-WslDistroList {}
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
            Mock Get-WslDistroList {}
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

Describe "Invoke-RepairInterop" {
    Context "When DistroName is provided" {
        It "Should check interop configuration and repair if needed" {
            Mock Write-Host {}
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
            Mock Write-Host {}
            Mock Test-WslInteropConfigured { $true }
            Mock Set-WslConf {}

            Invoke-RepairInterop -DistroName "Debian"

            Should -Invoke Test-WslInteropConfigured -ParameterFilter { $DistroName -eq "Debian" }
            Should -Invoke Set-WslConf -Times 0
            Should -Invoke Write-Host -ParameterFilter { $Object -like "*already configured*" }
        }
    }

    Context "When DistroName is not provided" {
        It "Should prompt for distribution selection" {
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

            Invoke-RepairInterop

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*number or name*" }
            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should handle selection by number" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}

            Invoke-RepairInterop

            Should -Invoke Set-WslConf -ParameterFilter { $DistroName -eq "Ubuntu" }
        }

        It "Should cancel when no selection provided" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Test-WslInteropConfigured { $false }
            Mock Set-WslConf {}

            Invoke-RepairInterop

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke Set-WslConf -Times 0
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

            Invoke-RepairInterop

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke Set-WslConf -Times 0
        }

        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-WarningMsg {}
            Mock Test-WslInteropConfigured {}
            Mock Set-WslConf {}

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

Describe "Invoke-SetupUser" {
    Context "When DistroName is provided with credentials" {
        It "Should call New-WslUser directly without prompting" {
            Mock Write-Host {}
            Mock New-WslUser {}

            Invoke-SetupUser -DistroName "Debian" -Username "testuser" -Password "pass"

            Should -Invoke New-WslUser -ParameterFilter {
                $DistroName -eq "Debian" -and $Username -eq "testuser" -and $Confirm -eq $false
            }
        }

        It "Should display success message after user creation" {
            Mock Write-Host {}
            Mock New-WslUser {}

            Invoke-SetupUser -DistroName "Ubuntu" -Username "developer" -Password "pass"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully created user*" }
        }
    }

    Context "When DistroName is not provided" {
        It "Should prompt for distribution selection by name" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "Debian" }
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock New-WslUser {}

            Invoke-SetupUser -Username "testuser" -Password "pass"

            Should -Invoke New-WslUser -ParameterFilter { $DistroName -eq "Debian" }
        }

        It "Should prompt for distribution selection by number" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "2" }
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock New-WslUser {}

            Invoke-SetupUser -Username "testuser" -Password "pass"

            Should -Invoke New-WslUser -ParameterFilter { $DistroName -eq "Ubuntu" }
        }

        It "Should cancel when no selection provided" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock New-WslUser {}

            Invoke-SetupUser -Username "testuser" -Password "pass"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*cancel*" }
            Should -Invoke New-WslUser -Times 0
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
            Mock New-WslUser {}

            Invoke-SetupUser -Username "testuser" -Password "pass"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke New-WslUser -Times 0
        }

        It "Should warn when no distributions exist" {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Write-WarningMsg {}
            Mock New-WslUser {}

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
        It "Should call Install-WslDockerEngine directly" {
            Mock Write-Host {}
            Mock Install-WslDockerEngine { $true }

            Invoke-SetupDocker -DistroName "Debian"

            Should -Invoke Install-WslDockerEngine -ParameterFilter { $DistroName -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should display success message" {
            Mock Write-Host {}
            Mock Install-WslDockerEngine { $true }

            Invoke-SetupDocker -DistroName "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully installed Docker*" }
        }

        It "Should propagate errors" {
            Mock Write-Host {}
            Mock Install-WslDockerEngine { throw "Docker install failed" }

            { Invoke-SetupDocker -DistroName "Debian" } | Should -Throw "*Docker install failed*"
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
        It "Should call Install-WslPodman directly" {
            Mock Write-Host {}
            Mock Install-WslPodman { $true }

            Invoke-SetupPodman -DistroName "Debian"

            Should -Invoke Install-WslPodman -ParameterFilter { $DistroName -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should display success message" {
            Mock Write-Host {}
            Mock Install-WslPodman { $true }

            Invoke-SetupPodman -DistroName "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully installed Podman*" }
        }

        It "Should propagate errors" {
            Mock Write-Host {}
            Mock Install-WslPodman { throw "Podman install failed" }

            { Invoke-SetupPodman -DistroName "Debian" } | Should -Throw "*Podman install failed*"
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

Describe "Invoke-SetupProxy" {
    Context "When DistroName is provided" {
        It "Should call Install-WslProxy directly" {
            Mock Write-Host {}
            Mock Install-WslProxy { $true }

            Invoke-SetupProxy -DistroName "Debian"

            Should -Invoke Install-WslProxy -ParameterFilter { $DistroName -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should display success message" {
            Mock Write-Host {}
            Mock Install-WslProxy { $true }

            Invoke-SetupProxy -DistroName "Ubuntu"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Successfully configured proxy*" }
        }

        It "Should propagate errors" {
            Mock Write-Host {}
            Mock Install-WslProxy { throw "Proxy config failed" }

            { Invoke-SetupProxy -DistroName "Debian" } | Should -Throw "*Proxy config failed*"
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

Describe "Invoke-CreateDistro" {
    Context "When Name is provided" {
        It "Should install the named distribution" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "kali-linux") }
            Mock Write-Host {}
            Mock New-WslDistro {}

            Invoke-CreateDistro -Name "Debian"

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should reject an unavailable distribution name" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock New-WslDistro {}

            Invoke-CreateDistro -Name "NonExistent"

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*not available*" }
            Should -Invoke New-WslDistro -Times 0
        }
    }

    Context "When Name is not provided" {
        It "Should prompt and install the selected distribution by number" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "1" }
            Mock New-WslDistro {}

            Invoke-CreateDistro

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Debian" -and $Confirm -eq $false }
        }

        It "Should prompt and install the selected distribution by name" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "Ubuntu" }
            Mock New-WslDistro {}

            Invoke-CreateDistro

            Should -Invoke New-WslDistro -ParameterFilter { $Name -eq "Ubuntu" -and $Confirm -eq $false }
        }

        It "Should cancel on empty input" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Write-WarningMsg {}
            Mock New-WslDistro {}

            Invoke-CreateDistro

            Should -Invoke New-WslDistro -Times 0
        }

        It "Should reject an invalid number" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu") }
            Mock Write-Host {}
            Mock Read-Host { "99" }
            Mock New-WslDistro {}

            Invoke-CreateDistro

            Should -Invoke Write-Host -ParameterFilter { $Object -like "*Invalid selection*" }
            Should -Invoke New-WslDistro -Times 0
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
        It "Should prompt for source distribution" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "1" }
            Mock Copy-WslDistro {}

            Invoke-CloneDistro -TargetName "MyClone"

            Should -Invoke Copy-WslDistro -ParameterFilter { $SourceName -eq "Debian" -and $TargetName -eq "MyClone" }
        }

        It "Should cancel when no source selection provided" {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Copy-WslDistro {}

            Invoke-CloneDistro -TargetName "MyClone"

            Should -Invoke Copy-WslDistro -Times 0
        }
    }

    Context "When TargetName is not provided" {
        It "Should prompt for target name" {
            Mock Write-Host {}
            Mock Read-Host { "MyClone" }
            Mock Copy-WslDistro {}

            $distros = @(
                [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true }
            )

            Invoke-CloneDistro -SourceName "Debian" -Distros $distros

            Should -Invoke Copy-WslDistro -ParameterFilter { $SourceName -eq "Debian" -and $TargetName -eq "MyClone" }
        }

        It "Should cancel when no target name provided" {
            Mock Write-Host {}
            Mock Read-Host { "" }
            Mock Write-WarningMsg {}
            Mock Copy-WslDistro {}

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
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Stopped"; Version = 2; IsDefault = $true }
                )
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

