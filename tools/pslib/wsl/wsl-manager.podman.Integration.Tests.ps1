<#
.DESCRIPTION
    Integration tests for Podman setup in wsl-manager.ps1 that run against real WSL.
    These tests execute WSL commands and verify the complete Podman workflow.

    Test workflow:
    1. Use existing Ubuntu as base distro
    2. Clone Ubuntu to ubuntu-podman-test
    3. Setup user in ubuntu-podman-test (testuser with sudo)
    4. Install Podman (rootless, includes systemd/interop/mount --make-rshared)
    5. Verify Podman installation and idempotency
    6. Verify systemd is configured and running
    7. Verify mount --make-rshared boot command
    8. Verify Docker is NOT installed (mutual exclusion)
    9. Verify DOCKER_HOST is set in .bashrc
    10. Verify XDG_RUNTIME_DIR and DBUS_SESSION_BUS_ADDRESS in .bashrc
    11. Verify loginctl enable-linger is set for testuser

    RESULT: After running this test, ubuntu-podman-test is a FULLY PREPARED distribution with:
    [OK] User account, [OK] Systemd, [OK] Windows interop, [OK] Rootless Podman

    NOTE: Test distributions are PRESERVED after tests complete for exploratory testing.
    Test distribution: ubuntu-podman-test (fully prepared, kept after tests)
    Base distribution: Ubuntu (minimal, kept after tests)
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Integration tests use Write-Host for user feedback during manual test runs.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

