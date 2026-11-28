<#
.DESCRIPTION
    Integration tests for wsl-manager.ps1 that run against real WSL.
    They cover the commands that do not install a container stack:
    create, update, clone, setup-user, list, terminate, script execution,
    auto-terminate and the in-distro root CA (setup-ca).
    The dev-stack role is covered by manager.devstack.Integration.Tests.ps1.

    Test workflow:
    1. Use existing Debian or install it (base distro)
    2. Update Debian (base distro) to latest packages
    3. Clone Debian to debian-custom-test (custom distro)
    4. Setup user in debian-custom-test (testuser with sudo)
    5. List the distributions
    6. Auto-terminate for update, clone and remove
    7. Terminate a running and a stopped distribution
    8. Execute bash scripts in the distribution
    9. Install and remove root CA certificates

    NOTE: Test distributions are PRESERVED after tests complete for exploratory testing.
    Test distribution: debian-custom-test (kept after tests)
    Base distribution: Debian (minimal, kept after tests)
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Integration tests use Write-Host for user feedback during manual test runs.')]
param()

Describe "WSL Manager Integration Tests" -Tag "Integration" {
    BeforeAll {
        . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
        Start-SutIsolation

        $script:baseDistroName = "Debian"
        $script:customDistroName = "debian-custom-test"
        $script:outputCapture = @()

        # Verify WSL is installed
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            throw "WSL is required for integration tests. wsl.exe not found."
        }

        Write-Host "==> Preparing test environment ..." -ForegroundColor Cyan

        # Load the library functions (manager.ps1 dot-sources commands.ps1)
        . (Join-Path $PSScriptRoot "manager.ps1")

        # Check if base distro already exists
        $existingDistros = Get-WslDistroList

        if ($script:baseDistroName -in $existingDistros) {
            Write-Host "    $script:baseDistroName already exists, will use it" -ForegroundColor Green
        }
        else {
            Write-Host "    $script:baseDistroName not found, will create it during tests" -ForegroundColor Yellow
        }

        # Shutdown entire WSL subsystem to prevent systemd auto-restart race (SC-002)
        Write-Host "    Shutting down WSL subsystem before tests ..." -ForegroundColor Yellow
        Stop-WslSubsystem -Confirm:$false

        # Always remove custom distro before tests (clean slate)
        if ($script:customDistroName -in $existingDistros) {
            Write-Host "    Removing existing $script:customDistroName for fresh test run ..." -ForegroundColor Yellow
            Remove-WslDistro -Name $script:customDistroName -Confirm:$false
        }

        Write-Host "    NOTE: Test distributions will be preserved after tests for exploratory testing" -ForegroundColor Cyan
    }

    AfterAll {
        # Shutdown entire WSL subsystem after tests to prevent failures on next run (SC-002)
        Write-Host "`n==> Cleaning up test environment ..." -ForegroundColor Cyan

        try {
            Write-Host "    Shutting down WSL subsystem ..." -ForegroundColor Yellow
            Stop-WslSubsystem -Confirm:$false
        }
        catch {
            Write-Host "    Warning: Could not shut down WSL subsystem: $_" -ForegroundColor Yellow
        }

        Write-Host "    Cleanup complete. Distributions preserved for exploratory testing." -ForegroundColor Green

        Stop-SutIsolation
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
                $output = Invoke-WslManager -Command "install" -Name $script:baseDistroName *>&1 | Out-String

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

            # Shutdown WSL subsystem to prevent systemd auto-restart race (SC-002)
            Write-Host "Shutting down WSL subsystem before updating..." -ForegroundColor Yellow
            Stop-WslSubsystem -Confirm:$false

            # Capture output from Update-WslDistro
            $output = Invoke-WslManager -Command "update" -Name $script:baseDistroName *>&1 | Out-String

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

            # Shutdown WSL subsystem to prevent systemd auto-restart race (SC-002)
            Write-Host "Shutting down WSL subsystem before cloning..." -ForegroundColor Yellow
            Stop-WslSubsystem -Confirm:$false

            # Capture output from Copy-WslDistro
            $output = Invoke-WslManager -Command "clone" -Name $script:baseDistroName -TargetName $script:customDistroName *>&1 | Out-String

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
            $output = Invoke-WslManager -Command "setup-user" -Name $script:customDistroName -Username $testUsername -Password $testPassword *>&1 | Out-String

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

            # Try to create the same user again (should fail with proper error message)
            Write-Host "`n==> TEST: Attempting to create same user again (should fail) ..." -ForegroundColor Magenta
            { Invoke-WslManager -Command "setup-user" -Name $script:customDistroName -Username $testUsername -Password $testPassword } | Should -Throw -ExpectedMessage "*User '$testUsername' already exists in distribution '$script:customDistroName'*"

            Write-Host "    Correctly rejected duplicate user creation" -ForegroundColor Green
        }
    }

    Context "List Distributions" {
        It "Should list distributions and show both base and custom distros" {
            Write-Host "`n==> TEST: Listing distributions ..." -ForegroundColor Magenta

            # Call the script to display the list (for visual verification)
            Show-WslDistroTable

            Write-Host "`n==> Captured Output:" -ForegroundColor Cyan

            # Verify both distributions exist
            $existingDistros = Get-WslDistroList

            $existingDistros | Should -Contain $script:baseDistroName
            $existingDistros | Should -Contain $script:customDistroName
        }
    }

    Context "Auto-terminate for Operations" {
        It "Should auto-terminate the distribution and complete update when running" {
            Write-Host "`n==> TEST: Auto-terminate behavior for Update on running $script:customDistroName ..." -ForegroundColor Magenta

            # Start the distribution
            Invoke-WslDistroCommand -DistroName $script:customDistroName -Command "echo 'starting distro'" -PrintCommand $false -Silent $true

            # Verify it's running
            $state = Get-WslDistroState -DistroName $script:customDistroName
            Write-Host "    Current state: $state" -ForegroundColor Cyan
            $state | Should -Be "Running"

            # Update should auto-terminate then proceed (no manual termination required)
            Write-Host "    Running update on running distribution ..." -ForegroundColor Cyan
            { Invoke-WslManager -Command "update" -Name $script:customDistroName } | Should -Not -Throw

            Write-Host "    Update auto-terminated and completed without user intervention" -ForegroundColor Green
        }

        It "Should auto-terminate the source distribution and complete clone when running" {
            $cloneTarget = "auto-term-clone-target"
            Write-Host "`n==> TEST: Auto-terminate behavior for Clone with running source $script:customDistroName ..." -ForegroundColor Magenta

            try {
                # Start the source distribution
                Invoke-WslDistroCommand -DistroName $script:customDistroName -Command "echo 'starting distro'" -PrintCommand $false -Silent $true
                $state = Get-WslDistroState -DistroName $script:customDistroName
                Write-Host "    Source state: $state" -ForegroundColor Cyan
                $state | Should -Be "Running"

                # Clone should auto-terminate the source then proceed
                Write-Host "    Running clone with running source ..." -ForegroundColor Cyan
                { Invoke-WslManager -Command "clone" -Name $script:customDistroName -TargetName $cloneTarget } | Should -Not -Throw

                # Verify the clone exists
                $existingDistros = Get-WslDistroList
                $existingDistros | Should -Contain $cloneTarget

                Write-Host "    Clone auto-terminated source and completed without user intervention" -ForegroundColor Green
            }
            finally {
                # Cleanup the temporary clone
                $cleanupDistros = Get-WslDistroList
                if ($cloneTarget -in $cleanupDistros) {
                    Write-Host "    Cleaning up temporary clone $cloneTarget ..." -ForegroundColor Yellow
                    Remove-WslDistro -Name $cloneTarget -Confirm:$false
                }
            }
        }

        It "Should auto-terminate the distribution and complete remove when running" {
            $removeTarget = "auto-term-remove-target"
            Write-Host "`n==> TEST: Auto-terminate behavior for Remove on running $removeTarget ..." -ForegroundColor Magenta

            try {
                # Create a disposable target via clone (the source is whatever state it's in)
                Write-Host "    Setting up disposable target via clone ..." -ForegroundColor Cyan
                Copy-WslDistro -SourceName $script:customDistroName -TargetName $removeTarget -Confirm:$false

                # Start the disposable target so we can prove auto-terminate happens
                Invoke-WslDistroCommand -DistroName $removeTarget -Command "echo 'starting distro'" -PrintCommand $false -Silent $true
                $state = Get-WslDistroState -DistroName $removeTarget
                Write-Host "    Target state: $state" -ForegroundColor Cyan
                $state | Should -Be "Running"

                # Remove should auto-terminate then unregister
                Write-Host "    Running remove on running distribution ..." -ForegroundColor Cyan
                { Invoke-WslManager -Command "remove" -Name $removeTarget } | Should -Not -Throw

                # Verify the distribution is gone
                $existingDistros = Get-WslDistroList
                $existingDistros | Should -Not -Contain $removeTarget

                Write-Host "    Remove auto-terminated and unregistered without user intervention" -ForegroundColor Green
            }
            finally {
                # Defensive cleanup if remove failed
                $cleanupDistros = Get-WslDistroList
                if ($removeTarget -in $cleanupDistros) {
                    Write-Host "    Defensive cleanup of $removeTarget ..." -ForegroundColor Yellow
                    Remove-WslDistro -Name $removeTarget -Confirm:$false
                }
            }
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
            $output = Invoke-WslManager -Command "terminate" -Name $script:customDistroName *>&1 | Out-String

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

            # Try to terminate (should not throw)
            { Invoke-WslManager -Command "terminate" -Name $script:customDistroName } | Should -Not -Throw

            # Verify the distribution is still stopped (graceful no-op, not an error)
            $finalState = Get-WslDistroState -DistroName $script:customDistroName
            $finalState | Should -Be "Stopped"
        }
    }

    Context "Script Execution" {
        It "Should execute bash script using Invoke-WslDistroScript" {
            Write-Host "`n==> TEST: Executing bash script in $script:customDistroName ..." -ForegroundColor Magenta

            # Create a temporary test script with Unix line endings
            $testScriptContent = "#!/bin/bash`necho `"Script executed successfully`"`necho `"Argument 1: `$1`"`necho `"Argument 2: `$2`"`nexit 42"
            $testScriptPath = Join-Path $env:TEMP "wsl-test-script-$([guid]::NewGuid().ToString().Substring(0,8)).sh"
            # Write with LF line endings only (Unix format, no BOM)
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($testScriptPath, $testScriptContent, $utf8NoBom)

            try {
                # Execute the script
                Write-Host "    Executing script: $testScriptPath" -ForegroundColor Cyan
                $exitCode = Invoke-WslDistroScript -ScriptPath $testScriptPath `
                    -DistroName $script:customDistroName `
                    -Arguments @("arg1", "arg2") `
                    -StopAtError $false `
                    -PrintCommand $false

                Write-Host "    Exit code: $exitCode" -ForegroundColor Cyan

                # Verify exit code is returned correctly
                $exitCode | Should -Be 42

                Write-Host "    Script execution test passed" -ForegroundColor Green
            }
            finally {
                # Cleanup
                if (Test-Path $testScriptPath) {
                    Remove-Item $testScriptPath -Force
                }
            }
        }

        It "Should execute bash script as non-root user (scripts handle sudo internally)" {
            Write-Host "`n==> TEST: Executing bash script as non-root in $script:customDistroName ..." -ForegroundColor Magenta

            # Create a test script that checks if running as non-root with Unix line endings
            $testScriptContent = "#!/bin/bash`nif [ `"`$(id -u)`" -ne 0 ]; then`n    echo `"Running as non-root user`"`n    exit 0`nelse`n    echo `"Running as root (unexpected)`"`n    exit 1`nfi"
            $testScriptPath = Join-Path $env:TEMP "wsl-test-nonroot-$([guid]::NewGuid().ToString().Substring(0,8)).sh"
            # Write with LF line endings only (Unix format, no BOM)
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($testScriptPath, $testScriptContent, $utf8NoBom)

            try {
                Write-Host "    Executing script (should run as non-root)" -ForegroundColor Cyan
                $exitCode = Invoke-WslDistroScript -ScriptPath $testScriptPath `
                    -DistroName $script:customDistroName `
                    -StopAtError $false `
                    -PrintCommand $false

                Write-Host "    Exit code: $exitCode" -ForegroundColor Cyan

                # Should exit 0 (running as non-root)
                $exitCode | Should -Be 0

                Write-Host "    Non-root execution test passed" -ForegroundColor Green
            }
            finally {
                # Cleanup
                if (Test-Path $testScriptPath) {
                    Remove-Item $testScriptPath -Force
                }
            }
        }
    }

    Context "Root CA Setup" {
        BeforeAll {
            . "$PSScriptRoot\..\..\test\bin\lib\TestCertificate.ps1"

            $script:caDir = "/usr/local/share/ca-certificates"
            $script:caA = Get-TestRootCertificate -Subject "CN=wsl-manager integration root A"
            $script:caB = Get-TestRootCertificate -Subject "CN=wsl-manager integration root B"
            $script:caExpired = Get-TestRootCertificate -Subject "CN=wsl-manager integration root expired" -NotAfter (Get-Date).AddDays(-1)

            function Get-CaDirListing {
                $listing = Invoke-WslDistroCommand -DistroName $script:customDistroName `
                    -Command "ls -l --time-style=+%s.%N $script:caDir" -PrintCommand $false -PassThru
                return (@($listing) -join "`n")
            }

            function Test-CaBundleEntry {
                param($Certificate)
                $bundle = Invoke-WslDistroCommand -DistroName $script:customDistroName `
                    -Command "cat /etc/ssl/certs/ca-certificates.crt" -PrintCommand $false -PassThru
                # The bundle concatenates PEM files; without whitespace a certificate's base64 body is contiguous
                return ((@($bundle) -join '') -replace '\s', '').Contains([Convert]::ToBase64String($Certificate.RawData))
            }
        }

        It "Should install a root certificate into the system trust store" {
            Write-Host "`n==> TEST: Installing a root CA into $script:customDistroName ..." -ForegroundColor Magenta

            Install-WslCaCertificate -DistroName $script:customDistroName -Certificate $script:caA -Confirm:$false

            Get-CaDirListing | Should -Match "wsl-manager-$($script:caA.Thumbprint)\.crt"
            Test-CaBundleEntry -Certificate $script:caA | Should -BeTrue
        }

        It "Should leave the files unchanged when run again with the same certificate" {
            Write-Host "`n==> TEST: Repeating the root CA install (idempotency) ..." -ForegroundColor Magenta

            $before = Get-CaDirListing
            Install-WslCaCertificate -DistroName $script:customDistroName -Certificate $script:caA -Confirm:$false

            Get-CaDirListing | Should -Be $before
        }

        It "Should add a certificate and keep the managed ones already there" {
            Write-Host "`n==> TEST: Adding root CA B next to A ..." -ForegroundColor Magenta

            Install-WslCaCertificate -DistroName $script:customDistroName -Certificate $script:caB -Confirm:$false

            $listing = Get-CaDirListing
            $listing | Should -Match "wsl-manager-$($script:caA.Thumbprint)\.crt"
            $listing | Should -Match "wsl-manager-$($script:caB.Thumbprint)\.crt"
            Test-CaBundleEntry -Certificate $script:caA | Should -BeTrue
            Test-CaBundleEntry -Certificate $script:caB | Should -BeTrue
        }

        It "Should remove an expired managed certificate on the next run" {
            Write-Host "`n==> TEST: Removing an expired root CA on the next run ..." -ForegroundColor Magenta

            Install-WslCaCertificate -DistroName $script:customDistroName -Certificate $script:caExpired -Confirm:$false
            Get-CaDirListing | Should -Match "wsl-manager-$($script:caExpired.Thumbprint)\.crt"

            Install-WslCaCertificate -DistroName $script:customDistroName -Certificate $script:caB -Confirm:$false

            $listing = Get-CaDirListing
            $listing | Should -Not -Match "wsl-manager-$($script:caExpired.Thumbprint)\.crt"
            $listing | Should -Match "wsl-manager-$($script:caA.Thumbprint)\.crt"
            $listing | Should -Match "wsl-manager-$($script:caB.Thumbprint)\.crt"
        }

        It "Should remove only the certificates wsl-manager installed" {
            Write-Host "`n==> TEST: Removing the managed root CAs, keeping a foreign one ..." -ForegroundColor Magenta

            Invoke-WslDistroCommand -DistroName $script:customDistroName `
                -Command "sudo cp $script:caDir/wsl-manager-$($script:caB.Thumbprint).crt $script:caDir/foreign-test.crt" -PrintCommand $false
            try {
                Remove-WslCaCertificate -DistroName $script:customDistroName -Confirm:$false

                $listing = Get-CaDirListing
                $listing | Should -Not -Match "wsl-manager-"
                $listing | Should -Match "foreign-test\.crt"
            }
            finally {
                Invoke-WslDistroCommand -DistroName $script:customDistroName `
                    -Command "sudo rm -f $script:caDir/foreign-test.crt && sudo /usr/sbin/update-ca-certificates" -PrintCommand $false -StopAtError $false
            }
        }
    }

}
