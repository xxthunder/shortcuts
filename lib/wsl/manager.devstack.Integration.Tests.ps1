<#
.DESCRIPTION
    Integration test for 'wsl-manager setup-dev-stack' that runs against real WSL.
    It hands the Linux side of a fresh Ubuntu clone to the dev-stack Ansible role with
    Podman and Claude Code, and checks the result inside the distribution.

    Test workflow:
    1. Use existing Ubuntu or install it (base distro)
    2. Clone Ubuntu to ubuntu-devstack-test
    3. Setup user in ubuntu-devstack-test (testuser with NOPASSWD sudo)
    4. setup-dev-stack -Runtime docker on Ubuntu throws and leaves wsl.conf unchanged
    5. setup-dev-stack -ClaudeCode (Podman) succeeds, then the script runs again (changed=0) and the command succeeds again
    6. Test-WslPodmanInstalled is true and Test-WslDockerInstalled is false
    7. Verify the tools, the shell, rootless docker, DOCKER_HOST, wsl.conf, DevPod and binfmt

    NOTE: The test distribution is PRESERVED after the tests for exploratory testing.
    Test distribution: ubuntu-devstack-test (fully prepared, kept after tests)
    Base distribution: Ubuntu (minimal, kept after tests)
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Integration tests use Write-Host for user feedback during manual test runs.')]
param()

