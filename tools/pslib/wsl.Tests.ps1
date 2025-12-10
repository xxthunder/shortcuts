<#
.DESCRIPTION
    Pester tests for wsl.ps1 WSL utility functions
#>

BeforeAll {
    . "$PSScriptRoot\utils.ps1"
    . "$PSScriptRoot\wsl.ps1"
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

Describe "Get-WslAvailableDistro" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Get-WslAvailableDistro } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When WSL is installed" {
        It "Should parse English output correctly" {
            Mock Test-WslInstalled { $true }
            $englishOutput = @"
NAME                        FRIENDLY NAME
Debian                      Debian GNU/Linux
Ubuntu                      Ubuntu
Ubuntu-20.04                Ubuntu 20.04 LTS
Ubuntu-22.04                Ubuntu 22.04 LTS
kali-linux                  Kali Linux Rolling
"@
            Mock wsl { $englishOutput } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--online" }

            $result = Get-WslAvailableDistro

            $result | Should -Contain "Debian"
            $result | Should -Contain "Ubuntu"
            $result | Should -Contain "Ubuntu-20.04"
            $result | Should -Contain "Ubuntu-22.04"
            $result | Should -Contain "kali-linux"
            $result | Should -Not -Contain "NAME"
            $result | Should -Not -Contain "FRIENDLY"
        }

        It "Should handle localized headers (German example)" {
            Mock Test-WslInstalled { $true }
            $germanOutput = @"
NAME                        ANZEIGENAME
Debian                      Debian GNU/Linux
Ubuntu                      Ubuntu
Ubuntu-22.04                Ubuntu 22.04 LTS
"@
            Mock wsl { $germanOutput } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--online" }

            $result = Get-WslAvailableDistro

            $result | Should -Contain "Debian"
            $result | Should -Contain "Ubuntu"
            $result | Should -Contain "Ubuntu-22.04"
            $result | Should -Not -Contain "NAME"
            $result | Should -Not -Contain "ANZEIGENAME"
        }

        It "Should handle null characters in output" {
            Mock Test-WslInstalled { $true }
            $output = "N`0A`0M`0E`0`nD`0e`0b`0i`0a`0n`0      Debian GNU/Linux"
            Mock wsl { $output } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--online" }

            $result = Get-WslAvailableDistro

            $result | Should -Contain "Debian"
        }

        It "Should handle distributions with dots and underscores" {
            Mock Test-WslInstalled { $true }
            $output = @"
NAME                        FRIENDLY NAME
Oracle_Linux_8_10           Oracle Linux 8.10
openSUSE-Leap-15.6          openSUSE Leap 15.6
"@
            Mock wsl { $output } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--online" }

            $result = Get-WslAvailableDistro

            $result | Should -Contain "Oracle_Linux_8_10"
            $result | Should -Contain "openSUSE-Leap-15.6"
        }

        It "Should set and restore LC_ALL environment variable" {
            Mock Test-WslInstalled { $true }
            Mock wsl { "Debian      Debian" } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--online" }

            $originalLcAll = $env:LC_ALL
            Get-WslAvailableDistro
            $afterLcAll = $env:LC_ALL

            $afterLcAll | Should -Be $originalLcAll
        }
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

            Should -Invoke wsl -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--quiet" }
        }
    }
}

