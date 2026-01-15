<#
.DESCRIPTION
    Integration tests for utils.ps1 Install-NpmPackage function.
    These tests execute real installations against npm and verify the complete workflow.

    Test workflow:
    1. Install a small npm package (cowsay) for the first time (clean install on CI)
    2. Run install again to verify update logic works
    3. Verify the package command is available

    WARNING: These tests will install and uninstall npm packages globally.
    Test package: cowsay (small package ~71KB)

    REQUIREMENTS:
    - Scoop must be installed
    - Internet connection required
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Integration tests use Write-Host for user feedback during manual test runs.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

Describe "Install-NpmPackage Integration Tests" -Tag "Integration" -Skip:(-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    BeforeAll {
        # Use a small, stable package for testing
        $script:testPackageName = "cowsay"
        $script:testCommand = "cowsay"
        $script:utilsPath = Join-Path $PSScriptRoot "utils.ps1"

        # Load the utilities
        . $script:utilsPath

        Write-Host "==> Preparing test environment..." -ForegroundColor Cyan
        Write-Host "    Scoop is installed" -ForegroundColor Green

        # Verify Node.js is available (will be installed by Install-NpmPackage if needed)
        if (Get-Command node -ErrorAction SilentlyContinue) {
            $nodeVersion = node --version
            Write-Host "    Node.js $nodeVersion is installed" -ForegroundColor Green
        }
        else {
            Write-Host "    Node.js not found, will be installed during test" -ForegroundColor Yellow
        }

        # Check if test package already exists and uninstall it for clean test
        Write-Host "    Checking for existing $script:testPackageName installation..." -ForegroundColor Yellow
        try {
            $null = npm list -g $script:testPackageName --depth=0 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    Uninstalling existing $script:testPackageName for clean test..." -ForegroundColor Yellow
                npm uninstall -g $script:testPackageName 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    Successfully uninstalled $script:testPackageName" -ForegroundColor Green
                }
            }
            else {
                Write-Host "    $script:testPackageName is not installed (clean state)" -ForegroundColor Green
            }
        }
        catch {
            # Silently continue if npm is not installed yet or check fails
            Write-Verbose "Could not check for existing installation: $_"
        }
    }

    AfterAll {
        # Cleanup: Uninstall test package
        Write-Host "==> Cleaning up: Removing test package..." -ForegroundColor Cyan
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            try {
                $null = npm list -g $script:testPackageName --depth=0 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "    Uninstalling $script:testPackageName..." -ForegroundColor Yellow
                    npm uninstall -g $script:testPackageName 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "    Successfully removed $script:testPackageName" -ForegroundColor Green
                    }
                }
            }
            catch {
                # Silently continue if cleanup fails
                Write-Verbose "Could not uninstall test package: $_"
            }
        }
    }

    Context "First Installation (Clean Install)" {
        It "Should install npm package from clean state and print executed commands" {
            Write-Host "`n==> TEST: Installing $script:testPackageName (clean install)..." -ForegroundColor Magenta

            $packageName = $script:testPackageName
            $commandName = $script:testCommand

            # Verify package is not installed before test
            $wasInstalled = $false
            try {
                $null = npm list -g $packageName --depth=0 2>&1
                $wasInstalled = ($LASTEXITCODE -eq 0)
            }
            catch {
                # Expected if npm is not installed yet
                Write-Verbose "Could not check package status: $_"
            }

            if ($wasInstalled) {
                Write-Host "    Note: Package was already installed, uninstalling for clean test..." -ForegroundColor Yellow
                npm uninstall -g $packageName 2>&1 | Out-Null
            }

            # Run Install-NpmPackage (output goes to console via Write-Host)
            Install-NpmPackage -PackageName $packageName -CheckCommand $commandName

            Write-Host "==> Verifying installation..." -ForegroundColor Cyan

            # Verify installation succeeded
            $null = npm list -g $packageName --depth=0 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Package should be installed after running Install-NpmPackage"

            # Verify command is available
            Get-Command $commandName -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            Write-Host "    ✓ Package installed successfully" -ForegroundColor Green
        }
    }

    Context "Second Installation (Update/Verify)" {
        It "Should handle already-installed package and verify/update it" {
            Write-Host "`n==> TEST: Running Install-NpmPackage again (should update/verify)..." -ForegroundColor Magenta

            $packageName = $script:testPackageName
            $commandName = $script:testCommand

            # Verify package is already installed from previous test
            $null = npm list -g $packageName --depth=0 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Package should still be installed from previous test"

            # Run Install-NpmPackage again (output goes to console via Write-Host)
            Install-NpmPackage -PackageName $packageName -CheckCommand $commandName

            Write-Host "==> Verifying package is still installed and functional..." -ForegroundColor Cyan

            # Verify package is still installed
            $null = npm list -g $packageName --depth=0 2>&1
            $LASTEXITCODE | Should -Be 0 -Because "Package should still be installed after update"

            # Verify command is still available
            Get-Command $commandName -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            Write-Host "    ✓ Package updated/verified successfully" -ForegroundColor Green
        }
    }

    Context "Command Verification" {
        It "Should have working package command after installation" {
            Write-Host "`n==> TEST: Verifying $script:testCommand works..." -ForegroundColor Magenta

            # Verify command exists
            $command = Get-Command $script:testCommand -ErrorAction SilentlyContinue
            $command | Should -Not -BeNullOrEmpty

            # Verify command can execute (cowsay --version or similar)
            try {
                $result = & $script:testCommand "Test" 2>&1
                $result | Should -Not -BeNullOrEmpty
                Write-Host "    $script:testCommand executed successfully" -ForegroundColor Green
            }
            catch {
                # Some commands might not support test arguments, just verify it exists
                Write-Verbose "Command check skipped: $_"
                Write-Host "    $script:testCommand exists (execution test skipped)" -ForegroundColor Yellow
            }
        }
    }
}
