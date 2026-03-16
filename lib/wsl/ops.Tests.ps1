<#
.DESCRIPTION
    Pester tests for lib/ops.ps1 - WSL distribution operations (remove, copy, update)
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

Describe "Stop-WslSubsystem" {
    Context "When distributions are running" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Running"; Version = 2; IsDefault = $true },
                    [PSCustomObject]@{ Name = "Ubuntu"; State = "Stopped"; Version = 2; IsDefault = $false }
                )
            } -ParameterFilter { $Detailed }
            Mock Invoke-CommandLine { }
            Mock Write-Warning { }
            Mock Write-Output { }
        }

        It "Should warn about running distributions" {
            Stop-WslSubsystem -Confirm:$false

            Should -Invoke Write-Warning -ParameterFilter {
                $Message -like "*Debian*"
            }
        }

        It "Should execute wsl.exe --shutdown" {
            Stop-WslSubsystem -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -eq "wsl.exe --shutdown"
            }
        }
    }

    Context "When no distributions are running" {
        BeforeEach {
            Mock Get-WslDistroList {
                @(
                    [PSCustomObject]@{ Name = "Debian"; State = "Stopped"; Version = 2; IsDefault = $true }
                )
            } -ParameterFilter { $Detailed }
            Mock Invoke-CommandLine { }
            Mock Write-Warning { }
            Mock Write-Output { }
        }

        It "Should not warn about running distributions" {
            Stop-WslSubsystem -Confirm:$false

            Should -Invoke Write-Warning -Times 0
        }

        It "Should still execute wsl.exe --shutdown" {
            Stop-WslSubsystem -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -eq "wsl.exe --shutdown"
            }
        }

        It "Should display idempotent message" {
            Stop-WslSubsystem -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*No distributions are currently running*"
            }
        }
    }

    Context "When no distributions are installed" {
        BeforeEach {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Invoke-CommandLine { }
            Mock Write-Warning { }
            Mock Write-Output { }
        }

        It "Should not warn and still execute shutdown" {
            Stop-WslSubsystem -Confirm:$false

            Should -Invoke Write-Warning -Times 0
            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -eq "wsl.exe --shutdown"
            }
        }
    }

    Context "When ShouldProcess is used" {
        BeforeEach {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Invoke-CommandLine { }
            Mock Write-Output { }
        }

        It "Should skip shutdown when user cancels with -WhatIf" {
            Stop-WslSubsystem -WhatIf

            Should -Invoke Invoke-CommandLine -Times 0
        }
    }

    Context "When shutdown command fails" {
        BeforeEach {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Write-Output { }
            Mock Invoke-CommandLine {
                $global:LASTEXITCODE = 1
                throw "Command line call `"wsl.exe --shutdown`" failed with exit code 1"
            }
        }

        It "Should throw error when wsl command fails" {
            { Stop-WslSubsystem -Confirm:$false } | Should -Throw "*failed with exit code 1*"
        }
    }

    Context "When displaying output" {
        BeforeEach {
            Mock Get-WslDistroList { @() } -ParameterFilter { $Detailed }
            Mock Invoke-CommandLine { }
            Mock Write-Output { }
        }

        It "Should display shutdown progress message" {
            Stop-WslSubsystem -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Shutting down WSL subsystem*"
            }
        }

        It "Should display success message after shutdown" {
            Stop-WslSubsystem -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*WSL subsystem has been shut down*"
            }
        }
    }
}

Describe "Merge-WslConfig" {
    Context "When .wslconfig is empty" {
        It "Should create [wsl2] section with all defaults" {
            $defaults = [ordered]@{
                networkingMode = "mirrored"
                dnsTunneling   = "true"
            }

            $result = Merge-WslConfig -Lines @() -Defaults $defaults

            $result.Changed | Should -Be $true
            $result.Lines | Should -Contain "[wsl2]"
            $result.Lines | Should -Contain "networkingMode = mirrored"
            $result.Lines | Should -Contain "dnsTunneling = true"
        }
    }

    Context "When [wsl2] section is missing from existing content" {
        It "Should append [wsl2] section after existing content" {
            $lines = @("[other]", "key=value")
            $defaults = [ordered]@{ networkingMode = "mirrored" }

            $result = Merge-WslConfig -Lines $lines -Defaults $defaults

            $result.Changed | Should -Be $true
            $result.Lines | Should -Contain "[wsl2]"
            $result.Lines | Should -Contain "networkingMode = mirrored"
        }
    }

    Context "When [wsl2] section exists with all defaults already set" {
        It "Should report no changes needed" {
            $lines = @("[wsl2]", "networkingMode = mirrored", "dnsTunneling = true")
            $defaults = [ordered]@{
                networkingMode = "mirrored"
                dnsTunneling   = "true"
            }

            $result = Merge-WslConfig -Lines $lines -Defaults $defaults

            $result.Changed | Should -Be $false
        }
    }

    Context "When [wsl2] section exists with a key missing" {
        It "Should add missing key without altering existing ones" {
            $lines = @("[wsl2]", "networkingMode = mirrored")
            $defaults = [ordered]@{
                networkingMode = "mirrored"
                dnsTunneling   = "true"
            }

            $result = Merge-WslConfig -Lines $lines -Defaults $defaults

            $result.Changed | Should -Be $true
            $result.Lines | Should -Contain "networkingMode = mirrored"
            $result.Lines | Should -Contain "dnsTunneling = true"
        }
    }

    Context "When user has a different (custom) value for a key" {
        It "Should leave the user value untouched" {
            $lines = @("[wsl2]", "networkingMode = nat")
            $defaults = [ordered]@{ networkingMode = "mirrored" }

            $result = Merge-WslConfig -Lines $lines -Defaults $defaults

            $result.Changed | Should -Be $false
            $result.Lines | Should -Contain "networkingMode = nat"
        }
    }

    Context "kernelCommandLine special handling" {
        It "Should append missing parameters to existing kernelCommandLine" {
            $lines = @("[wsl2]", "kernelCommandLine = cgroup_no_v1=all")
            $defaults = [ordered]@{
                kernelCommandLine = "cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1"
            }

            $result = Merge-WslConfig -Lines $lines -Defaults $defaults

            $result.Changed | Should -Be $true
            ($result.Lines | Where-Object { $_ -like "kernelCommandLine*" }) | Should -Match "systemd.unified_cgroup_hierarchy=1"
            ($result.Lines | Where-Object { $_ -like "kernelCommandLine*" }) | Should -Match "cgroup_no_v1=all"
        }

        It "Should not change kernelCommandLine when all default params are already present" {
            $lines = @("[wsl2]", "kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1")
            $defaults = [ordered]@{
                kernelCommandLine = "cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1"
            }

            $result = Merge-WslConfig -Lines $lines -Defaults $defaults

            $result.Changed | Should -Be $false
        }

        It "Should preserve extra user params in kernelCommandLine when appending" {
            $lines = @("[wsl2]", "kernelCommandLine = myCustomParam cgroup_no_v1=all")
            $defaults = [ordered]@{
                kernelCommandLine = "cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1"
            }

            $result = Merge-WslConfig -Lines $lines -Defaults $defaults

            $result.Changed | Should -Be $true
            ($result.Lines | Where-Object { $_ -like "kernelCommandLine*" }) | Should -Match "myCustomParam"
            ($result.Lines | Where-Object { $_ -like "kernelCommandLine*" }) | Should -Match "systemd.unified_cgroup_hierarchy=1"
        }
    }

    Context "When [wsl2] is followed by another section" {
        It "Should insert missing keys before the next section" {
            $lines = @("[wsl2]", "networkingMode = mirrored", "", "[experimental]", "autoMemoryReclaim=gradual")
            $defaults = [ordered]@{
                networkingMode = "mirrored"
                dnsTunneling   = "true"
            }

            $result = Merge-WslConfig -Lines $lines -Defaults $defaults

            $result.Changed | Should -Be $true
            # dnsTunneling should appear before [experimental]
            $wsl2Idx = [Array]::IndexOf($result.Lines, "[wsl2]")
            $expIdx = [Array]::IndexOf($result.Lines, "[experimental]")
            $dnsTunnelingIdx = [Array]::IndexOf($result.Lines, "dnsTunneling = true")
            $dnsTunnelingIdx | Should -BeGreaterThan $wsl2Idx
            $dnsTunnelingIdx | Should -BeLessThan $expIdx
        }
    }
}

Describe "Invoke-ConfigureWsl" {
    BeforeAll {
        # USERPROFILE is not set on Linux CI; provide a temporary directory so
        # Join-Path doesn't fail before mocks are applied.
        if ([string]::IsNullOrEmpty($env:USERPROFILE)) {
            $env:USERPROFILE = $TestDrive
        }
    }

    BeforeEach {
        $script:wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"
        Mock Write-Output { }
        Mock Test-Path { $false } -ParameterFilter { $Path -eq $script:wslConfigPath }
        Mock Get-Content { @() }
        Mock Set-Content { }
        Mock Copy-Item { }
        Mock Get-Date { "20260309120000" }
    }

    Context "When .wslconfig does not exist" {
        It "Should create the file with defaults" {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq $script:wslConfigPath }

            Invoke-ConfigureWsl -Confirm:$false

            Should -Invoke Set-Content -Times 1
        }

        It "Should not create a backup when file does not exist" {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq $script:wslConfigPath }

            Invoke-ConfigureWsl -Confirm:$false

            Should -Invoke Copy-Item -Times 0
        }
    }

    Context "When .wslconfig exists and already has all defaults" {
        It "Should not write the file" {
            $existingContent = @(
                "[wsl2]",
                "kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1",
                "networkingMode = mirrored",
                "dnsTunneling = true",
                "autoProxy = true"
            )
            Mock Test-Path { $true } -ParameterFilter { $Path -eq $script:wslConfigPath }
            Mock Get-Content { $existingContent }

            Invoke-ConfigureWsl -Confirm:$false

            Should -Invoke Set-Content -Times 0
        }

        It "Should report that no changes are needed" {
            $existingContent = @(
                "[wsl2]",
                "kernelCommandLine = cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1",
                "networkingMode = mirrored",
                "dnsTunneling = true",
                "autoProxy = true"
            )
            Mock Test-Path { $true } -ParameterFilter { $Path -eq $script:wslConfigPath }
            Mock Get-Content { $existingContent }

            Invoke-ConfigureWsl -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*already has all required defaults*"
            }
        }
    }

    Context "When .wslconfig exists but is missing some defaults" {
        BeforeEach {
            $existingContent = @("[wsl2]", "networkingMode = mirrored")
            Mock Test-Path { $true } -ParameterFilter { $Path -eq $script:wslConfigPath }
            Mock Get-Content { $existingContent }
        }

        It "Should write updated content" {
            Invoke-ConfigureWsl -Confirm:$false

            Should -Invoke Set-Content -Times 1
        }

        It "Should create a timestamped backup" {
            Invoke-ConfigureWsl -Confirm:$false

            Should -Invoke Copy-Item -Times 1
        }

        It "Should inform the user a backup was created" {
            Invoke-ConfigureWsl -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Backup created*"
            }
        }

        It "Should hint to restart WSL" {
            Invoke-ConfigureWsl -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*wsl-manager shutdown*"
            }
        }
    }

    Context "When -WhatIf is used" {
        It "Should not write the file" {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq $script:wslConfigPath }

            Invoke-ConfigureWsl -WhatIf

            Should -Invoke Set-Content -Times 0
        }
    }
}
