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
        . (Join-Path $PSScriptRoot "wsl.ps1")
        . (Join-Path $PSScriptRoot "..\utils\utils.ps1")

        # Check if base distro already exists
        $existingDistros = Get-WslDistroList

        if ($script:baseDistroName -in $existingDistros) {
            Write-Host "    $script:baseDistroName already exists, will use it" -ForegroundColor Green
        }
        else {
            Write-Host "    $script:baseDistroName not found, will create it during tests" -ForegroundColor Yellow
        }

        # Terminate base distro if it's running (required for update/clone operations)
        if ($script:baseDistroName -in $existingDistros) {
            $baseState = Get-WslDistroState -DistroName $script:baseDistroName
            if ($baseState -eq "Running") {
                Write-Host "    Stopping $script:baseDistroName before tests ..." -ForegroundColor Yellow
                Stop-WslDistro -Name $script:baseDistroName -Confirm:$false
            }
        }

        # Always remove custom distro before tests (clean slate)
        if ($script:customDistroName -in $existingDistros) {
            Write-Host "    Removing existing $script:customDistroName for fresh test run ..." -ForegroundColor Yellow
            # Stop it first if running
            $customState = Get-WslDistroState -DistroName $script:customDistroName
            if ($customState -eq "Running") {
                Stop-WslDistro -Name $script:customDistroName -Confirm:$false
            }
            Remove-WslDistro -Name $script:customDistroName -Confirm:$false
        }

        Write-Host "    NOTE: Test distributions will be preserved after tests for exploratory testing" -ForegroundColor Cyan
    }

    AfterAll {
        # Ensure test distributions are stopped after tests to prevent failures on next run
        Write-Host "`n==> Cleaning up test environment ..." -ForegroundColor Cyan

        $existingDistros = Get-WslDistroList

        # Stop custom distro if it's running
        if ($script:customDistroName -in $existingDistros) {
            try {
                $state = Get-WslDistroState -DistroName $script:customDistroName
                if ($state -eq "Running") {
                    Write-Host "    Stopping $script:customDistroName ..." -ForegroundColor Yellow
                    Stop-WslDistro -Name $script:customDistroName -Confirm:$false
                }
            }
            catch {
                Write-Host "    Warning: Could not stop $script:customDistroName : $_" -ForegroundColor Yellow
            }
        }

        # Stop base distro if it's running
        if ($script:baseDistroName -in $existingDistros) {
            try {
                $state = Get-WslDistroState -DistroName $script:baseDistroName
                if ($state -eq "Running") {
                    Write-Host "    Stopping $script:baseDistroName ..." -ForegroundColor Yellow
                    Stop-WslDistro -Name $script:baseDistroName -Confirm:$false
                }
            }
            catch {
                Write-Host "    Warning: Could not stop $script:baseDistroName : $_" -ForegroundColor Yellow
            }
        }

        Write-Host "    Cleanup complete. Distributions preserved for exploratory testing." -ForegroundColor Green
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
                $output = & $script:wslManagerPath create $script:baseDistroName *>&1 | Out-String
                $output = $output -replace '\x00',''

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
            $output = Update-WslDistro -Name $script:baseDistroName -Confirm:$false *>&1 | Out-String
            $output = $output -replace '\x00',''

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

            # Ensure base distribution is stopped before cloning (Copy-WslDistro requirement)
            if (Test-WslDistroRunning -DistroName $script:baseDistroName) {
                Write-Host "Stopping '$script:baseDistroName' before cloning..." -ForegroundColor Yellow
                Stop-WslDistro -Name $script:baseDistroName -Confirm:$false
            }

            # Capture output from Copy-WslDistro
            $output = Copy-WslDistro -SourceName $script:baseDistroName -TargetName $script:customDistroName -Confirm:$false *>&1 | Out-String
            $output = $output -replace '\x00',''

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
            $output = New-WslUser -DistroName $script:customDistroName -Username $testUsername -Password $testPassword -Confirm:$false *>&1 | Out-String
            $output = $output -replace '\x00',''

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify user creation output
            $output | Should -Match "User '$testUsername' does not exist in distribution '$script:customDistroName'. Creating user"
            $output | Should -Match "Successfully created user '$testUsername'"
            $output | Should -Match "Restarting distribution"

            # Verify NOPASSWD warning is displayed (Optional, output capture can be flaky)
            $output | Should -Match "NOPASSWD sudo has been configured"
            $output | Should -Match "allows running commands as root without password prompt"

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

    Context "State Validation for Operations" {
        It "Should prevent update when distribution is running" {
            Write-Host "`n==> TEST: Testing state validation for Update on running $script:customDistroName ..." -ForegroundColor Magenta

            # Start the distribution
            Invoke-WslDistroCommand -DistroName $script:customDistroName -Command "echo 'starting distro'" -PrintCommand $false -Silent $true

            # Verify it's running
            $state = Get-WslDistroState -DistroName $script:customDistroName
            Write-Host "    Current state: $state" -ForegroundColor Cyan
            $state | Should -Be "Running"

            # Try to update (should fail with error message)
            Write-Host "    Attempting update on running distribution ..." -ForegroundColor Cyan
            { Update-WslDistro -Name $script:customDistroName -Confirm:$false -ErrorAction Stop } | Should -Throw "*is running*Stop it first with*wsl --terminate*"

            Write-Host "    State validation correctly blocked update" -ForegroundColor Green
        }

        It "Should prevent clone when source distribution is running" {
            Write-Host "`n==> TEST: Testing state validation for Clone on running $script:customDistroName ..." -ForegroundColor Magenta

            # Ensure distribution is running
            Invoke-WslDistroCommand -DistroName $script:customDistroName -Command "echo 'starting distro'" -PrintCommand $false -Silent $true

            # Verify it's running
            $state = Get-WslDistroState -DistroName $script:customDistroName
            Write-Host "    Current state: $state" -ForegroundColor Cyan
            $state | Should -Be "Running"

            # Try to clone (should fail with error message)
            Write-Host "    Attempting clone of running distribution ..." -ForegroundColor Cyan
            { Copy-WslDistro -SourceName $script:customDistroName -TargetName "clone-test-temp" -Confirm:$false -ErrorAction Stop } | Should -Throw "*is running*Stop it first with*wsl --terminate*"

            Write-Host "    State validation correctly blocked clone" -ForegroundColor Green
        }

        It "Should prevent remove when distribution is running" {
            Write-Host "`n==> TEST: Testing state validation for Remove on running $script:customDistroName ..." -ForegroundColor Magenta

            # Ensure distribution is running
            Invoke-WslDistroCommand -DistroName $script:customDistroName -Command "echo 'starting distro'" -PrintCommand $false -Silent $true

            # Verify it's running
            $state = Get-WslDistroState -DistroName $script:customDistroName
            Write-Host "    Current state: $state" -ForegroundColor Cyan
            $state | Should -Be "Running"

            # Try to remove (should fail with error message)
            Write-Host "    Attempting remove of running distribution ..." -ForegroundColor Cyan
            { Remove-WslDistro -Name $script:customDistroName -Confirm:$false -ErrorAction Stop } | Should -Throw "*is running*Stop it first with*wsl --terminate*"

            Write-Host "    State validation correctly blocked remove" -ForegroundColor Green
        }

        It "Should allow operations after distribution is stopped" {
            Write-Host "`n==> TEST: Testing operations succeed after terminating $script:customDistroName ..." -ForegroundColor Magenta

            # Terminate the distribution
            Stop-WslDistro -Name $script:customDistroName -Confirm:$false

            # Verify it's stopped
            $state = Get-WslDistroState -DistroName $script:customDistroName
            Write-Host "    Current state: $state" -ForegroundColor Cyan
            $state | Should -Be "Stopped"

            # Update should succeed now
            Write-Host "    Attempting update on stopped distribution ..." -ForegroundColor Cyan
            { Update-WslDistro -Name $script:customDistroName -Confirm:$false -ErrorAction Stop } | Should -Not -Throw

            Write-Host "    Update succeeded after termination" -ForegroundColor Green
        }
    }

    Context "Terminate Distribution" {
        It "Should terminate a running distribution and show state changes" {
            Write-Host "`n==> TEST: Testing terminate functionality on $script:customDistroName ..." -ForegroundColor Magenta

            # First ensure the custom distribution exists
            $existingDistros = Get-WslDistroList
            $existingDistros | Should -Contain $script:customDistroName

            # Get initial state
            $initialState = Get-WslDistroState -DistroName $script:customDistroName
            Write-Host "    Initial state: $initialState" -ForegroundColor Cyan

            # Start the distribution by running a simple command (ensures it's running)
            Write-Host "    Starting distribution ..." -ForegroundColor Cyan
            Invoke-WslDistroCommand -DistroName $script:customDistroName -Command "echo 'starting distro'" -PrintCommand $false -Silent $true

            # Verify it's running
            $runningState = Get-WslDistroState -DistroName $script:customDistroName
            Write-Host "    State after starting: $runningState" -ForegroundColor Cyan
            $runningState | Should -Be "Running"

            # Test the terminate command via wsl-manager
            Write-Host "    Terminating distribution ..." -ForegroundColor Cyan
            $output = & $script:wslManagerPath terminate $script:customDistroName *>&1 | Out-String
            $output = $output -replace '\x00',''

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify the output contains success message (Standard WSL or Wrapper output)
            $output | Should -Match "successfully"

            # Verify the distribution is now stopped
            $finalState = Get-WslDistroState -DistroName $script:customDistroName
            Write-Host "    Final state: $finalState" -ForegroundColor Cyan
            $finalState | Should -Be "Stopped"
        }

        It "Should handle terminating an already stopped distribution gracefully" {
            Write-Host "`n==> TEST: Testing terminate on already stopped $script:customDistroName ..." -ForegroundColor Magenta

            # Ensure distribution is stopped (from previous test)
            $initialState = Get-WslDistroState -DistroName $script:customDistroName
            Write-Host "    Initial state: $initialState" -ForegroundColor Cyan

            # Try to terminate (should succeed with informational message)
            $output = & $script:wslManagerPath terminate $script:customDistroName *>&1 | Out-String
            $output = $output -replace '\x00',''

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            # Verify the output contains "No running" message (from Invoke-TerminateDistro when no distros are running)
            $output | Should -Match "No running"

            # Verify the distribution is still stopped (not an error)
            $finalState = Get-WslDistroState -DistroName $script:customDistroName
            $finalState | Should -Be "Stopped"
        }
    }
}
