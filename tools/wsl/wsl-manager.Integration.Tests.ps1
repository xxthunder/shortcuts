#Requires -Version 5.1

<#
.SYNOPSIS
    Integration tests for wsl-manager.ps1 that run against real WSL.

.DESCRIPTION
    These tests actually execute WSL commands and verify the complete workflow.
    They require WSL to be installed and will create/remove test distributions.

    WARNING: These tests will create and remove WSL distributions.
    Test distribution: Ubuntu-24.04

.NOTES
    Run these tests manually or in a dedicated test environment.
    They are not included in the main test suite by default.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import Pester
Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

Describe "WSL Manager Integration Tests" -Tag "Integration" {
    BeforeAll {
        $script:testDistroName = "Ubuntu-24.04"
        $script:wslManagerPath = Join-Path $PSScriptRoot "wsl-manager.ps1"
        $script:outputCapture = @()

        # Verify WSL is installed
        if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
            Write-Warning "WSL is not installed. Skipping integration tests."
            Set-ItResult -Skipped -Because "WSL is not installed"
            return
        }

        Write-Host "==> Cleaning up: Removing $script:testDistroName if it exists..." -ForegroundColor Cyan
        # Clean up: Remove test distro if it exists
        $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
        if ($script:testDistroName -in $existingDistros) {
            Write-Host "    Removing existing $script:testDistroName..." -ForegroundColor Yellow
            wsl --unregister $script:testDistroName 2>&1 | Out-Null
            Start-Sleep -Seconds 2
        }
    }

    AfterAll {
        # Cleanup: Remove test distro after tests
        Write-Host "==> Cleaning up: Removing $script:testDistroName after tests..." -ForegroundColor Cyan
        $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
        if ($script:testDistroName -in $existingDistros) {
            wsl --unregister $script:testDistroName 2>&1 | Out-Null
        }
    }

    Context "Create Distribution" {
        It "Should create Ubuntu-24.04 and print executed commands" {
            Write-Host "`n==> TEST: Creating $script:testDistroName..." -ForegroundColor Magenta

            # Capture output
            $output = & $script:wslManagerPath create $script:testDistroName 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify distribution was created
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:testDistroName

            # Verify commands were printed
            $output | Should -Match "Executing:.*wsl --install"
            $output | Should -Match "Successfully created '$script:testDistroName'"
        }
    }

    Context "Update Distribution" {
        It "Should update Ubuntu-24.04 and print executed commands" {
            Write-Host "`n==> TEST: Updating $script:testDistroName..." -ForegroundColor Magenta

            # First verify the distribution exists
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:testDistroName

            # Note: We can't actually run update non-interactively easily, so we'll test the library function directly
            # Load the library
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Capture output from Update-WslDistro
            $output = Update-WslDistro -Name $script:testDistroName -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify commands were printed
            $output | Should -Match "Updating WSL distribution '$script:testDistroName'"
            $output | Should -Match "Executing:.*wsl -d $script:testDistroName"
            $output | Should -Match "sudo apt update"
            $output | Should -Match "Successfully updated '$script:testDistroName'"
        }
    }

    Context "List Distributions" {
        It "Should list distributions and show Ubuntu-24.04" {
            Write-Host "`n==> TEST: Listing distributions..." -ForegroundColor Magenta

            $output = & $script:wslManagerPath list 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            $output | Should -Match $script:testDistroName
        }
    }

    Context "Remove Distribution" {
        It "Should remove Ubuntu-24.04 and print executed commands" {
            Write-Host "`n==> TEST: Removing $script:testDistroName..." -ForegroundColor Magenta

            # Load the library to call Remove-WslDistro directly
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Capture output from Remove-WslDistro
            $output = Remove-WslDistro -Name $script:testDistroName -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify distribution was removed
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Not -Contain $script:testDistroName

            # Verify commands were printed
            $output | Should -Match "Executing:.*wsl --unregister"
        }
    }
}

# Run the tests if this script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║          WSL Manager Integration Tests                        ║
║                                                                ║
║  These tests run against REAL WSL and will:                   ║
║  - Create Ubuntu-24.04 distribution (~300-500MB download)     ║
║  - Update the distribution (apt update && upgrade)            ║
║  - Remove the distribution                                     ║
║                                                                ║
║  WARNING: This will take several minutes to complete!         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Yellow

    $confirmation = Read-Host "Do you want to proceed? [y/N]"
    if ($confirmation -notmatch '^[Yy](es)?$') {
        Write-Host "Integration tests cancelled." -ForegroundColor Yellow
        exit 0
    }

    $config = New-PesterConfiguration
    $config.Run.Path = $PSScriptRoot
    $config.Filter.Tag = 'Integration'
    $config.Output.Verbosity = 'Detailed'
    $config.Should.ErrorAction = 'Stop'

    Invoke-Pester -Configuration $config
}