Describe "WSL Manager Dev Stack Integration Tests" -Tag "Integration" {
    BeforeAll {
        . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
        Start-SutIsolation

        $script:baseDistroName = "Ubuntu"
        $script:testDistroName = "ubuntu-devstack-test"
        $script:testUser = "testuser"

        # Verify WSL is installed
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            throw "WSL is required for integration tests. wsl.exe not found."
        }

        Write-Host "==> Preparing dev-stack test environment ..." -ForegroundColor Cyan

        # Load the library functions (manager.ps1 dot-sources commands.ps1)
        . (Join-Path $PSScriptRoot "manager.ps1")

        # Runs a command as the default user (testuser) in a zsh login shell, so PATH and
        # DOCKER_HOST from ~/.zprofile apply. The command must not contain single quotes.
        # Append '&& echo command-ok' to a command whose exit code the test checks.
        function Invoke-TestUserCommand {
            param([string]$Command)
            Invoke-WslDistroCommand -DistroName $script:testDistroName -Command "zsh -lc '$Command'" `
                -PrintCommand $false -PassThru -StopAtError $false
        }

        # Path of a repository file as the distribution sees it (/mnt/<drive>/...), the
        # same mapping Invoke-WslDistroScript uses for the scripts.
        function ConvertTo-WslMountPath {
            param([string]$Path)
            $fullPath = (Resolve-Path $Path).Path
            "/mnt/" + $fullPath.Substring(0, 1).ToLower() + $fullPath.Substring(2).Replace('\', '/')
        }

        # Prints free disk and memory of the host and of the test distribution, so a CI log
        # shows the resource trend around the heavy steps (diagnostics for runs that froze).
        function Write-ResourceProbe {
            param([string]$Label)
            $disk = Get-PSDrive -Name C
            $os = Get-CimInstance -ClassName Win32_OperatingSystem
            $vm = Get-Process -Name vmmem, vmmemWSL -ErrorAction SilentlyContinue |
                Measure-Object -Property WorkingSet64 -Sum
            Write-Host ("==> PROBE {0} {1:HH:mm:ss}: host C: free {2:N1} GB; host memory free {3:N1} of {4:N1} GB; WSL VM working set {5:N1} GB" -f `
                    $Label, (Get-Date), ($disk.Free / 1GB), ($os.FreePhysicalMemory / 1MB), ($os.TotalVisibleMemorySize / 1MB), ($vm.Sum / 1GB)) -ForegroundColor DarkGray
            if ($script:testDistroName -in (Get-WslDistroList)) {
                $inside = Invoke-WslDistroCommand -DistroName $script:testDistroName -Command "free -m | sed -n 2p; df -h / | tail -1" `
                    -PrintCommand $false -PassThru -StopAtError $false
                Write-Host "==> PROBE $Label in ${script:testDistroName}: $inside" -ForegroundColor DarkGray
            }
        }

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

        # Always remove test distro before tests (clean slate)
        if ($script:testDistroName -in $existingDistros) {
            Write-Host "    Removing existing $script:testDistroName for fresh test run ..." -ForegroundColor Yellow
            Remove-WslDistro -Name $script:testDistroName -Confirm:$false
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

    Context "Create Base Distribution" {
        It "Should use existing or create Ubuntu" {
            $existingDistros = Get-WslDistroList

            if ($script:baseDistroName -in $existingDistros) {
                Write-Host "`n==> TEST: Using existing $script:baseDistroName ..." -ForegroundColor Magenta
                $existingDistros | Should -Contain $script:baseDistroName
            }
            else {
                Write-Host "`n==> TEST: Creating $script:baseDistroName ..." -ForegroundColor Magenta

                $output = Invoke-WslManager -Command "install" -Name $script:baseDistroName *>&1 | Out-String

                Write-Host "==> Captured Output:" -ForegroundColor Cyan
                Write-Host $output

                $existingDistros = Get-WslDistroList
                $existingDistros | Should -Contain $script:baseDistroName

                $output | Should -Match "Executing:.*wsl.exe --install"
                $output | Should -Match "Successfully created '$script:baseDistroName'"
            }
        }
    }

    Context "Clone and Prepare Test Distribution" {
        It "Should clone Ubuntu to test distro" {
            Write-Host "`n==> TEST: Cloning $script:baseDistroName to $script:testDistroName ..." -ForegroundColor Magenta

            # Shutdown WSL subsystem to prevent systemd auto-restart race (SC-002)
            Write-Host "    Shutting down WSL subsystem before cloning..." -ForegroundColor Yellow
            Stop-WslSubsystem -Confirm:$false

            $output = Invoke-WslManager -Command "clone" -Name $script:baseDistroName -TargetName $script:testDistroName *>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            $existingDistros = Get-WslDistroList
            $existingDistros | Should -Contain $script:testDistroName
        }

        It "Should setup test user with NOPASSWD sudo in cloned distro" {
            Write-Host "`n==> TEST: Setting up user in $script:testDistroName ..." -ForegroundColor Magenta

            $output = Invoke-WslManager -Command "setup-user" -Name $script:testDistroName -Username $script:testUser -Password "testpass123" *>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            $output | Should -Match "Successfully created user '$script:testUser'"
            $output | Should -Match "NOPASSWD sudo has been configured"
            $output | Should -Match "allows running commands as root without password prompt"

            # Restart to apply user changes
            Stop-WslDistro -Name $script:testDistroName -Confirm:$false
            Invoke-WslDistroCommand -DistroName $script:testDistroName -Command "echo 'restarted'" -PrintCommand $false -Silent $true

            # Verify testuser is the default user
            $currentUser = Invoke-WslDistroCommand -DistroName $script:testDistroName `
                -Command "whoami" -PrintCommand $false -PassThru
            $currentUser.Trim() | Should -Be $script:testUser

            # Verify user is in sudo group with a NOPASSWD sudoers file
            $groupCheck = Invoke-WslDistroCommand -DistroName $script:testDistroName -Command "groups $script:testUser" -PrintCommand $false -PassThru
            $groupCheck | Should -Match '\bsudo\b'
            $sudoersCheck = Invoke-WslDistroCommand -DistroName $script:testDistroName -Command "sudo cat /etc/sudoers.d/$script:testUser" -PrintCommand $false -PassThru
            $sudoersCheck | Should -Match "NOPASSWD:ALL"
        }

        It "Should have no [interop] or [automount] section in wsl.conf of the fresh clone" {
            $script:wslConfFresh = Invoke-WslDistroCommand -DistroName $script:testDistroName `
                -Command "cat /etc/wsl.conf" -PrintCommand $false -PassThru -StopAtError $false
            Write-Host "    wsl.conf of the fresh clone:" -ForegroundColor Cyan
            Write-Host $script:wslConfFresh

            $script:wslConfFresh | Should -Not -Match '\[interop\]'
            $script:wslConfFresh | Should -Not -Match '\[automount\]'
        }
    }

    Context "Dev Stack Refusal" {
        It "Should refuse Docker on Ubuntu before any change" {
            Write-Host "`n==> TEST: setup-dev-stack -Runtime docker on Ubuntu ..." -ForegroundColor Magenta

            $before = Invoke-WslDistroCommand -DistroName $script:testDistroName `
                -Command "cat /etc/wsl.conf" -PrintCommand $false -PassThru -StopAtError $false

            { Invoke-WslManager -Command "setup-dev-stack" -Name $script:testDistroName -Runtime docker } |
                Should -Throw "*Docker is supported on Debian only*"

            $after = Invoke-WslDistroCommand -DistroName $script:testDistroName `
                -Command "cat /etc/wsl.conf" -PrintCommand $false -PassThru -StopAtError $false
            $after | Should -BeExactly $before
        }
    }

    Context "Dev Stack Setup with Podman" {
        BeforeEach {
            Write-ResourceProbe -Label "before test"
        }

        AfterEach {
            Write-ResourceProbe -Label "after test"
        }

        It "Should apply the dev-stack role with Claude Code" {
            Write-Host "`n==> TEST: setup-dev-stack -ClaudeCode (first run, may take several minutes) ..." -ForegroundColor Magenta

            $output = Invoke-WslManager -Command "setup-dev-stack" -Name $script:testDistroName -ClaudeCode *>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            $output | Should -Not -Match "Dev-stack setup failed"
            $output | Should -Match "Successfully set up the dev stack in '$script:testDistroName'"
        }

        It "Should change nothing when the script runs again (changed=0)" {
            Write-Host "`n==> TEST: setup-dev-stack.sh as the second application, captured for the PLAY RECAP ..." -ForegroundColor Magenta

            # Invoke-WslDistroScript discards the script's stdout. Run the script the way
            # Install-WslDevStack does (wsl.exe --exec bash -l <script> <args>) through
            # Invoke-WslDistroCommand -PassThru, so its output is captured. The command sits inside
            # a double-quoted bash -c string, so the script path is single-quoted. 2>&1 captures stderr.
            # No exit-code echo: Invoke-WslDistroCommand mangles a trailing '; echo $?'. The script
            # prints '[INFO] Dev stack is set up' only on success, right before exit 0, so that line
            # stands for exit 0.
            $setupScript = ConvertTo-WslMountPath (Join-Path $PSScriptRoot "scripts\setup-dev-stack.sh")
            $output = Invoke-WslDistroCommand -DistroName $script:testDistroName `
                -Command "bash -l '$setupScript' --runtime=podman --username=$script:testUser --claude-code=true 2>&1" `
                -PrintCommand $false -PassThru -StopAtError $false

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            $output | Should -Match '\[INFO\] Dev stack is set up'
            $output | Should -Not -Match '\[ERROR\]'
            $output | Should -Match 'PLAY RECAP'
            $output | Should -Match 'localhost\s+:\s+ok=\d+\s+changed=0\s+unreachable=0\s+failed=0'
        }

        It "Should find Podman and no Docker Engine after the role" {
            Test-WslPodmanInstalled -DistroName $script:testDistroName | Should -Be $true
            Test-WslDockerInstalled -DistroName $script:testDistroName | Should -Be $false
        }

        It "Should succeed on a further run through the command" {
            Write-Host "`n==> TEST: setup-dev-stack -ClaudeCode (further run) ..." -ForegroundColor Magenta

            $output = Invoke-WslManager -Command "setup-dev-stack" -Name $script:testDistroName -ClaudeCode *>&1 | Out-String

            Write-Host "==> Captured Output:" -ForegroundColor Cyan
            Write-Host $output

            $output | Should -Not -Match "Dev-stack setup failed"
            $output | Should -Not -Match "already installed"
            $output | Should -Match "Successfully set up the dev stack in '$script:testDistroName'"
        }

        It "Should run <Name> as testuser" -ForEach @(
            @{ Name = "podman --version"; Pattern = "podman version" }
            @{ Name = "devpod version"; Pattern = "\d+\.\d+" }
            @{ Name = "uv --version"; Pattern = "uv \d+\.\d+" }
            @{ Name = "gh --version"; Pattern = "gh version" }
            @{ Name = "claude --version"; Pattern = "\d+\.\d+\.\d+" }
        ) {
            $output = Invoke-TestUserCommand "$Name && echo command-ok"
            Write-Host "    ${Name}: $output" -ForegroundColor Cyan

            $output | Should -Match "command-ok"
            $output | Should -Match $Pattern
        }

        It "Should set zsh as the login shell of testuser" {
            $passwd = Invoke-WslDistroCommand -DistroName $script:testDistroName `
                -Command "getent passwd $script:testUser" -PrintCommand $false -PassThru
            $passwd.Trim() | Should -Match '/zsh$'
        }

        It "Should install oh-my-zsh for testuser" {
            $output = Invoke-TestUserCommand "test -d ~/.oh-my-zsh && echo command-ok"
            $output | Should -Match "command-ok"
        }

        It "Should run docker (podman-docker) rootless" {
            $output = Invoke-TestUserCommand "docker info && echo command-ok"
            Write-Host "    docker info: $output" -ForegroundColor Cyan

            $output | Should -Match "command-ok"
            $output | Should -Match 'rootless:\s*true'
        }

        It "Should point DOCKER_HOST at the podman socket of testuser in a login shell" {
            $uid = (Invoke-TestUserCommand "id -u").Trim()
            $dockerHost = Invoke-TestUserCommand 'echo $DOCKER_HOST'

            $dockerHost.Trim() | Should -Be "unix:///run/user/$uid/podman/podman.sock"
        }

        It "Should write only systemd and the boot command to wsl.conf" {
            $wslConf = Invoke-WslDistroCommand -DistroName $script:testDistroName `
                -Command "cat /etc/wsl.conf" -PrintCommand $false -PassThru
            Write-Host "    wsl.conf contents:" -ForegroundColor Cyan
            Write-Host $wslConf

            $wslConf | Should -Match '\[boot\]'
            $wslConf | Should -Match 'systemd\s*=\s*true'
            $wslConf | Should -Match 'command\s*=\s*mount --make-rshared /'
            $wslConf | Should -Not -Match '\[interop\]'
            $wslConf | Should -Not -Match '\[automount\]'
        }

        It "Should list the docker provider in DevPod" {
            $output = Invoke-TestUserCommand "devpod provider list && echo command-ok"
            Write-Host "    Provider list: $output" -ForegroundColor Cyan

            $output | Should -Match "command-ok"
            $output | Should -Match "docker"
        }

        It "Should register the WSLInterop binfmt format" {
            $binfmtConf = Invoke-WslDistroCommand -DistroName $script:testDistroName `
                -Command "cat /etc/binfmt.d/WSLInterop.conf" -PrintCommand $false -PassThru
            $binfmtConf | Should -Match ([regex]::Escape(":WSLInterop:M::MZ::/init:PF"))

            $registered = Invoke-WslDistroCommand -DistroName $script:testDistroName `
                -Command "test -e /proc/sys/fs/binfmt_misc/WSLInterop && echo command-ok" -PrintCommand $false -PassThru -StopAtError $false
            $registered | Should -Match "command-ok"
        }
    }
}
