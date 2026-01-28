<#
.DESCRIPTION
    Pester tests for lib/core.ps1 - Core WSL detection and state management functions
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\utils\utils.ps1"
    . "$PSScriptRoot\..\wsl.ps1"
}

Describe "Test-WslInstalled" {
    It "Should return <Expected> when <Scenario>" -ForEach @(
        @{ Scenario = "wsl.exe command exists"; MockBehavior = { @{ Name = "wsl.exe" } }; Expected = $true }
        @{ Scenario = "wsl.exe command does not exist"; MockBehavior = { $null }; Expected = $false }
        @{ Scenario = "Get-Command throws an error"; MockBehavior = { throw "Command not found" }; Expected = $false }
    ) {
        Mock Get-Command $MockBehavior -ParameterFilter { $Name -eq "wsl" }

        Test-WslInstalled | Should -Be $Expected

        Should -Invoke Get-Command -ParameterFilter { $Name -eq "wsl" }
    }
}

Describe "Get-WslDistroList" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Get-WslDistroList } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When WSL is installed" {
        It "Should return <Expected> when <Scenario>" -ForEach @(
            @{ Scenario = "no distributions installed"; WslOutput = @(); Expected = @() }
            @{ Scenario = "one distribution installed"; WslOutput = @("Debian"); Expected = @("Debian") }
            @{ Scenario = "multiple distributions installed"; WslOutput = @("Debian", "Ubuntu", "Alpine"); Expected = @("Debian", "Ubuntu", "Alpine") }
            @{ Scenario = "output contains null characters"; WslOutput = @("D`0e`0b`0i`0a`0n`0"); Expected = @("Debian") }
            @{ Scenario = "output contains carriage returns"; WslOutput = @("Debian`r", "Ubuntu`r"); Expected = @("Debian", "Ubuntu") }
            @{ Scenario = "output contains whitespace"; WslOutput = @("  Debian  ", "  Ubuntu  "); Expected = @("Debian", "Ubuntu") }
        ) {
            Mock Test-WslInstalled { $true }
            Mock wsl { $WslOutput } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--quiet" }

            $result = Get-WslDistroList

            $result | Should -Be $Expected
        }

        It "Should call wsl with --list --quiet" {
            Mock Test-WslInstalled { $true }
            Mock wsl { @() }

            Get-WslDistroList

            Should -Invoke wsl.exe -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--quiet" }
        }
    }

    Context "When -Detailed switch is specified" {
        It "Should return structured objects with Name, State, Version, IsDefault fields" {
            Mock Test-WslInstalled { $true }
            $verboseOutput = @"
  NAME            STATE           VERSION
* Debian          Running         2
  Ubuntu          Stopped         2
"@
            Mock wsl { $verboseOutput -split "`n" } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = Get-WslDistroList -Detailed

            $result | Should -HaveCount 2

            $result[0].Name | Should -Be "Debian"
            $result[0].State | Should -Be "Running"
            $result[0].Version | Should -Be 2
            $result[0].IsDefault | Should -Be $true

            $result[1].Name | Should -Be "Ubuntu"
            $result[1].State | Should -Be "Stopped"
            $result[1].Version | Should -Be 2
            $result[1].IsDefault | Should -Be $false
        }

        It "Should normalize German localized state 'Wird ausgeführt' to 'Running'" {
            Mock Test-WslInstalled { $true }
            $germanOutput = @"
  NAME            STATUS          VERSION
* Debian          Wird ausgeführt 2
  Ubuntu          Beendet         2
"@
            Mock wsl { $germanOutput -split "`n" } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = Get-WslDistroList -Detailed

            $result[0].State | Should -Be "Running"
            $result[1].State | Should -Be "Stopped"
        }

        It "Should normalize French localized state 'En cours d'exécution' to 'Running'" {
            Mock Test-WslInstalled { $true }
            $frenchOutput = @"
  NOM             ÉTAT            VERSION
* Debian          En cours d'exécution 2
"@
            Mock wsl { $frenchOutput -split "`n" } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = Get-WslDistroList -Detailed

            $result[0].State | Should -Be "Running"
        }

        It "Should clean UTF-16 null characters from output" {
            Mock Test-WslInstalled { $true }
            # Simulate output with null characters between each character
            $outputWithNulls = "  N`0A`0M`0E`0            S`0T`0A`0T`0E`0           V`0E`0R`0S`0I`0O`0N`0`n* D`0e`0b`0i`0a`0n`0          R`0u`0n`0n`0i`0n`0g`0         2`0"
            Mock wsl { $outputWithNulls -split "`n" } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = Get-WslDistroList -Detailed

            $result[0].Name | Should -Be "Debian"
            $result[0].State | Should -Be "Running"
        }

        It "Should return empty array when no distributions are installed" {
            Mock Test-WslInstalled { $true }
            $headerOnly = @"
  NAME            STATE           VERSION
"@
            Mock wsl { $headerOnly -split "`n" } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = @(Get-WslDistroList -Detailed)

            $result | Should -HaveCount 0
            $result.GetType().Name | Should -Be "Object[]"
        }

        It "Should return array with one object when single distribution exists" {
            Mock Test-WslInstalled { $true }
            $singleDistro = @"
  NAME            STATE           VERSION
* Debian          Running         2
"@
            Mock wsl { $singleDistro -split "`n" } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = Get-WslDistroList -Detailed

            $result | Should -HaveCount 1
            @($result).Count | Should -Be 1  # Ensure it's wrapped in array
        }

        It "Should parse WSL1 version as integer 1" {
            Mock Test-WslInstalled { $true }
            $wsl1Output = @"
  NAME            STATE           VERSION
  Ubuntu-18.04    Stopped         1
"@
            Mock wsl { $wsl1Output -split "`n" } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = Get-WslDistroList -Detailed

            $result[0].Version | Should -Be 1
            $result[0].Version | Should -BeOfType [int]
        }

        It "Should handle mixed WSL1 and WSL2 distributions" {
            Mock Test-WslInstalled { $true }
            $mixedOutput = @"
  NAME            STATE           VERSION
* Debian          Running         2
  Ubuntu-18.04    Stopped         1
  Ubuntu-22.04    Stopped         2
"@
            Mock wsl { $mixedOutput -split "`n" } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = Get-WslDistroList -Detailed

            $result | Should -HaveCount 3
            $result[0].Version | Should -Be 2
            $result[1].Version | Should -Be 1
            $result[2].Version | Should -Be 2
        }
    }

    Context "Backward compatibility without -Detailed" {
        It "Should return string array when -Detailed is not specified" {
            Mock Test-WslInstalled { $true }
            Mock wsl { @("Debian", "Ubuntu") } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--quiet" }

            $result = Get-WslDistroList

            $result | Should -HaveCount 2
            $result[0] | Should -BeOfType [string]
            $result | Should -Contain "Debian"
            $result | Should -Contain "Ubuntu"
        }
    }
}

