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

        # Load the library functions
        . (Join-Path $PSScriptRoot "..\pslib\wsl.ps1")
        . (Join-Path $PSScriptRoot "..\pslib\utils.ps1")

        # Check if base distro already exists
        $existingDistros = Get-WslDistroList

        if ($script:baseDistroName -in $existingDistros) {
            Write-Host "    $script:baseDistroName already exists, will use it" -ForegroundColor Green
        }
        else {
            Write-Host "    $script:baseDistroName not found, will create it during tests" -ForegroundColor Yellow
        }

        # Always remove custom distro before tests (clean slate)
        if ($script:customDistroName -in $existingDistros) {
            Write-Host "    Removing existing $script:customDistroName for fresh test run ..." -ForegroundColor Yellow
            Remove-WslDistro -Name $script:customDistroName -Confirm:$false
        }

        Write-Host "    NOTE: Test distributions will be preserved after tests for exploratory testing" -ForegroundColor Cyan
    }

    Context "Create Distribution" {
        It "Should use existing or create Debian and print executed commands" {
            # Check if base distro exists
            $existingDistros = Get-WslDistroList

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
                $existingDistros = Get-WslDistroList
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
            $existingDistros = Get-WslDistroList
            $existingDistros | Should -Contain $script:baseDistroName

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
            $existingDistros = Get-WslDistroList
            $existingDistros | Should -Contain $script:baseDistroName

            # Capture output from Copy-WslDistro
            $output = Copy-WslDistro -SourceName $script:baseDistroName -TargetName $script:customDistroName -Confirm:$false 2>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify custom distribution was created
            $existingDistros = Get-WslDistroList
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
            $existingDistros = Get-WslDistroList
            $existingDistros | Should -Contain $script:customDistroName

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
            $output | Should -Match "Restarting distribution"

            # Verify user exists in the distribution
            $userCheck = Invoke-WslDistroCommand -DistroName $script:customDistroName -Command "id -u $testUsername" -PrintCommand $false -PassThru
            $userCheck | Should -Match '^\d+$'

            # Verify user is in sudo group
            $groupCheck = Invoke-WslDistroCommand -DistroName $script:customDistroName -Command "groups $testUsername" -PrintCommand $false -PassThru
            $groupCheck | Should -Match '\bsudo\b'

            # Verify sudoers file exists with NOPASSWD configuration
            $sudoersCheck = Invoke-WslDistroCommand -DistroName $script:customDistroName -Command "sudo cat /etc/sudoers.d/$testUsername" -PrintCommand $false -PassThru
            $sudoersCheck | Should -Match "NOPASSWD:ALL"
            $sudoersCheck | Should -Match "$testUsername ALL="

            # Try to create the same user again (should fail with proper error message)
            Write-Host "`n==> TEST: Attempting to create same user again (should fail) ..." -ForegroundColor Magenta
            { New-WslUser -DistroName $script:customDistroName -Username $testUsername -Password $testPassword -Confirm:$false -ErrorAction Stop } | Should -Throw -ExpectedMessage "*User '$testUsername' already exists in distribution '$script:customDistroName'*"

            Write-Host "    Correctly rejected duplicate user creation" -ForegroundColor Green
        }
    }

    Context "List Distributions" {
        It "Should list distributions and show both base and custom distros" {
            Write-Host "`n==> TEST: Listing distributions ..." -ForegroundColor Magenta

            # Call the script to display the list (for visual verification)
            & $script:wslManagerPath list

            Write-Host "`n==> Captured Output:" -ForegroundColor Cyan

            # Verify both distributions exist
            $existingDistros = Get-WslDistroList

            $existingDistros | Should -Contain $script:baseDistroName
            $existingDistros | Should -Contain $script:customDistroName
        }
    }
}
