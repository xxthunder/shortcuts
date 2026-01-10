<#
.DESCRIPTION
    Pester tests for wsl.ps1 WSL utility functions
#>

BeforeAll {
    . "$PSScriptRoot\..\utils\utils.ps1"
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
        It "Should remove distribution using wsl.exe --unregister" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine {}

            Remove-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl.exe --unregister Debian" }
        }
    }

    Context "When Force parameter is used" {
        It "Should skip confirmation and remove distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine {}

            Remove-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl.exe --unregister Debian" }
        }

        It "Should throw error when wsl command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { 
                $global:LASTEXITCODE = 1
                throw "Command line call `"wsl.exe --unregister Debian`" failed with exit code 1"
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

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl.exe --install --distribution kali-linux --no-launch" }
        }
    }

    Context "When creating a new distribution" {
        It "Should create <DistroName> using wsl.exe --install --distribution <DistroName> --no-launch" -ForEach @(
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

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl.exe --install --distribution $DistroName --no-launch" }
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

            $output -join ' ' | Should -Match "To start: wsl.exe --distribution Ubuntu"
        }

        It "Should trim whitespace from distribution name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name "  Debian  " -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl.exe --install --distribution Debian --no-launch" }
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
                throw "Command line call `"wsl.exe --install --distribution Debian --no-launch`" failed with exit code 1"
            }

            { New-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw "*failed with exit code 1*"
        }

        It "Should not display success message when wsl command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine { 
                $global:LASTEXITCODE = 1
                throw "Command line call `"wsl.exe --install --distribution Debian --no-launch`" failed with exit code 1"
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
                $CommandLine -like "wsl.exe --export Debian *"
            }
        }

        It "Should import with target name" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --import MyDebian * *"
            }
        }

        It "Should use default install path when not specified" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --import MyDebian *wsl\MyDebian* *"
            }
        }

        It "Should use custom install path when specified" {
            Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -InstallPath "D:\WSL\MyDebian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --import MyDebian *D:\WSL\MyDebian* *"
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

            $output -join ' ' | Should -Match "To start: wsl.exe --distribution MyUbuntu"
        }

        It "Should trim whitespace from distribution names" {
            Copy-WslDistro -SourceName "  Debian  " -TargetName "  MyDebian  " -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --export Debian *"
            }
            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --import MyDebian *"
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
            Mock Invoke-CommandLine { throw "Export failed" } -ParameterFilter { $CommandLine -like "wsl.exe --export *" }
            Mock Test-Path { $true }
            Mock Remove-Item {}

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false } | Should -Throw

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -like "wsl.exe --import *" } -Times 0
            Should -Invoke Remove-Item
        }

        It "Should clean up temp file when import fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine {} -ParameterFilter { $CommandLine -like "wsl.exe --export *" }
            Mock Invoke-CommandLine { 
                $global:LASTEXITCODE = 1
                throw "Command line call failed with exit code 1" 
            } -ParameterFilter { $CommandLine -like "wsl.exe --import *" }
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
                $CommandLine -like "*wsl.exe --import MyDebian*My WSL\MyDebian*"
            }
        }

        It "Should handle distribution names with hyphens" {
            Mock Get-WslDistroList { @("Ubuntu-22.04") }

            Copy-WslDistro -SourceName "Ubuntu-22.04" -TargetName "My-Project" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --export Ubuntu-22.04 *"
            }
            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --import My-Project *"
            }
        }

        It "Should handle distribution names with underscores" {
            Mock Get-WslDistroList { @("Oracle_Linux_8") }

            Copy-WslDistro -SourceName "Oracle_Linux_8" -TargetName "My_Project" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --export Oracle_Linux_8 *"
            }
        }

        It "Should handle distribution names with dots" {
            Mock Get-WslDistroList { @("openSUSE-Leap-15.6") }

            Copy-WslDistro -SourceName "openSUSE-Leap-15.6" -TargetName "SUSE.Project" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --export openSUSE-Leap-15.6 *"
            }
        }
    }
}

Describe "Invoke-WslDistroCommand" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu", "Alpine") }

            { Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" } | Should -Throw "*does not exist*"
        }
    }

    Context "When executing valid command" {
        It "Should execute command with correct wsl parameters" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { "command output" }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test"

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*wsl.exe --distribution Debian --exec bash -c "echo test"*'
            }
        }

        It "Should pass StopAtError parameter to Invoke-CommandLine" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" -StopAtError $false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $StopAtError -eq $false
            }
        }

        It "Should pass PrintCommand parameter to Invoke-CommandLine" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" -PrintCommand $false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $PrintCommand -eq $false
            }
        }

        It "Should print commands by default when PrintCommand is not specified" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test"

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $PrintCommand -eq $true
            }
        }
    }

    Context "When using -PassThru switch" {
        It "Should capture and return output when -PassThru is specified" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { "command output" }

            $result = Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" -PassThru

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*wsl.exe --distribution Debian --exec bash -c "echo test"*'
            }
            $result | Should -Be "command output"
        }

        It "Should return output when -PassThru is not specified" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { "command output" }

            $result = Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test"

            $result | Should -Be "command output"
        }

        It "Should join multiple output lines with newline when -PassThru is used" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { @("line1", "line2", "line3") }

            $result = Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" -PassThru

            $result | Should -Be "line1`nline2`nline3"
        }

        It "Should not join multiple output lines when -PassThru is not used" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { @("line1", "line2", "line3") }

            $result = Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test"

            $result | Should -HaveCount 3
            $result[0] | Should -Be "line1"
            $result[1] | Should -Be "line2"
            $result[2] | Should -Be "line3"
        }
    }

    Context "When command contains special characters" {
        It "Should handle double quotes in command (escaping with backslash)" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command 'echo "hello world"'

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*bash -c "echo*hello world*"*'
            }
        }

        It "Should handle commands with pipes" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Ubuntu" -Command "cat file.txt | grep pattern"

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*bash -c "cat file.txt | grep pattern"*'
            }
        }

        It "Should handle commands with && operator" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "apt update && apt upgrade"

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*bash -c "apt update && apt upgrade"*'
            }
        }
    }

    Context "When command fails" {
        It "Should throw when StopAtError is true and command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { throw "Command failed with exit code 1" }

            { Invoke-WslDistroCommand -DistroName "Debian" -Command "false" -StopAtError $true } | Should -Throw "*Command failed*"
        }

        It "Should not throw when StopAtError is false and command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-CommandLine { }

            { Invoke-WslDistroCommand -DistroName "Debian" -Command "false" -StopAtError $false } | Should -Not -Throw
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Invoke-WslDistroCommand -DistroName "" -Command "echo test" } | Should -Throw
        }

        It "Should throw when Command is empty" {
            { Invoke-WslDistroCommand -DistroName "Debian" -Command "" } | Should -Throw
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

Describe "Update-WslDistro" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Update-WslDistro -Name "Debian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Update-WslDistro -Name "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When distribution is not Debian/Ubuntu" {
        It "Should throw error for Arch distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Arch") }
            Mock Get-WslDistroType { "arch" }

            { Update-WslDistro -Name "Arch" -Confirm:$false } | Should -Throw "*not a Debian/Ubuntu distribution*"
        }

        It "Should throw error for RHEL family" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Fedora") }
            Mock Get-WslDistroType { "rhel" }

            { Update-WslDistro -Name "Fedora" -Confirm:$false } | Should -Throw "*not a Debian/Ubuntu distribution*"
        }

        It "Should throw error for unknown distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("CustomLinux") }
            Mock Get-WslDistroType { "unknown" }

            { Update-WslDistro -Name "CustomLinux" -Confirm:$false } | Should -Throw "*not a Debian/Ubuntu distribution*"
        }
    }

    Context "When updating Debian/Ubuntu distributions" {
        It "Should update Debian distribution successfully" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }

            Update-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean*"
            }
        }

        It "Should update Ubuntu distribution successfully" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }
            Mock Get-WslDistroType { "ubuntu" }
            Mock Invoke-WslDistroCommand { }

            Update-WslDistro -Name "Ubuntu" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean*"
            }
        }

        It "Should display progress message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }
            Mock Write-Output { }

            Update-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Updating*Debian*"
            }
        }

        It "Should display success message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }
            Mock Write-Output { }

            Update-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Successfully updated*Debian*"
            }
        }

        It "Should trim whitespace from distribution name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }

            Update-WslDistro -Name "  Debian  " -Confirm:$false

            Should -Invoke Get-WslDistroType -ParameterFilter {
                $DistroName -eq "Debian"
            }
        }
    }

    Context "When ShouldProcess is used" {
        It "Should skip update when user cancels confirmation" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }

            Update-WslDistro -Name "Debian" -WhatIf

            Should -Invoke Invoke-WslDistroCommand -Times 0
        }
    }

    Context "When update command fails" {
        It "Should throw error when apt command fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { throw "apt upgrade failed" }

            { Update-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw "*apt upgrade failed*"
        }

        It "Should not display success message when update fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { throw "apt upgrade failed" }
            Mock Write-Output { }

            try {
                Update-WslDistro -Name "Debian" -Confirm:$false
            }
            catch {
                # Expected to throw - suppressing error for test verification
                $null = $_
            }

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Successfully*"
            } -Times 0
        }
    }

    Context "Parameter validation" {
        It "Should throw when Name is empty" {
            { Update-WslDistro -Name "" } | Should -Throw
        }
    }
}

Describe "New-WslUser" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" } | Should -Throw "*does not exist*"
        }
    }

    Context "Username validation" {
        It "Should accept valid username" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "validuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand
        }

        It "Should throw for username starting with number" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }

            { New-WslUser -DistroName "Debian" -Username "1user" -Password "testpass" } | Should -Throw "*invalid username*"
        }

        It "Should throw for username with uppercase letters" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            { New-WslUser -DistroName "Debian" -Username "TestUser" -Password "testpass" } | Should -Throw "*invalid username*"
        }

        It "Should throw for username with special characters" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }

            { New-WslUser -DistroName "Debian" -Username "test@user" -Password "testpass" } | Should -Throw "*invalid username*"
        }

        It "Should accept username with hyphens and underscores" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "test_user-name" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand
        }

        It "Should throw for username longer than 32 characters" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }

            { New-WslUser -DistroName "Debian" -Username ("a" * 33) -Password "testpass" } | Should -Throw "*too long*"
        }

        It "Should accept username with exactly 32 characters" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username ("a" * 32) -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand
        }
    }

    Context "When user already exists" {
        It "Should throw error when user exists" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "1001" } -ParameterFilter { $Command -like "*id -u*" }

            { New-WslUser -DistroName "Debian" -Username "existinguser" -Password "testpass" -Confirm:$false } | Should -Throw "*already exists*"
        }

        It "Should continue when user does not exist" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "newuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter { $Command -like "*useradd*" }
        }
    }

    Context "When creating user" {
        It "Should create user with useradd command" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*useradd -m -s /bin/bash testuser*"
            }
        }

        It "Should set user password with chpasswd" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*echo*testuser:testpass*chpasswd*"
            }
        }

        It "Should add user to sudo group" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*usermod -aG sudo testuser*"
            }
        }

        It "Should configure NOPASSWD in sudoers.d" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*testuser ALL=(ALL) NOPASSWD:ALL*" -and
                $Command -like "*sudo tee /etc/sudoers.d/testuser*" -and
                $Command -like "*chmod 0440*"
            }
        }

        It "Should set default user in wsl.conf" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*[user]*" -and
                $Command -like "*default=testuser*" -and
                $Command -like "*sudo tee /etc/wsl.conf*"
            }
        }

        It "Should display restart message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }
            Mock Write-Output { }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Restarting distribution*"
            }
        }

        It "Should trim username" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "  testuser  " -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*useradd*testuser*" -and $Command -notlike "*  testuser  *"
            }
        }
    }

    Context "When handling passwords" {
        It "Should accept password string" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "plainpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*testuser:plainpass*"
            }
        }

        It "Should handle password with special characters" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password 'p@$$w0rd!&*' -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*testuser:p@*"
            }
        }
    }

    Context "When ShouldProcess is used" {
        It "Should skip user creation when user cancels confirmation" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -WhatIf

            Should -Invoke Invoke-WslDistroCommand -Times 0
        }
    }

    Context "When user creation fails" {
        It "Should throw error when useradd fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { throw "useradd failed" } -ParameterFilter { $Command -like "*useradd*" }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false } | Should -Throw "*useradd failed*"
        }

        It "Should throw error when password setting fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*useradd*" }
            Mock Invoke-WslDistroCommand { throw "chpasswd failed" } -ParameterFilter { $Command -like "*chpasswd*" }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false } | Should -Throw "*chpasswd failed*"
        }

        It "Should not display success message when user creation fails" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { throw "useradd failed" } -ParameterFilter { $Command -like "*useradd*" }
            Mock Write-Output { }

            try {
                New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false
            }
            catch {
                # Expected to throw - suppressing error for test verification
                $null = $_
            }

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Successfully created*"
            } -Times 0
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { New-WslUser -DistroName "" -Username "testuser" -Password "testpass" } | Should -Throw
        }

        It "Should throw when Username is empty" {
            { New-WslUser -DistroName "Debian" -Username "" -Password "testpass" } | Should -Throw
        }

        It "Should throw when Password is empty" {
            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "" } | Should -Throw
        }
    }
}

Describe "Get-WslDefaultUser" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Get-WslDefaultUser -DistroName "Debian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Get-WslDefaultUser -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should return null" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" } -ParameterFilter {
                $Command -like "*cat /etc/wsl.conf*"
            }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When wsl.conf exists but has no [user] section" {
        It "Should return null" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[boot]
systemd=true
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When [user] section exists but has no default= line" {
        It "Should return null" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user]
# No default user configured
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When default user is configured" {
        It "Should return username from 'default=username' format" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user]
default=developer
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -Be "developer"
        }

        It "Should return username from 'default = username' format (with spaces)" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user]
default = johndoe
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -Be "johndoe"
        }

        It "Should return username when [user] section is not first" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[boot]
systemd=true

[user]
default=testuser
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -Be "testuser"
        }

        It "Should return username when there are comments in the file" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
# WSL Configuration
[user]
# Set the default user
default=admin
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -Be "admin"
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Get-WslDefaultUser -DistroName "" } | Should -Throw
        }
    }
}

Describe "Test-WslSystemdConfigured" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Test-WslSystemdConfigured -DistroName "Debian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Test-WslSystemdConfigured -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should return false when wsl.conf is not found" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When systemd is configured in wsl.conf" {
        It "Should return true when systemd=true is set in [boot] section" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=true`n[user]`ndefault=developer"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true when systemd=true with spaces around equals" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd = true"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true when systemd=true with extra whitespace" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`n  systemd  =  true  "
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $true
        }
    }

    Context "When systemd is not configured in wsl.conf" {
        It "Should return false when [boot] section does not exist" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[user]`ndefault=developer"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when systemd is not set in [boot] section" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`n# systemd=true"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when systemd=false" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=false"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when wsl.conf is empty" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When systemd setting is in different sections" {
        It "Should only check [boot] section, not [other] sections" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[other]`nsystemd=true`n[boot]`nsystemd=false"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslSystemdConfigured -DistroName "" } | Should -Throw
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
        It "Should return true for WSL2 distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock wsl {
                @"
  NAME      STATE           VERSION
* Debian    Running         2
  Ubuntu    Stopped         2
"@
            } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = Test-Wsl2Version -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should handle distribution name with special characters" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu-22.04") }
            Mock wsl {
                @"
  NAME              STATE           VERSION
  Ubuntu-22.04      Running         2
"@
            } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

            $result = Test-Wsl2Version -DistroName "Ubuntu-22.04"

            $result | Should -Be $true
        }
    }

    Context "When distribution is WSL1" {
        It "Should return false for WSL1 distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock wsl {
                @"
  NAME      STATE           VERSION
  Debian    Running         1
  Ubuntu    Stopped         2
"@
            } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--verbose" }

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

Describe "Test-WslDockerInstalled" {
    Context "When WSL is not installed" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $false }

            { Test-WslDockerInstalled -DistroName "Debian" } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Test-WslDockerInstalled -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When Docker is installed" {
        It "Should return true when docker --version succeeds" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "Docker version 24.0.7, build afdd53b"
            } -ParameterFilter { $Command -like "*docker --version*" }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should execute docker --version command" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "Docker version 24.0.7, build afdd53b"
            } -ParameterFilter { $Command -like "*docker --version*" }

            Test-WslDockerInstalled -DistroName "Debian"

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*docker --version*" -and
                $DistroName -eq "Debian" -and
                $StopAtError -eq $false -and
                $PrintCommand -eq $false
            }
        }
    }

    Context "When Docker is not installed" {
        It "Should return false when docker command not found" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                throw "docker: command not found"
            } -ParameterFilter { $Command -like "*docker --version*" }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when docker --version returns empty output" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter {
                $Command -like "*docker --version*"
            }

            $result = Test-WslDockerInstalled -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslDockerInstalled -DistroName "" } | Should -Throw
        }
    }
}

Describe "Install-WslDockerEngine" {
    Context "Prerequisite validation - WSL installation" {
        It "Should throw when WSL is not installed" {
            Mock Test-WslInstalled { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*WSL is not installed*"
        }
    }

    Context "Prerequisite validation - Distribution existence" {
        It "Should throw when distribution does not exist" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*does not exist*"
        }
    }

    Context "Prerequisite validation - WSL2 version" {
        It "Should throw when distribution is WSL1" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*WSL2*"
        }

        It "Should provide upgrade command in error message for WSL1" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*wsl.exe --set-version*"
        }
    }

    Context "Prerequisite validation - Systemd configuration" {
        It "Should throw when systemd is not configured in wsl.conf" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*systemd*wsl.conf*"
        }

        It "Should provide wsl.conf configuration instructions in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*[boot]*systemd=true*"
        }

        It "Should provide restart instructions in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*wsl.exe --terminate*"
        }
    }

    Context "Prerequisite validation - Systemd running" {
        It "Should throw when systemd is not running" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*systemd*running*"
        }

        It "Should provide troubleshooting steps in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $false }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*systemctl --version*"
        }
    }

    Context "Prerequisite validation - Distribution type" {
        It "Should throw when distribution is not Debian/Ubuntu" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Arch") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "arch" }

            { Install-WslDockerEngine -DistroName "Arch" -Confirm:$false } | Should -Throw "*Debian*Ubuntu*"
        }

        It "Should accept Debian distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw for Debian
            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false -WhatIf } | Should -Not -Throw
        }

        It "Should accept Ubuntu distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "ubuntu" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "ubuntu`njammy`namd64" } -ParameterFilter { $Command -like "*bash << 'EOF'*os-release*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw for Ubuntu
            { Install-WslDockerEngine -DistroName "Ubuntu" -Confirm:$false -WhatIf } | Should -Not -Throw
        }
    }

    Context "Prerequisite validation - Default user" {
        It "Should throw when no default user is configured and Username not provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*default user*"
        }

        It "Should provide setup-user command in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*setup-user*"
        }

        It "Should use provided Username parameter when specified" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { $null }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }

            # Should not throw when Username is provided
            { Install-WslDockerEngine -DistroName "Debian" -Username "customuser" -Confirm:$false -WhatIf } | Should -Not -Throw
        }

        It "Should auto-detect default user from wsl.conf when Username not provided" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "autodetected" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }
            Mock Invoke-WslDistroCommand { }

            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false -WhatIf

            Should -Invoke Get-WslDefaultUser -Times 1 -ParameterFilter { $DistroName -eq "Debian" }
        }
    }

    Context "Prerequisite validation - Docker already installed" {
        It "Should throw when Docker is already installed" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*already installed*"
        }

        It "Should provide uninstall instructions in error message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $true }

            { Install-WslDockerEngine -DistroName "Debian" -Confirm:$false } | Should -Throw "*apt-get remove*"
        }
    }

    Context "Docker installation workflow" {
        BeforeEach {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }
        }

        It "Should execute installation commands when prerequisites pass" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*apt-get update*"
            }
        }

        It "Should remove old Docker versions" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*apt-get remove*docker*"
            }
        }

        It "Should install Docker prerequisites" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*apt-get install*ca-certificates*curl*"
            }
        }

        It "Should add Docker GPG key" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*gpg --dearmor*docker.gpg*"
            }
        }

        It "Should setup Docker repository" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*apt/sources.list.d/docker.list*"
            }
        }

        It "Should install Docker Engine packages" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*docker-ce*docker-ce-cli*containerd*docker-buildx-plugin*docker-compose-plugin*"
            }
        }

        It "Should add user to docker group" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*usermod -aG docker*developer*"
            }
        }

        It "Should add specified Username to docker group when provided" {
            Install-WslDockerEngine -DistroName "Debian" -Username "customuser" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*usermod -aG docker*customuser*"
            }
        }

        It "Should enable Docker service" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*systemctl enable docker*"
            }
        }

        It "Should start Docker service" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*systemctl start docker*"
            }
        }
    }

    Context "Post-installation verification" {
        BeforeEach {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { "Docker version 24.0.7" }
        }

        It "Should verify Docker Engine version" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*docker --version*"
            }
        }

        It "Should verify Docker Compose version" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*docker compose version*"
            }
        }

        It "Should verify Docker service status" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*systemctl status docker*"
            }
        }

        It "Should run hello-world container test" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*docker run hello-world*"
            }
        }
    }

    Context "SupportsShouldProcess" {
        BeforeEach {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }
            Mock Test-Wsl2Version { $true }
            Mock Test-WslSystemdConfigured { $true }
            Mock Test-WslSystemd { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Get-WslDefaultUser { "developer" }
            Mock Test-WslDockerInstalled { $false }
            Mock Invoke-WslDistroCommand { "debian`nbookworm`namd64" } -ParameterFilter { $Command -like "*. /etc/os-release*echo*VERSION_CODENAME*dpkg --print-architecture*" }
            Mock Invoke-WslDistroCommand { }
        }

        It "Should support -WhatIf parameter" {
            Install-WslDockerEngine -DistroName "Debian" -WhatIf

            # With -WhatIf, no actual commands should be executed
            Should -Invoke Invoke-WslDistroCommand -Times 0
        }

        It "Should execute when -Confirm:false is specified" {
            Install-WslDockerEngine -DistroName "Debian" -Confirm:$false

            # With -Confirm:$false, commands should execute
            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*apt-get update*"
            }
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Install-WslDockerEngine -DistroName "" -Confirm:$false } | Should -Throw
        }
    }
}