Describe "Get-WslDistroType" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Get-WslDistroType -DistroName "Debian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Get-WslDistroType -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When detecting distribution types" {
        It "Should detect Debian distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "debian" } -ParameterFilter {
                $Command -like '*os-release*' -and $DistroName -eq "Debian"
            }

            $result = Get-WslDistroType -DistroName "Debian"

            $result | Should -Be "debian"
        }

        It "Should detect Ubuntu distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }
            Mock Invoke-WslDistroCommand { "ubuntu" } -ParameterFilter {
                $Command -like '*os-release*' -and $DistroName -eq "Ubuntu"
            }

            $result = Get-WslDistroType -DistroName "Ubuntu"

            $result | Should -Be "ubuntu"
        }

        It "Should detect Arch distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Arch") }
            Mock Invoke-WslDistroCommand { "arch" } -ParameterFilter {
                $Command -like '*os-release*'
            }

            $result = Get-WslDistroType -DistroName "Arch"

            $result | Should -Be "arch"
        }

        It "Should detect Fedora as rhel family" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Fedora") }
            Mock Invoke-WslDistroCommand { "fedora" } -ParameterFilter {
                $Command -like '*os-release*'
            }

            $result = Get-WslDistroType -DistroName "Fedora"

            $result | Should -Be "rhel"
        }

        It "Should detect CentOS as rhel family" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("CentOS") }
            Mock Invoke-WslDistroCommand { "centos" } -ParameterFilter {
                $Command -like '*os-release*'
            }

            $result = Get-WslDistroType -DistroName "CentOS"

            $result | Should -Be "rhel"
        }

        It "Should detect RHEL as rhel family" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("RHEL") }
            Mock Invoke-WslDistroCommand { "rhel" } -ParameterFilter {
                $Command -like '*os-release*'
            }

            $result = Get-WslDistroType -DistroName "RHEL"

            $result | Should -Be "rhel"
        }

        It "Should return unknown for unrecognized distributions" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("CustomLinux") }
            Mock Invoke-WslDistroCommand { "customlinux" } -ParameterFilter {
                $Command -like '*os-release*'
            }

            $result = Get-WslDistroType -DistroName "CustomLinux"

            $result | Should -Be "unknown"
        }
    }

    Context "When parsing os-release output" {
        It "Should execute command silently without printing" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "debian" }

            Get-WslDistroType -DistroName "Debian"

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $PrintCommand -eq $false
            }
        }

        It "Should parse ID field from os-release" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "debian" }

            Get-WslDistroType -DistroName "Debian"

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like '*cat /etc/os-release*grep*ID=*' -and
                $Command -like '*cut -d= -f2*'
            }
        }

        It "Should handle output with quotes" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }
            Mock Invoke-WslDistroCommand { '"ubuntu"' } -ParameterFilter {
                $Command -like '*os-release*'
            }

            $result = Get-WslDistroType -DistroName "Ubuntu"

            $result | Should -Be "ubuntu"
        }

        It "Should handle output with whitespace" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "  debian  " } -ParameterFilter {
                $Command -like '*os-release*'
            }

            $result = Get-WslDistroType -DistroName "Debian"

            $result | Should -Be "debian"
        }

        It "Should normalize to lowercase" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "DEBIAN" } -ParameterFilter {
                $Command -like '*os-release*'
            }

            $result = Get-WslDistroType -DistroName "Debian"

            $result | Should -Be "debian"
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Get-WslDistroType -DistroName "" } | Should -Throw
        }
    }
}

