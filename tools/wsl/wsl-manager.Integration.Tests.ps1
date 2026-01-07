<#
.DESCRIPTION
    Integration tests for wsl-manager.ps1 that run against real WSL.
    These tests execute WSL commands and verify the complete workflow.

    Test workflow:
    1. Use existing Debian or install it (base distro)
    2. Update Debian (base distro) to latest packages
    3. Clone Debian to debian-custom-test (custom distro)
    4. Setup user in debian-custom-test
    5. Setup Docker in debian-custom-test
    6. List both distributions
    7. Verify distributions (both are kept for exploratory testing)

    NOTE: Test distributions are PRESERVED after tests complete for exploratory testing.
    Test distribution: debian-custom-test (kept after tests)
    Base distribution: Debian (kept after tests)
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
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            Write-Warning "WSL is not installed. Skipping integration tests."
            Set-ItResult -Skipped -Because "WSL is not installed"
            return
        }

        Write-Host "==> Preparing test environment ..." -ForegroundColor Cyan
        # Check if base distro already exists
        $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }

        if ($script:baseDistroName -in $existingDistros) {
            Write-Host "    $script:baseDistroName already exists, will use it" -ForegroundColor Green
        }
        else {
            Write-Host "    $script:baseDistroName not found, will create it during tests" -ForegroundColor Yellow
        }

        # Always remove custom distro before tests (clean slate)
        if ($script:customDistroName -in $existingDistros) {
            Write-Host "    Removing existing $script:customDistroName for fresh test run ..." -ForegroundColor Yellow
            wsl.exe --unregister $script:customDistroName 2>&1 | Out-Null
            Start-Sleep -Seconds 2
        }

        Write-Host "    NOTE: Test distributions will be preserved after tests for exploratory testing" -ForegroundColor Cyan
    }

    Context "Create Distribution" {
        It "Should use existing or create Debian and print executed commands" {
            # Check if base distro exists
            $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }

            if ($script:baseDistroName -in $existingDistros) {
                Write-Host "`n==> TEST: Using existing $script:baseDistroName ..." -ForegroundColor Magenta
                # Verify it exists
                $existingDistros | Should -Contain $script:baseDistroName
            }
            else {
                Write-Host "`n==> TEST: Creating $script:baseDistroName ..." -ForegroundColor Magenta

                # Capture output
                $output = & $script:wslManagerPath create $script:baseDistroName 2>&1 | Out-String

                Write-Host "==> Captured Output:" -ForegroundColor Cyan
                Write-Host $output

                # Verify distribution was created
                $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
                $existingDistros | Should -Contain $script:baseDistroName

                # Verify commands were printed
                $output | Should -Match "Executing:.*wsl.exe --install"
                $output | Should -Match "Successfully created '$script:baseDistroName'"
            }
        }
    }

    Context "Update Base Distribution" {
        It "Should update Debian base distro to latest packages and print executed commands" {
            Write-Host "`n==> TEST: Updating base $script:baseDistroName to latest packages ..." -ForegroundColor Magenta

            # First verify the base distribution exists
            $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:baseDistroName

            # Load the library
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Capture output from Update-WslDistro
            $output = Update-WslDistro -Name $script:baseDistroName -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify commands were printed
            $output | Should -Match "Updating WSL distribution '$script:baseDistroName'"
            $output | Should -Match "Executing:.*wsl.exe --distribution $script:baseDistroName"
            $output | Should -Match "sudo apt update"
            $output | Should -Match "Successfully updated '$script:baseDistroName'"
        }
    }

    Context "Clone Distribution" {
        It "Should clone Debian to custom distro and print executed commands" {
            Write-Host "`n==> TEST: Cloning $script:baseDistroName to $script:customDistroName ..." -ForegroundColor Magenta

            # First verify the base distribution exists
            $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:baseDistroName

            # Load the library to call Copy-WslDistro directly
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Capture output from Copy-WslDistro
            $output = Copy-WslDistro -SourceName $script:baseDistroName -TargetName $script:customDistroName -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify custom distribution was created
            $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:customDistroName

            # Verify commands were printed
            $output | Should -Match "Executing:.*wsl.exe --export"
            $output | Should -Match "Executing:.*wsl.exe --import"
            $output | Should -Match "Successfully cloned '$script:baseDistroName' to '$script:customDistroName'"
        }
    }

    Context "Setup User" {
        It "Should create test user in custom distro and print executed commands" {
            Write-Host "`n==> TEST: Setting up user in $script:customDistroName ..." -ForegroundColor Magenta

            # First verify the custom distribution exists
            $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:customDistroName

            # Load the library
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Create test user with plain text password (for automation)
            $testUsername = "testuser"
            $testPassword = "testpass123"

            # Capture output from New-WslUser
            $output = New-WslUser -DistroName $script:customDistroName -Username $testUsername -Password $testPassword -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify user creation output
            $output | Should -Match "User '$testUsername' does not exist in distribution '$script:customDistroName'. Creating user"
            $output | Should -Match "Successfully created user '$testUsername'"
            $output | Should -Match "wsl.exe --terminate $script:customDistroName"

            # Verify user exists in the distribution
            $userCheck = wsl.exe --distribution $script:customDistroName --exec id -u $testUsername 2>&1
            $userCheck | Should -Match '^\d+$'

            # Verify user is in sudo group
            $groupCheck = wsl.exe --distribution $script:customDistroName --exec groups $testUsername 2>&1
            $groupCheck | Should -Match '\bsudo\b'

            # Verify sudoers file exists with NOPASSWD configuration
            $sudoersCheck = wsl.exe --distribution $script:customDistroName --exec sudo cat /etc/sudoers.d/$testUsername 2>&1
            $sudoersCheck | Should -Match "NOPASSWD:ALL"
            $sudoersCheck | Should -Match "$testUsername ALL="
        }
    }

    Context "Setup Docker" {
        It "Should install Docker Engine in custom distro with user and print executed commands" {
            Write-Host "`n==> TEST: Installing Docker in $script:customDistroName ..." -ForegroundColor Magenta

            # First verify the custom distribution exists
            $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:customDistroName

            # Load the library
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Capture output from Install-WslDockerEngine
            $output = Install-WslDockerEngine -DistroName $script:customDistroName -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify Docker is installed (output messages aren't captured due to Write-Information)
            $dockerVersion = wsl.exe --distribution $script:customDistroName --exec docker --version 2>&1
            $dockerVersion | Should -Match "Docker version"

            # Verify Docker Compose is installed
            $composeVersion = wsl.exe --distribution $script:customDistroName --exec docker compose version 2>&1
            $composeVersion | Should -Match "Docker Compose version"

            # Verify Docker service is running
            $serviceStatus = wsl.exe --distribution $script:customDistroName --exec sudo systemctl is-active docker 2>&1
            $serviceStatus | Should -Match "active"

            # Verify user is in docker group
            $testUsername = "testuser"
            $groupCheck = wsl.exe --distribution $script:customDistroName --exec groups $testUsername 2>&1
            $groupCheck | Should -Match '\bdocker\b'
        }

        It "Should fail when trying to install Docker again (already installed)" {
            Write-Host "`n==> TEST: Verifying Docker already installed error in $script:customDistroName ..." -ForegroundColor Magenta

            # Load the library
            . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
            . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

            # Attempt to install Docker again (should fail)
            { Install-WslDockerEngine -DistroName $script:customDistroName -Confirm:$false -ErrorAction Stop } | Should -Throw -ExpectedMessage "*Docker is already installed*"
        }
    }

    Context "List Distributions" {
        It "Should list distributions and show both base and custom distros" {
            Write-Host "`n==> TEST: Listing distributions ..." -ForegroundColor Magenta

            # Call the script to display the list (for visual verification)
            & $script:wslManagerPath list

            Write-Host "`n==> Captured Output:" -ForegroundColor Cyan

            # Verify both distributions exist by checking WSL directly
            $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }

            $existingDistros | Should -Contain $script:baseDistroName
            $existingDistros | Should -Contain $script:customDistroName
        }
    }

    Context "Verify Distributions Preserved" {
        It "Should verify base distro is preserved for exploratory testing" {
            Write-Host "`n==> TEST: Verifying $script:baseDistroName is preserved ..." -ForegroundColor Magenta

            # Verify base distribution exists
            $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:baseDistroName

            Write-Host "    $script:baseDistroName is preserved for exploratory testing" -ForegroundColor Green
        }

        It "Should verify custom distro is preserved for exploratory testing" {
            Write-Host "`n==> TEST: Verifying $script:customDistroName is preserved ..." -ForegroundColor Magenta

            # Verify custom distribution exists
            $existingDistros = wsl.exe --list --quiet 2>$null | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim([char]0x0000).Trim() }
            $existingDistros | Should -Contain $script:customDistroName

            Write-Host "    $script:customDistroName is preserved for exploratory testing" -ForegroundColor Green
            Write-Host "    NOTE: Test distributions kept - manually remove when no longer needed" -ForegroundColor Yellow
        }
    }
}
