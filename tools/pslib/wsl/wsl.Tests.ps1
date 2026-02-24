<#
.DESCRIPTION
    Pester tests for wsl.ps1 - Module structure and backward compatibility
#>

BeforeAll {
    . "$PSScriptRoot\..\utils\utils.ps1"
    . "$PSScriptRoot\wsl.ps1"
}

Describe "Module Structure - Backward Compatibility" {
    Context "When wsl.ps1 is sourced" {
        It "Should export all 22 core WSL functions" {
            # Define all functions that must remain accessible after refactoring
            $expectedFunctions = @(
                'Test-WslInstalled'
                'Get-WslAvailableDistro'
                'New-WslDistro'
                'Get-WslDistroList'
                'Remove-WslDistro'
                'Copy-WslDistro'
                'Invoke-WslDistroCommand'
                'Invoke-WslDistroScript'
                'Get-WslDistroType'
                'Get-WslDistroState'
                'Test-WslDistroRunning'
                'Stop-WslDistro'
                'Update-WslDistro'
                'New-WslUser'
                'Get-WslDefaultUser'
                'Test-WslSystemdConfigured'
                'Test-WslSystemd'
                'Test-Wsl2Version'
                'Test-WslDockerInstalled'
                'Install-WslDockerEngine'
                'Assert-WslDistroExists'
                'Assert-WslDistroNotExists'
            )

            # Verify each function is accessible
            foreach ($functionName in $expectedFunctions) {
                Get-Command -Name $functionName -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$functionName must be accessible after sourcing wsl.ps1"
            }
        }

        It "Should allow wsl-manager.ps1 to source wsl.ps1 without errors" {
            # Verify that sourcing wsl.ps1 doesn't cause errors
            # This simulates what wsl-manager.ps1 does
            { . "$PSScriptRoot\wsl.ps1" } | Should -Not -Throw
        }
    }
}
