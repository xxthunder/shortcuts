<#
.DESCRIPTION
    Pester tests for lib/install.ps1 - WSL distribution installation functions
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\wsl.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Get-WslAvailableDistro" {
    Context "When WSL is installed" {
        It "Should parse English output correctly" {
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

            $output = "N`0A`0M`0E`0`nD`0e`0b`0i`0a`0n`0      Debian GNU/Linux"
            Mock wsl { $output } -ParameterFilter { $args[0] -eq "--list" -and $args[1] -eq "--online" }

            $result = Get-WslAvailableDistro

            $result | Should -Contain "Debian"
        }

        It "Should handle distributions with dots and underscores" {

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

Describe "New-WslDistro" {
    Context "When distribution already exists" {
        It "Should throw an error for existing distribution" {
            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04") }
            Mock Get-WslDistroList { @("Debian") }

            { New-WslDistro -Name "Debian" } | Should -Throw "*already exists*"
        }
    }

    Context "When distribution name is not available" {
        It "Should throw an error with available distributions listed" {

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

            Mock Get-WslAvailableDistro { @("Debian", "Ubuntu", "Ubuntu-22.04", "kali-linux") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name $DistroName -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl.exe --install --distribution $DistroName --no-launch" }
        }

        It "Should display success message" {

            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            $output = New-WslDistro -Name "Debian" -Confirm:$false 6>&1

            $output -join ' ' | Should -Match "Successfully created 'Debian'"
        }

        It "Should display how to start the distribution" {

            Mock Get-WslAvailableDistro { @("Ubuntu") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            $output = New-WslDistro -Name "Ubuntu" -Confirm:$false 6>&1

            $output -join ' ' | Should -Match "To start: wsl.exe --distribution Ubuntu"
        }

        It "Should trim whitespace from distribution name" {

            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name "  Debian  " -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl.exe --install --distribution Debian --no-launch" }
        }

        It "Should skip installation when user cancels confirmation" {

            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name "Debian" -WhatIf

            Should -Invoke Invoke-CommandLine -Times 0
        }

        It "Should throw error and stop execution when wsl command fails" {

            Mock Get-WslAvailableDistro { @("Debian") }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {
                $global:LASTEXITCODE = 1
                throw "Command line call `"wsl.exe --install --distribution Debian --no-launch`" failed with exit code 1"
            }

            { New-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw "*failed with exit code 1*"
        }

        It "Should not display success message when wsl command fails" {

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