Describe "WSL Manager Podman Integration Tests" -Tag "Integration" {
    BeforeAll {
        $script:baseDistroName = "Ubuntu"
        $script:podmanTestDistroName = "ubuntu-podman-test"

        # Verify WSL is installed
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            Write-Warning "WSL is not installed. Skipping integration tests."
            Set-ItResult -Skipped -Because "WSL is not installed"
            return
        }

        Write-Host "==> Preparing Podman test environment ..." -ForegroundColor Cyan

        # Load the library functions
        . (Join-Path $PSScriptRoot "wsl.ps1")
        . (Join-Path $PSScriptRoot "..\utils\utils.ps1")
        . (Join-Path $PSScriptRoot "wsl-manager.ps1")

        # Verify base distro exists
        $baseExists = Get-WslDistroList | Where-Object { $_ -eq $script:baseDistroName }
        if (-not $baseExists) {
            Write-Warning "$($script:baseDistroName) base distro not found. Skipping Podman integration tests."
            Set-ItResult -Skipped -Because "$($script:baseDistroName) is not installed"
            return
        }

        # Clean slate: remove test distro if it exists
        $testExists = Get-WslDistroList | Where-Object { $_ -eq $script:podmanTestDistroName }
        if ($testExists) {
            Write-Host "    Removing existing $($script:podmanTestDistroName) ..." -ForegroundColor Yellow
            Remove-WslDistro -Name $script:podmanTestDistroName -Confirm:$false
        }

        # Clone Ubuntu to test distro
        Write-Host "    Cloning $($script:baseDistroName) -> $($script:podmanTestDistroName) ..." -ForegroundColor Cyan
        Copy-WslDistro -SourceName $script:baseDistroName -TargetName $script:podmanTestDistroName -Confirm:$false

        # Setup user
        Write-Host "    Setting up testuser in $($script:podmanTestDistroName) ..." -ForegroundColor Cyan
        Invoke-WslManager -Command "setup-user" -Name $script:podmanTestDistroName -Username "testuser" -Password "testpass123"

        # Restart to apply user changes
        Stop-WslDistro -Name $script:podmanTestDistroName -Confirm:$false
        Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName -Command "echo 'restarted'" -PrintCommand $false -Silent $true

        Write-Host "    Podman test environment ready" -ForegroundColor Green
    }

    AfterAll {
        # Stop test distro if running (preserve for exploration)
        $testExists = Get-WslDistroList | Where-Object { $_ -eq $script:podmanTestDistroName }
        if ($testExists) {
            Write-Host "==> Stopping $($script:podmanTestDistroName) (preserved for exploration) ..." -ForegroundColor Cyan
            Stop-WslDistro -Name $script:podmanTestDistroName -Confirm:$false
        }

        # Stop base distro if running
        $baseRunning = Get-WslDistroList -Detailed | Where-Object { $_.Name -eq $script:baseDistroName -and $_.State -eq "Running" }
        if ($baseRunning) {
            Write-Host "==> Stopping $($script:baseDistroName) ..." -ForegroundColor Cyan
            Stop-WslDistro -Name $script:baseDistroName -Confirm:$false
        }
    }

    Context "Podman Setup" {
        It "Should install Podman and verify idempotency" {
            Write-Host "`n==> TEST: Setting up Podman (demonstrating idempotency)..." -ForegroundColor Magenta

            # First run: Install
            Write-Host "    First run: Installing Podman..." -ForegroundColor Cyan
            Write-Host "    This may take several minutes..." -ForegroundColor Yellow
            $result1 = Install-WslPodman -DistroName $script:podmanTestDistroName -Confirm:$false
            $result1 | Should -Be $true

            # Verify Podman installed
            $podmanInstalled = Test-WslPodmanInstalled -DistroName $script:podmanTestDistroName
            $podmanInstalled | Should -Be $true

            # Verify Podman version
            $podmanVersion = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command "podman --version" -PrintCommand $false -PassThru
            Write-Host "    Podman version: $podmanVersion" -ForegroundColor Cyan
            $podmanVersion | Should -Match "podman version"

            # Second run: Demonstrate idempotency (no error)
            Write-Host "    Second run: Demonstrating idempotency..." -ForegroundColor Cyan
            $result2 = Install-WslPodman -DistroName $script:podmanTestDistroName -Confirm:$false
            $result2 | Should -Be $true

            # Restart distribution to apply configuration
            Write-Host "    Restarting distribution for configuration changes..." -ForegroundColor Cyan
            Stop-WslDistro -Name $script:podmanTestDistroName -Confirm:$false

            # Start it again
            Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName -Command "echo 'restarted'" -PrintCommand $false -Silent $true

            # Verify Podman socket exists
            $socketCheck = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command 'test -S /run/user/$(id -u testuser)/podman/podman.sock && echo "exists" || echo "not-found"' `
                -PrintCommand $false -PassThru -StopAtError $false
            Write-Host "    Podman socket: $socketCheck" -ForegroundColor Cyan
            $socketCheck.Trim() | Should -Be "exists"

            # Verify podman info succeeds as testuser
            $podmanInfo = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command "sudo -u testuser podman info --format '{{.Host.OS}}'" -PrintCommand $false -PassThru -StopAtError $false
            Write-Host "    Podman info OS: $podmanInfo" -ForegroundColor Cyan
            $podmanInfo | Should -Match "linux"

            Write-Host "    Idempotent Podman setup verification complete" -ForegroundColor Green
        }

        It "Should verify systemd is configured and running" {
            Write-Host "`n==> TEST: Verifying systemd configuration in $($script:podmanTestDistroName) ..." -ForegroundColor Magenta

            # Verify systemd is configured in wsl.conf
            $wslConfContent = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command "cat /etc/wsl.conf" -PrintCommand $false -PassThru
            Write-Host "    wsl.conf contents:" -ForegroundColor Cyan
            Write-Host $wslConfContent

            # Check for [boot] section with systemd=true
            $wslConfContent | Should -Match '\[boot\]'
            $wslConfContent | Should -Match 'systemd\s*=\s*true'

            # Verify systemd is actually running
            $systemdStatus = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command "systemctl --version" -PrintCommand $false -PassThru -StopAtError $false
            Write-Host "    systemctl version: $($systemdStatus -split "`n" | Select-Object -First 1)" -ForegroundColor Cyan
            $systemdStatus | Should -Match "systemd \d+"

            # Verify systemd is PID 1
            $initProcess = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command "ps -p 1 -o comm=" -PrintCommand $false -PassThru
            Write-Host "    Init process (PID 1): $initProcess" -ForegroundColor Cyan
            $initProcess.Trim() | Should -Be "systemd"

            Write-Host "    Systemd verification complete" -ForegroundColor Green
        }

        It "Should verify mount --make-rshared is configured in boot command" {
            Write-Host "`n==> TEST: Verifying mount --make-rshared boot command ..." -ForegroundColor Magenta

            $wslConfContent = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command "cat /etc/wsl.conf" -PrintCommand $false -PassThru

            # Check [boot] section has command= containing mount --make-rshared /
            $wslConfContent | Should -Match '\[boot\]'
            $wslConfContent | Should -Match 'command=.*mount --make-rshared /'

            Write-Host "    mount --make-rshared boot command verified" -ForegroundColor Green
        }

        It "Should verify Docker is NOT installed (mutual exclusion)" {
            Write-Host "`n==> TEST: Verifying Docker is not installed ..." -ForegroundColor Magenta

            $dockerInstalled = Test-WslDockerInstalled -DistroName $script:podmanTestDistroName
            $dockerInstalled | Should -Be $false

            Write-Host "    Docker is NOT installed (correct for Podman-only distro)" -ForegroundColor Green
        }

        It "Should verify DOCKER_HOST is set in .bashrc" {
            Write-Host "`n==> TEST: Verifying DOCKER_HOST in .bashrc ..." -ForegroundColor Magenta

            $bashrcContent = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command "cat ~testuser/.bashrc" -PrintCommand $false -PassThru

            $bashrcContent | Should -Match 'DOCKER_HOST=unix:///run/user/\$\(id -u\)/podman/podman\.sock'

            Write-Host "    DOCKER_HOST is set in .bashrc" -ForegroundColor Green
        }

        It "Should verify XDG_RUNTIME_DIR and DBUS_SESSION_BUS_ADDRESS in .bashrc" {
            Write-Host "`n==> TEST: Verifying XDG_RUNTIME_DIR and DBUS_SESSION_BUS_ADDRESS in .bashrc ..." -ForegroundColor Magenta

            $bashrcContent = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command "cat ~testuser/.bashrc" -PrintCommand $false -PassThru

            $bashrcContent | Should -Match 'XDG_RUNTIME_DIR'
            $bashrcContent | Should -Match 'DBUS_SESSION_BUS_ADDRESS'

            Write-Host "    XDG_RUNTIME_DIR and DBUS_SESSION_BUS_ADDRESS are set in .bashrc" -ForegroundColor Green
        }

        It "Should verify loginctl enable-linger is set for testuser" {
            Write-Host "`n==> TEST: Verifying loginctl enable-linger for testuser ..." -ForegroundColor Magenta

            $lingerStatus = Invoke-WslDistroCommand -DistroName $script:podmanTestDistroName `
                -Command "loginctl show-user testuser -p Linger" -PrintCommand $false -PassThru -StopAtError $false
            Write-Host "    Linger status: $lingerStatus" -ForegroundColor Cyan
            $lingerStatus.Trim() | Should -Be "Linger=yes"

            Write-Host "    loginctl enable-linger verification complete" -ForegroundColor Green
        }
    }
}
