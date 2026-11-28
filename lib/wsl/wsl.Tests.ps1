<#
.DESCRIPTION
    Pester tests for wsl.ps1 - Module structure and backward compatibility
#>

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\wsl.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Module Structure - Backward Compatibility" {
    Context "When wsl.ps1 is sourced" {
        It "Should export all 23 core WSL functions" {
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
                'Test-WslPodmanInstalled'
                'Install-WslDevStack'
                'Assert-WslDistroExists'
                'Assert-WslDistroNotExists'
            )

            # Verify each function is accessible
            foreach ($functionName in $expectedFunctions) {
                Get-Command -Name $functionName -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "$functionName must be accessible after sourcing wsl.ps1"
            }
        }

        It "Should not define the removed function <Removed>" -ForEach @(
            @{ Removed = "Install-WslDockerEngine" }
            @{ Removed = "Install-WslPodman" }
            @{ Removed = "Install-WslDevPod" }
        ) {
            Get-Command -Name $Removed -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It "Should not ship the removed file <Relative>" -ForEach @(
            @{ Relative = "scripts\install-docker.sh" }
            @{ Relative = "scripts\install-podman.sh" }
            @{ Relative = "scripts\install-devpod.sh" }
            @{ Relative = "devpod.ps1" }
        ) {
            Join-Path $PSScriptRoot $Relative | Should -Not -Exist
        }

        It "Should allow wsl-manager.ps1 to source wsl.ps1 without errors" {
            # Verify that sourcing wsl.ps1 doesn't cause errors
            # This simulates what wsl-manager.ps1 does
            { . "$PSScriptRoot\wsl.ps1" } | Should -Not -Throw
        }
    }
}
