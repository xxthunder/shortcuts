<#
.DESCRIPTION
    Pester tests for lib/ops.ps1 - WSL distribution operations (remove, copy, update)
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\utils\utils.ps1"
    . "$PSScriptRoot\..\wsl.ps1"
}

Describe "Remove-WslDistro" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Remove-WslDistro -Name "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When distribution is running" {
        It "Should throw error with terminate instruction" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }

            { Remove-WslDistro -Name "TestProject" -Confirm:$false } | Should -Throw "*is running*Stop it first with*wsl --terminate TestProject*"
        }

        It "Should not call unregister when distribution is running" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }

            try {
                Remove-WslDistro -Name "TestProject" -Confirm:$false
            }
            catch {
                $null = $_
            }

            Should -Invoke Invoke-CommandLine -Times 0 -ParameterFilter {
                $CommandLine -like "*wsl.exe --unregister*"
            }
        }
    }

    Context "When user cancels confirmation" {
        It "Should not remove distribution" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Invoke-CommandLine {}

            Remove-WslDistro -Name "Debian" -WhatIf

            Should -Invoke Invoke-CommandLine -Times 0
        }
    }

    Context "When user confirms removal" {
        It "Should remove distribution using wsl.exe --unregister" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Invoke-CommandLine {}

            Remove-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl.exe --unregister Debian" }
        }
    }

    Context "When Force parameter is used" {
        It "Should skip confirmation and remove distribution" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Invoke-CommandLine {}

            Remove-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl.exe --unregister Debian" }
        }

        It "Should throw error when wsl command fails" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Invoke-CommandLine {
                $global:LASTEXITCODE = 1
                throw "Command line call `"wsl.exe --unregister Debian`" failed with exit code 1"
            }

            { Remove-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw "*failed with exit code 1*"
        }
    }
}

Describe "Copy-WslDistro" {
    Context "When source distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When target distribution already exists" {
        It "Should throw an error" {

            Mock Assert-WslDistroExists { }
            Mock Assert-WslDistroNotExists { throw "Distribution '$($DistroName.Trim())' already exists." }

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" } | Should -Throw "*already exists*"
        }
    }

    Context "When source distribution is running" {
        It "Should throw error with terminate instruction" {

            Mock Assert-WslDistroExists { }
            Mock Assert-WslDistroNotExists { }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyProject" -Confirm:$false } | Should -Throw "*is running*Stop it first with*wsl --terminate Debian*"
        }

        It "Should not call export when source distribution is running" {

            Mock Assert-WslDistroExists { }
            Mock Assert-WslDistroNotExists { }
            Mock Test-WslDistroRunning { $true }
            Mock Invoke-CommandLine { }

            try {
                Copy-WslDistro -SourceName "Debian" -TargetName "MyProject" -Confirm:$false
            }
            catch {
                $null = $_
            }

            Should -Invoke Invoke-CommandLine -Times 0 -ParameterFilter {
                $CommandLine -like "*wsl.exe --export*"
            }
        }
    }

    Context "When copying distribution successfully" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Assert-WslDistroNotExists { }
            Mock Test-WslDistroRunning { $false }
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

            Mock Assert-WslDistroExists { }
            Mock Assert-WslDistroNotExists { }
            Mock Test-WslDistroRunning { $false }
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

            Mock Assert-WslDistroExists { }
            Mock Assert-WslDistroNotExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Invoke-CommandLine { throw "Export failed" } -ParameterFilter { $CommandLine -like "wsl.exe --export *" }
            Mock Test-Path { $true }
            Mock Remove-Item {}

            { Copy-WslDistro -SourceName "Debian" -TargetName "MyDebian" -Confirm:$false } | Should -Throw

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -like "wsl.exe --import *" } -Times 0
            Should -Invoke Remove-Item
        }

        It "Should clean up temp file when import fails" {

            Mock Assert-WslDistroExists { }
            Mock Assert-WslDistroNotExists { }
            Mock Test-WslDistroRunning { $false }
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

            Mock Assert-WslDistroExists { }
            Mock Assert-WslDistroNotExists { }
            Mock Test-WslDistroRunning { $false }
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
            Copy-WslDistro -SourceName "Ubuntu-22.04" -TargetName "My-Project" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --export Ubuntu-22.04 *"
            }
            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --import My-Project *"
            }
        }

        It "Should handle distribution names with underscores" {
            Copy-WslDistro -SourceName "Oracle_Linux_8" -TargetName "My_Project" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --export Oracle_Linux_8 *"
            }
        }

        It "Should handle distribution names with dots" {
            Copy-WslDistro -SourceName "openSUSE-Leap-15.6" -TargetName "SUSE.Project" -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like "wsl.exe --export openSUSE-Leap-15.6 *"
            }
        }
    }
}

Describe "Update-WslDistro" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Update-WslDistro -Name "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When distribution is running" {
        It "Should throw error with terminate instruction" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }

            { Update-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw "*is running*Stop it first with*wsl --terminate Debian*"
        }

        It "Should not call apt update when distribution is running" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $true }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }

            try {
                Update-WslDistro -Name "Debian" -Confirm:$false
            }
            catch {
                $null = $_
            }

            Should -Invoke Invoke-WslDistroCommand -Times 0
        }
    }

    Context "When distribution is not Debian/Ubuntu" {
        It "Should throw error for Arch distribution" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Get-WslDistroType { "arch" }

            { Update-WslDistro -Name "Arch" -Confirm:$false } | Should -Throw "*not a Debian/Ubuntu distribution*"
        }

        It "Should throw error for RHEL family" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Get-WslDistroType { "rhel" }

            { Update-WslDistro -Name "Fedora" -Confirm:$false } | Should -Throw "*not a Debian/Ubuntu distribution*"
        }

        It "Should throw error for unknown distribution" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Get-WslDistroType { "unknown" }

            { Update-WslDistro -Name "CustomLinux" -Confirm:$false } | Should -Throw "*not a Debian/Ubuntu distribution*"
        }
    }

    Context "When updating Debian/Ubuntu distributions" {
        It "Should update Debian distribution successfully" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }

            Update-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean*"
            }
        }

        It "Should update Ubuntu distribution successfully" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Get-WslDistroType { "ubuntu" }
            Mock Invoke-WslDistroCommand { }

            Update-WslDistro -Name "Ubuntu" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*apt update && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean*"
            }
        }

        It "Should display progress message" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }
            Mock Write-Output { }

            Update-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Updating*Debian*"
            }
        }

        It "Should display success message" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }
            Mock Write-Output { }

            Update-WslDistro -Name "Debian" -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Successfully updated*Debian*"
            }
        }

        It "Should trim whitespace from distribution name" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
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

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { }

            Update-WslDistro -Name "Debian" -WhatIf

            Should -Invoke Invoke-WslDistroCommand -Times 0
        }
    }

    Context "When update command fails" {
        It "Should throw error when apt command fails" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
            Mock Get-WslDistroType { "debian" }
            Mock Invoke-WslDistroCommand { throw "apt upgrade failed" }

            { Update-WslDistro -Name "Debian" -Confirm:$false } | Should -Throw "*apt upgrade failed*"
        }

        It "Should not display success message when update fails" {

            Mock Assert-WslDistroExists { }
            Mock Test-WslDistroRunning { $false }
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
