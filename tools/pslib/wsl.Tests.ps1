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
        It "Should throw an error for existing Debian" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Debian") }

            { New-WslDistro -Name "Debian" } | Should -Throw "*already exists*"
        }

        It "Should throw an error for existing Ubuntu" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @("Ubuntu") }

            { New-WslDistro -Name "Ubuntu" } | Should -Throw "*already exists*"
        }
    }

    Context "When distribution name is unsupported" {
        It "Should throw an error for unsupported distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() }

            { New-WslDistro -Name "Alpine" } | Should -Throw "*Unsupported distribution*"
        }
    }

    Context "When creating a new distribution" {
        It "Should create <DistroName> using wsl --install -d <DistroName> --no-launch" -ForEach @(
            @{ DistroName = "Debian" }
            @{ DistroName = "Ubuntu" }
        ) {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name $DistroName -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl --install -d $DistroName --no-launch" }
        }

        It "Should display success message" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            $output = New-WslDistro -Name "Debian" -Confirm:$false 6>&1

            $output -join ' ' | Should -Match "Successfully created 'Debian'"
        }

        It "Should display how to start the distribution" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            $output = New-WslDistro -Name "Ubuntu" -Confirm:$false 6>&1

            $output -join ' ' | Should -Match "To start: wsl -d Ubuntu"
        }

        It "Should trim whitespace from distribution name" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name "  Debian  " -Confirm:$false

            Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq "wsl --install -d Debian --no-launch" }
        }

        It "Should skip installation when user cancels confirmation" {
            Mock Test-WslInstalled { $true }
            Mock Get-WslDistroList { @() }
            Mock Invoke-CommandLine {}

            New-WslDistro -Name "Debian" -WhatIf

            Should -Invoke Invoke-CommandLine -Times 0
        }
    }
}