Describe "Test-WslSystemd" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Test-WslSystemd -DistroName "Debian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Test-WslSystemd -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When systemd is available and running" {
        It "Should return true when systemctl --version succeeds" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "systemd 249 (249.11-0ubuntu3.12)"
            } -ParameterFilter { $Command -like "*systemctl --version*" }

            $result = Test-WslSystemd -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should execute systemctl --version command" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "systemd 249" } -ParameterFilter {
                $Command -like "*systemctl --version*"
            }

            Test-WslSystemd -DistroName "Debian"

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*systemctl --version*" -and
                $DistroName -eq "Debian" -and
                $StopAtError -eq $false -and
                $PrintCommand -eq $false
            }
        }
    }

    Context "When systemd is not available or not running" {
        It "Should return false when systemctl command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { throw "systemctl: command not found" } -ParameterFilter {
                $Command -like "*systemctl --version*"
            }

            $result = Test-WslSystemd -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when systemctl returns non-zero exit code" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter {
                $Command -like "*systemctl --version*"
            }

            $result = Test-WslSystemd -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when systemd is not enabled in wsl.conf" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { throw "System has not been booted with systemd" } -ParameterFilter {
                $Command -like "*systemctl --version*"
            }

            $result = Test-WslSystemd -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslSystemd -DistroName "" } | Should -Throw
        }
    }
}

Describe "Test-Wsl2Version" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Test-Wsl2Version -DistroName "Debian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Test-Wsl2Version -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When distribution is WSL2" {
        It "Should return true using Get-WslDistroList -Detailed" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") } -ParameterFilter { -not $Detailed }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }

            $result = Test-Wsl2Version -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should handle distribution name with special characters" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu-22.04") } -ParameterFilter { -not $Detailed }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Ubuntu-22.04"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }

            $result = Test-Wsl2Version -DistroName "Ubuntu-22.04"

            $result | Should -Be $true
        }
    }

    Context "When distribution is WSL1" {
        It "Should return false using Get-WslDistroList -Detailed" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") } -ParameterFilter { -not $Detailed }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 1; IsDefault = $true })
            } -ParameterFilter { $Detailed }

            $result = Test-Wsl2Version -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-Wsl2Version -DistroName "" } | Should -Throw
        }
    }
}

Describe "Get-WslDistroState" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Get-WslDistroState -DistroName "Debian" } | Should -Throw -ExpectedMessage "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu", "Alpine") }

            { Get-WslDistroState -DistroName "NonExistent" } | Should -Throw -ExpectedMessage "*Distribution 'NonExistent' does not exist*"
        }
    }

    Context "When distribution is running" {
        It "Should return 'Running' using Get-WslDistroList -Detailed" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") } -ParameterFilter { -not $Detailed }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }

            $result = Get-WslDistroState -DistroName "Debian"
            $result | Should -Be "Running"
        }
    }

    Context "When distribution is stopped" {
        It "Should return 'Stopped' using Get-WslDistroList -Detailed" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") } -ParameterFilter { -not $Detailed }
            Mock Get-WslDistroList {
                @([PSCustomObject]@{ Name = "Debian"; State = "Stopped"; Version = 2; IsDefault = $true })
            } -ParameterFilter { $Detailed }

            $result = Get-WslDistroState -DistroName "Debian"
            $result | Should -Be "Stopped"
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Get-WslDistroState -DistroName "" } | Should -Throw
        }
    }
}