Describe "Remove-WslDistro" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Remove-WslDistro -Name "Debian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Remove-WslDistro -Name "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When user cancels confirmation" {
        It "Should not remove distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine {}

            Remove-WslDistro -Name "Debian" -WhatIf

            Should -Invoke Invoke-CommandLine -Times 0
        }
    }

    Context "When user confirms removal" {
        It "Should remove distribution using wsl --unregister" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine {}

            Remove-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl --unregister Debian" }
        }
    }

    Context "When Force parameter is used" {
        It "Should skip confirmation and remove distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine {}

            Remove-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl --unregister Debian" }
        }

        It "Should throw error when wsl command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { 
                $global:LASTEXITCODE = 1
                throw "Command line call `"wsl --unregister Debian`" failed with exit code 1"
            }

            { Remove-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw "*failed with exit code 1*"
        }
    }
}

Describe "New-WslDistro" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { New-WslDistro -Name "Debian" } | Should -Throw "*WSL is not installed*"
        }

        It "Should not attempt installation" {
            Mock Test-WslInstalled { $false }
            Mock Invoke-CommandLine {}

            { New-WslDistro -Name "Ubuntu" } | Should -Throw

            Should -Invoke Invoke-CommandLine -Times 0
        }
    }

    Context "When distribution already exists" {
        It "Should throw an error for existing distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock Get-WslDistroList { @("Debian") }

            { New-WslDistro -Name "Debian" } | Should -Throw "*already exists*"
        }
    }

    Context "When distribution name is not available" {
        It "Should throw an error with available distributions listed" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04", "kali-linux") }
            Mock Get-WslDistroList { @() }

            $errorThrown = $false
            try {
                New-WslDistro -Name "InvalidDistro"
            }
            catch {
                $errorThrown = $true
                $_.Exception.Message | Should -Match "not available"
                $_.Exception.Message | Should -Match "Debian"
                $_.Exception.Message | Should -Match "Ubuntu"
                $_.Exception.Message | Should -Match "kali-linux"
            }

            $errorThrown | Should -Be $true
        }

        It "Should accept any distribution from available list" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04", "kali-linux", "archlinux") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name "kali-linux" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl --install -d kali-linux --no-launch" }
        }
    }

    Context "When creating a new distribution" {
        It "Should create <DistroName> using wsl --install -d <DistroName> --no-launch" -ForEach @(
            @{ DistroName = "Debian" }
            @{ DistroName = "Ubuntu" }
            @{ DistroName = "Ubuntu-22.04" }
            @{ DistroName = "kali-linux" }
        ) {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04", "kali-linux") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name $DistroName -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl --install -d $DistroName --no-launch" }
        }

        It "Should display success message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            $output = New-WslDistro -Name "Debian" -Confirm:$false 6>&1

            $output -join ' ' | Should -Match "Successfully created 'Debian'"
        }

        It "Should display how to start the distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Ubuntu") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            $output = New-WslDistro -Name "Ubuntu" -Confirm:$false 6>&1

            $output -join ' ' | Should -Match "To start: wsl -d Ubuntu"
        }

        It "Should trim whitespace from distribution name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name "  Debian  " -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl --install -d Debian --no-launch" }
        }

        It "Should skip installation when user cancels confirmation" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name "Debian" -WhatIf

            Should -Invoke Invoke-CommandLine -Times 0
        }

        It "Should throw error and stop execution when wsl command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine { 
                $global:LASTEXITCODE = 1
                throw "Command line call `"wsl --install -d Debian --no-launch`" failed with exit code 1"
            }

            { New-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw "*failed with exit code 1*"
        }

        It "Should not display success message when wsl command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine { 
                $global:LASTEXITCODE = 1
                throw "Command line call `"wsl --install -d Debian --no-launch`" failed with exit code 1"
            }
            Mock Write-Output {}

            { New-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw

            # Verify success message was never written
            Should -Invoke Write-Output -Times 0 -ParameterFilter { $InputObject -like "*Successfully created*" }
        }
    }
}

Describe "Copy-WslDistro" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When source distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When target distribution already exists" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian", "MyDebian") }

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" } | Should -Throw "*already exists*"
        }
    }

    Context "When copying distribution successfully" {
        BeforeEach {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine {}
            Mock Test-Path { $false } -ParameterFilter { $Path -notlike "*temp*.tar" }
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*temp*.tar" }
            Mock New-Item {}
            Mock Remove-Item {}
        }

        It "Should export source distribution to temp file" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --export Debian *"
            }
        }

        It "Should import with target name" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --import MyDebian * *"
            }
        }

        It "Should use default install path when not specified" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --import MyDebian *wsl\MyDebian* *"
            }
        }

        It "Should use custom install path when specified" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -InstallPath "D:\WSL\MyDebian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --import MyDebian *D:\WSL\MyDebian* *"
            }
        }

        It "Should clean up temp file after successful import" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false

            Should -Invoke Remove-Item -ParameterFilter {
                $Path -like "*temp*.tar"
            }
        }

        It "Should display success message" {
            $output = Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false 6>&1

            $output -join ' ' | Should -Match "Successfully cloned"
            $output -join ' ' | Should -Match "Debian"
            $output -join ' ' | Should -Match "MyDebian"
        }

        It "Should display how to start the cloned distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }
            Mock Invoke-CommandLine {}
            Mock Test-Path { $false } -ParameterFilter { $Path -notlike "*temp*.tar" }
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*temp*.tar" }
            Mock New-Item {}
            Mock Remove-Item {}

            $output = Copy-WslDistro -SourceName "Ubuntu" -TargetName "MyUbuntu" -Confirm:$false 6>&1

            $output -join ' ' | Should -Match "To start: wsl -d MyUbuntu"
        }

        It "Should trim whitespace from distribution names" {
            Copy-WslDistro -SourceName "  Debian  " -TargetName "  MyDebian  " -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --export Debian *"
            }
            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --import MyDebian *"
            }
        }

        It "Should skip cloning when user cancels confirmation" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -WhatIf

            Should -Invoke Invoke-CommandLine -Times 0
        }
    }

    Context "When export fails" {
        It "Should not attempt import and should clean up" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { throw "Export failed" } -ParameterFilter { $CommandLine -like "wsl --export *" }
            Mock Test-Path { $true }
            Mock Remove-Item {}

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false } | Should -Throw

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -like "wsl --import *" } -Times 0
            Should -Invoke Remove-Item
        }

        It "Should clean up temp file when import fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine {} -ParameterFilter { $CommandLine -like "wsl --export *" }
            Mock Invoke-CommandLine { 
                $global:LASTEXITCODE = 1
                throw "Command line call failed with exit code 1" 
            } -ParameterFilter { $CommandLine -like "wsl --import *" }
            Mock Test-Path { $true }
            Mock Remove-Item {}

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false } | Should -Throw

            # Verify temp file cleanup still happens
            Should -Invoke Remove-Item
        }
    }

    Context "When testing boundary conditions" {
        BeforeEach {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine {}
            Mock Test-Path { $false } -ParameterFilter { $Path -notlike "*temp*.tar" }
            Mock Test-Path { $true } -ParameterFilter { $Path -like "*temp*.tar" }
            Mock New-Item {}
            Mock Remove-Item {}
        }

        It "Should throw on empty source name" {
            { Copy-WslDistro -SourceName "" -TargetName "MyDebian" } | Should -Throw
        }

        It "Should throw on empty target name" {
            { Copy-WslDistro -SourceName "Debian" -TargetName "" } | Should -Throw
        }

        It "Should throw on whitespace-only source name" {
            { Copy-WslDistro -SourceName "   " -TargetName "MyDebian" } | Should -Throw
        }

        It "Should throw on whitespace-only target name" {
            { Copy-WslDistro -SourceName "Debian" -TargetName "   " } | Should -Throw
        }

        It "Should handle install paths with spaces" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -InstallPath "C:\My WSL\MyDebian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "*wsl --import MyDebian*My WSL\MyDebian*"
            }
        }

        It "Should handle distribution names with hyphens" {
            Mock Get-WslDistroList { @("Ubuntu-22.04") }

            Copy-WslDistro -SourceName "Ubuntu-22.04" -TargetName "My-Project" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --export Ubuntu-22.04 *"
            }
            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --import My-Project *"
            }
        }

        It "Should handle distribution names with underscores" {
            Mock Get-WslDistroList { @("Oracle_Linux_8") }

            Copy-WslDistro -SourceName "Oracle_Linux_8" -TargetName "My_Project" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --export Oracle_Linux_8 *"
            }
        }

        It "Should handle distribution names with dots" {
            Mock Get-WslDistroList { @("openSUSE-Leap-15.6") }

            Copy-WslDistro -SourceName "openSUSE-Leap-15.6" -TargetName "SUSE.Project" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl --export openSUSE-Leap-15.6 *"
            }
        }
    }
}
