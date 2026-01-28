#Requires -Version 5.1

<#
.SYNOPSIS
    Integration tests for Install-NpmPackage function in utils.ps1

.DESCRIPTION
    Integration tests that verify Install-NpmPackage function with real npm operations.
    Tests the complete workflow including clean install, update/reinstall, and command verification.

    Test package: cowsay (small, stable package ~71KB)

    REQUIREMENTS:
    - Scoop must be installed
    - Internet connection required

    WARNING: These tests perform real npm operations (install/uninstall globally)
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Integration tests use Write-Host for user feedback')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'UTF-8 without BOM is standard for cross-platform')]
param()

BeforeDiscovery {
    # Evaluate skip conditions at discovery time
    $script:skipTests = -not (Get-Command scoop -ErrorAction SilentlyContinue)
}

BeforeAll {
    # Source the utilities module
    $script:utilsPath = Join-Path $PSScriptRoot "utils.ps1"
    . $script:utilsPath

    # Test package configuration
    $script:testPackageName = "cowsay"
    $script:testCommand = "cowsay"

    # Helper function to check if npm package is installed
    function script:Test-NpmPackageInstalled {
        param([string]$PackageName)
        try {
            $null = npm list -g $PackageName --depth=0 2>&1
            return ($LASTEXITCODE -eq 0)
        }
        catch {
            return $false
        }
    }

    # Helper function to uninstall npm package
    function script:Uninstall-NpmPackage {
        param([string]$PackageName)
        try {
            if (Test-NpmPackageInstalled -PackageName $PackageName) {
                Write-Host "    Uninstalling $PackageName..." -ForegroundColor Yellow
                $null = npm uninstall -g $PackageName 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    Successfully uninstalled $PackageName" -ForegroundColor Green
                    return $true
                }
            }
            return $false
        }
        catch {
            Write-Verbose "Failed to uninstall $PackageName : $_"
            return $false
        }
    }

    # Setup: Ensure clean test state by uninstalling the test package
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        $null = Uninstall-NpmPackage -PackageName $script:testPackageName
    }
}

Describe "Install-NpmPackage" -Tag "Integration" -Skip:$script:skipTests {

    Context "When package is not installed" {

        BeforeAll {
            # Ensure package is not installed
            if (Get-Command npm -ErrorAction SilentlyContinue) {
                $null = Uninstall-NpmPackage -PackageName $script:testPackageName
            }
        }

        It "Should install package from clean state" {
            Write-Host "`n==> TEST: Clean install of $script:testPackageName" -ForegroundColor Magenta

            # Verify package is not installed
            $isInstalled = Test-NpmPackageInstalled -PackageName $script:testPackageName
            $isInstalled | Should -Be $false -Because "Package should not be installed yet"

            # Execute installation
            { Install-NpmPackage -PackageName $script:testPackageName -CheckCommand $script:testCommand } | Should -Not -Throw

            # Verify installation succeeded
            $isInstalled = Test-NpmPackageInstalled -PackageName $script:testPackageName
            $isInstalled | Should -Be $true -Because "Package should be installed after Install-NpmPackage"

            Write-Host "    [OK] Package installed successfully" -ForegroundColor Green
        }

        It "Should make command available after installation" {
            Write-Host "`n==> TEST: Command availability check" -ForegroundColor Magenta

            # Verify command is available
            $command = Get-Command $script:testCommand -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty -Because "Command should be available after installation"

            Write-Host "    [OK] Command $script:testCommand is available" -ForegroundColor Green
        }
    }

    Context "When package is already installed" {

        BeforeAll {
            # Ensure package is installed
            if (-not (Test-NpmPackageInstalled -PackageName $script:testPackageName)) {
                Install-NpmPackage -PackageName $script:testPackageName -CheckCommand $script:testCommand
            }
        }

        It "Should handle already installed package and update it" {
            Write-Host "`n==> TEST: Update already installed package" -ForegroundColor Magenta

            # Verify package is already installed
            $isInstalled = Test-NpmPackageInstalled -PackageName $script:testPackageName
            $isInstalled | Should -Be $true -Because "Package should be installed from previous test"

            # Execute update
            { Install-NpmPackage -PackageName $script:testPackageName -CheckCommand $script:testCommand } | Should -Not -Throw

            # Verify package is still installed
            $isInstalled = Test-NpmPackageInstalled -PackageName $script:testPackageName
            $isInstalled | Should -Be $true -Because "Package should still be installed after update"

            Write-Host "    [OK] Package updated successfully" -ForegroundColor Green
        }

        It "Should keep command available after update" {
            Write-Host "`n==> TEST: Command persistence check" -ForegroundColor Magenta

            # Verify command still works
            $command = Get-Command $script:testCommand -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty -Because "Command should remain available after update"

            Write-Host "    [OK] Command $script:testCommand still available" -ForegroundColor Green
        }
    }

    Context "When verifying command execution" {

        BeforeAll {
            # Ensure package is installed
            if (-not (Test-NpmPackageInstalled -PackageName $script:testPackageName)) {
                Install-NpmPackage -PackageName $script:testPackageName -CheckCommand $script:testCommand
            }
        }

        It "Should execute installed command successfully" {
            Write-Host "`n==> TEST: Command execution verification" -ForegroundColor Magenta

            # Execute command with test input
            $result = & $script:testCommand "Test" 2>&1

            # Verify command execution didn't throw
            $result | Should -Not -BeNullOrEmpty -Because "Command should produce output"

            Write-Host "    [OK] Command executed successfully" -ForegroundColor Green
        }
    }
}