Describe "Test-WslDistroRunning" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Test-WslDistroRunning -DistroName "Debian" } | Should -Throw -ExpectedMessage "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu", "Alpine") }

            { Test-WslDistroRunning -DistroName "NonExistent" } | Should -Throw -ExpectedMessage "*Distribution 'NonExistent' does not exist*"
        }
    }

    Context "When distribution is running" {
        It "Should return true" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroState { "Running" } -ParameterFilter { $DistroName -eq "Debian" }

            $result = Test-WslDistroRunning -DistroName "Debian"
            $result | Should -Be $true
        }

        It "Should call Get-WslDistroState" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroState { "Running" }

            Test-WslDistroRunning -DistroName "Debian"

            Should -Invoke Get-WslDistroState -Times 1 -ParameterFilter { $DistroName -eq "Debian" }
        }
    }

    Context "When distribution is stopped" {
        It "Should return false" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroState { "Stopped" } -ParameterFilter { $DistroName -eq "Debian" }

            $result = Test-WslDistroRunning -DistroName "Debian"
            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslDistroRunning -DistroName "" } | Should -Throw
        }
    }
}

Describe "Stop-WslDistro" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Stop-WslDistro -Name "Debian" } | Should -Throw -ExpectedMessage "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu", "Alpine") }

            { Stop-WslDistro -Name "NonExistent" } | Should -Throw -ExpectedMessage "*Distribution 'NonExistent' does not exist*"
        }
    }

    Context "When distribution is already stopped" {
        It "Should display informational message and not call terminate" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $false } -ParameterFilter { $DistroName -eq "Debian" }
            Mock Invoke-CommandLine { }
            Mock Write-Information { }

            Stop-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*not running*"
            }
            Should -Invoke Invoke-CommandLine -Times 0 -ParameterFilter {
                $CommandLine -like "*wsl*--terminate*"
            }
        }

        It "Should not throw error when distribution is already stopped" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $false }
            Mock Invoke-CommandLine { }

            { Stop-WslDistro -Name "Debian" -Confirm:$false } | Should -Not -Throw
        }
    }

    Context "When distribution is running" {
        It "Should call wsl.exe --terminate with distribution name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }

            Stop-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -eq "wsl.exe --terminate Debian"
            }
        }

        It "Should display success message after termination" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }
            Mock Write-Information { }

            Stop-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*Successfully terminated*Debian*"
            }
        }

        It "Should trim whitespace from distribution name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }

            Stop-WslDistro -Name "  Debian  " -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -eq "wsl.exe --terminate Debian"
            }
        }
    }

    Context "ShouldProcess support" {
        It "Should skip termination when -WhatIf is specified" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }

            Stop-WslDistro -Name "Debian" -WhatIf

            Should -Invoke Invoke-CommandLine -Times 0
        }

        It "Should proceed when -Confirm:$false is specified" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }

            Stop-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "*wsl.exe --terminate*"
            }
        }

        It "Should proceed in CI environment without prompting" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }
            Mock Test-RunningInCIorTestEnvironment { $true }

            Stop-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "*wsl.exe --terminate*"
            }
        }
    }

    Context "Error handling" {
        It "Should throw when wsl terminate command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine {
                $global:LASTEXITCODE = 1
                throw "Command line call `"wsl.exe --terminate Debian`" failed with exit code 1"
            }

            { Stop-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw "*failed*"
        }

        It "Should not display success message when terminate fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { throw "Terminate failed" }
            Mock Write-Information { }

            try {
                Stop-WslDistro -Name "Debian" -Confirm:$false
            }
            catch {
                $null = $_
            }

            Should -Invoke Write-Information -Times 0 -ParameterFilter {
                $MessageData -like "*Successfully*"
            }
        }
    }

    Context "Parameter validation" {
        It "Should throw when Name is empty" {
            { Stop-WslDistro -Name "" } | Should -Throw
        }

        It "Should throw when Name is whitespace only" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }

            { Stop-WslDistro -Name "   " } | Should -Throw
        }
    }
}
