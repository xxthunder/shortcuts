<#
.DESCRIPTION
    Integration tests for wsl-manager.ps1 that run against real WSL.
    These tests execute WSL commands and verify the complete workflow.

    Test workflow:
    1. Use existing Debian or install it (base distro)
    2. Clone Debian to TestCustomDistro (custom distro)
    3. Update TestCustomDistro
    4. List both distributions
    5. Remove only TestCustomDistro (and leave Debian untouched)

    WARNING: These tests will create and remove WSL distributions.
    Test distributions: TestCustomDistro
    Base distribution (always preserved): Debian
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Integration tests use Write-Host for user feedback during manual test runs.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

Describe "WSL Manager Integration Tests" -Tag "Integration" {
    BeforeAll {
        $script:baseDistroName = "Debian"
        $script:customDistroName = "debian-custom-test"
        $script:wslManagerPath = Join-Path $PSScriptRoot "wsl-manager.ps1"
        $script:outputCapture = @()

        # Verify WSL is installed
        if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
            Write-Warning "WSL is not installed. Skipping integration tests."
            Set-ItResult -Skipped -Because "WSL is not installed"
            return
        }

        Write-Host "==> Preparing test environment..." -ForegroundColor Cyan
        # Check if base distro already exists
        $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }

        if ($script:baseDistroName -in $existingDistros) {
            Write-Host "    $script:baseDistroName already exists, will use it" -ForegroundColor Green
        }
        else {
            Write-Host "    $script:baseDistroName not found, will create it during tests" -ForegroundColor Yellow
        }

        # Only remove custom distro if it exists (test artifact)
        if ($script:customDistroName -in $existingDistros) {
            Write-Host "    Removing existing $script:customDistroName..." -ForegroundColor Yellow
            wsl --unregister $script:customDistroName 2>&1 | Out-Null
            Start-Sleep -Seconds 2
        }
    }

    AfterAll {
        # Cleanup: Remove only test artifacts, preserve base distro
        Write-Host "==> Cleaning up: Removing test distros after tests..." -ForegroundColor Cyan
        $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }

        # Always remove custom distro (test artifact)
        if ($script:customDistroName -in $existingDistros) {
            Write-Host "    Removing $script:customDistroName..." -ForegroundColor Yellow
            wsl --unregister $script:customDistroName 2>&1 | Out-Null
        }

        # Always preserve base distro
        if ($script:baseDistroName -in $existingDistros) {
            Write-Host "    Preserving $script:baseDistroName (base distro is never removed)" -ForegroundColor Green
        }
    }

    Context "Create Distribution" {
        It "Should use existing or create Debian and print executed commands" {
            # Check if base distro exists
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }

            if ($script:baseDistroName -in $existingDistros) {
                Write-Host "`n==> TEST: Using existing $script:baseDistroName..." -ForegroundColor Magenta
                # Verify it exists
                $existingDistros | Should -Contain $script:baseDistroName
            }
            else {
                Write-Host "`n==> TEST: Creating $script:baseDistroName..." -ForegroundColor Magenta

                # Capture output
                $output = & $script:wslManagerPath create $script:baseDistroName 2>&1 | Out-String

                Write-Host "==> Captured Output:" -ForegroundColor Cyan
                Write-Host $output

                # Verify distribution was created
                $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
                $existingDistros | Should -Contain $script:baseDistroName

                # Verify commands were printed
                $output | Should -Match "Executing:.*wsl --install"
                $output | Should -Match "Successfully created '$script:baseDistroName'"
            }
        }
    }

    Context "Clone Distribution" {
        It "Should clone Debian to custom distro and print executed commands" {
            Write-Host "`n==> TEST: Cloning $script:baseDistroName to $script:customDistroName..." -ForegroundColor Magenta

            # First verify the base distribution exists
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:baseDistroName

            # Load the library to call Copy-WslDistro directly
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Capture output from Copy-WslDistro
            $output = Copy-WslDistro -SourceName $script:baseDistroName -TargetName $script:customDistroName -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify custom distribution was created
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:customDistroName

            # Verify commands were printed
            $output | Should -Match "Executing:.*wsl --export"
            $output | Should -Match "Executing:.*wsl --import"
            $output | Should -Match "Successfully cloned '$script:baseDistroName' to '$script:customDistroName'"
        }
    }

    Context "Update Distribution" {
        It "Should update custom distro and print executed commands" {
            Write-Host "`n==> TEST: Updating $script:customDistroName..." -ForegroundColor Magenta

            # First verify the custom distribution exists
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:customDistroName

            # Load the library
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Capture output from Update-WslDistro
            $output = Update-WslDistro -Name $script:customDistroName -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify commands were printed
            $output | Should -Match "Updating WSL distribution '$script:customDistroName'"
            $output | Should -Match "Executing:.*wsl -d $script:customDistroName"
            $output | Should -Match "sudo apt update"
            $output | Should -Match "Successfully updated '$script:customDistroName'"
        }
    }

    Context "List Distributions" {
        It "Should list distributions and show both base and custom distros" {
            Write-Host "`n==> TEST: Listing distributions..." -ForegroundColor Magenta

            # Call the script to display the list (for visual verification)
            & $script:wslManagerPath list

            Write-Host "`n==> Captured Output:" -ForegroundColor Cyan

            # Verify both distributions exist by checking WSL directly
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }

            $existingDistros | Should -Contain $script:baseDistroName
            $existingDistros | Should -Contain $script:customDistroName
        }
    }

    Context "Remove Distribution" {
        It "Should remove custom distro and print executed commands" {
            Write-Host "`n==> TEST: Removing $script:customDistroName..." -ForegroundColor Magenta

            # Load the library to call Remove-WslDistro directly
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Capture output from Remove-WslDistro
            $output = Remove-WslDistro -Name $script:customDistroName -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify custom distribution was removed
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Not -Contain $script:customDistroName

            # Verify commands were printed
            $output | Should -Match "Executing:.*wsl --unregister"
        }

        It "Should preserve base distro (Debian is never removed)" {
            Write-Host "`n==> TEST: Verifying $script:baseDistroName is preserved..." -ForegroundColor Magenta

            # Verify base distribution still exists
            $existingDistros = wsl --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:baseDistroName

            Write-Host "    $script:baseDistroName is preserved (base distro is never removed)" -ForegroundColor Green
        }
    }
}
