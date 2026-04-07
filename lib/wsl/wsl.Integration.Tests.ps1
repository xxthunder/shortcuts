<#
.DESCRIPTION
    Integration tests for wsl.ps1 library functions.
    These tests execute against the actual WSL environment.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'Standard for cross-platform compatibility.')]
param()

Describe "WSL Library Integration Tests" -Tag "Integration" {
    BeforeAll {
        . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
        Start-SutIsolation
        $wslScript = Join-Path $PSScriptRoot ".\wsl.ps1"
        if (Test-Path $wslScript) {
            . $wslScript
        } else {
            Throw "Could not find wsl.ps1 at $wslScript"
        }

        # Check for WSL
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            throw "WSL is required for integration tests. wsl.exe not found."
        }
    }

    Context "Get-WslDistroList" {
        It "Should return distribution list array" {
            $distros = @(Get-WslDistroList)
            $distros.GetType().IsArray | Should -Be $true
        }

        It "Should return detailed objects when -Detailed is used" {
            $distros = @(Get-WslDistroList -Detailed)
            $distros.GetType().IsArray | Should -Be $true

            if ($distros.Count -gt 0) {
                $distro = $distros[0]
                $distro | Should -BeOfType [System.Management.Automation.PSCustomObject]

                # Check properties
                $distro.Name | Should -Not -BeNullOrEmpty
                $distro.State | Should -BeIn "Running", "Stopped"
                $distro.Version | Should -BeIn 1, 2
                $distro.IsDefault | Should -BeOfType [bool]

                # Verify consistency with non-detailed
                $simpleDistros = @(Get-WslDistroList)
                $simpleDistros | Should -Contain $distro.Name
            }
        }
    }

    Context "Get-WslDistroState" {
        It "Should return valid state for existing distributions" {
            $distros = @(Get-WslDistroList -Detailed)

            foreach ($d in $distros) {
                $state = Get-WslDistroState -DistroName $d.Name
                $state | Should -Be $d.State
            }
        }
    }

    Context "Test-Wsl2Version" {
        It "Should return boolean for existing distributions" {
             $distros = @(Get-WslDistroList -Detailed)

             foreach ($d in $distros) {
                 $isWsl2 = Test-Wsl2Version -DistroName $d.Name
                 $expected = ($d.Version -eq 2)
                 $isWsl2 | Should -Be $expected
             }
        }
    }

    AfterAll {
        Stop-SutIsolation
    }
}
