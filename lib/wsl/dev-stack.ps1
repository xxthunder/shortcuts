<#
.DESCRIPTION
    WSL dev-stack functions: hand the Linux side of a WSL distribution (container runtime,
    tools, optional Claude Code) to the dev-stack Ansible role.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

function Install-WslDevStack {
    <#
    .SYNOPSIS
        Applies the dev-stack Ansible role to a WSL distribution.

    .DESCRIPTION
        Prepares /etc/wsl.conf (systemd, and for Podman the boot command
        'mount --make-rshared /'), registers the WSLInterop binfmt format, then runs
        setup-dev-stack.sh, which installs Ansible, fetches the pinned dev-stack role and
        runs its playbook. Safe to run more than once.

        Prerequisites:
        - WSL2 (not WSL1)
        - Debian or Ubuntu distribution (Docker: Debian only)
        - Default user configured in /etc/wsl.conf (or Username parameter provided)
        - The other container runtime must NOT be installed (mutual exclusion)

        Validation and coexistence failures throw. A failure of one of the scripts is
        written as an error and the function returns $false.

    .PARAMETER DistroName
        The name of the WSL distribution.

    .PARAMETER Runtime
        The container runtime: 'podman' (default) or 'docker'.

    .PARAMETER ClaudeCode
        Also installs Claude Code through the role.

    .PARAMETER Username
        Optional user for the setup. Default: the default user from /etc/wsl.conf.

    .OUTPUTS
        System.Boolean
        Returns $true if the role was applied, $false otherwise.

    .EXAMPLE
        Install-WslDevStack -DistroName "Debian"

    .EXAMPLE
        Install-WslDevStack -DistroName "Debian" -Runtime docker -ClaudeCode -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("podman", "docker")]
        [string]$Runtime = "podman",

        [Parameter(Mandatory = $false)]
        [switch]$ClaudeCode,

        [Parameter(Mandatory = $false)]
        [string]$Username
    )

    if ($Username) {
        $Username = $Username.Trim()
    }

    # 1. Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

    # 2. Check WSL2 (not WSL1)
    if (-not (Test-Wsl2Version -DistroName $DistroName)) {
        throw @"
Distribution '$DistroName' is using WSL1.
The dev-stack setup requires WSL2. Upgrade with:
  wsl.exe --set-version $DistroName 2
"@
    }

    # 3. Check distribution type (Debian/Ubuntu only)
    $distroType = Get-WslDistroType -DistroName $DistroName
    if ($distroType -notin @("debian", "ubuntu")) {
        throw "Distribution '$DistroName' is not a Debian or Ubuntu distribution (detected: $distroType). Only Debian and Ubuntu distributions are currently supported for the dev-stack setup."
    }

    # 4. Docker only on Debian
    if ($Runtime -eq "docker" -and $distroType -ne "debian") {
        throw "Docker is supported on Debian only: '$DistroName' is Ubuntu. The dev-stack role installs Docker on Debian only. Use -Runtime podman, or a Debian distribution."
    }

    # 5. Detect or validate username
    if (-not $Username) {
        $Username = Get-WslDefaultUser -DistroName $DistroName
        if (-not $Username) {
            throw @"
No default user configured in '$DistroName'.
The dev-stack setup requires a non-root user.

Please setup a user first:
  wsl-manager setup-user $DistroName

Then run the dev-stack setup again.
"@
        }
    }

    # 6. Mutual exclusion of Docker and Podman
    $other = if ($Runtime -eq "podman") { "Docker" } else { "Podman" }
    $otherInstalled = if ($Runtime -eq "podman") {
        Test-WslDockerInstalled -DistroName $DistroName
    }
    else {
        Test-WslPodmanInstalled -DistroName $DistroName
    }
    if ($otherInstalled) {
        $self = if ($Runtime -eq "podman") { "Podman" } else { "Docker" }
        throw @"
$other is already installed in '$DistroName'.
Docker and Podman cannot coexist in the same distribution.

To use $self, first remove $other, or use a separate WSL distribution.
"@
    }

    # 7. wsl.conf: systemd, and the boot command for rootless Podman
    $systemdConfigured = Test-WslSystemdConfigured -DistroName $DistroName
    $bootCommandOk = $true
    if ($Runtime -eq "podman") {
        $conf = Get-WslConf -DistroName $DistroName
        $bootSection = $conf["boot"]
        $bootCommandOk = ($bootSection -is [hashtable] -and $bootSection["command"] -eq "mount --make-rshared /")
    }

    if (-not $systemdConfigured -or -not $bootCommandOk) {
        $sections = @{ boot = @{} }
        if (-not $systemdConfigured) {
            $sections.boot.systemd = "true"
        }
        if (-not $bootCommandOk) {
            $sections.boot.command = "mount --make-rshared /"
        }

        $existingUser = Get-WslDefaultUser -DistroName $DistroName
        if ($existingUser) {
            $sections.user = @{ default = $existingUser }
        }

        Write-Information "Configuring /etc/wsl.conf in '$DistroName'..."
        Set-WslConf -DistroName $DistroName -Sections $sections -Confirm:$false | Out-Null

        Write-Information "Restarting distribution to apply changes..."
        Stop-WslDistro -Name $DistroName -Confirm:$false | Out-Null
    }

    # 8. Confirmation
    if (-not $PSCmdlet.ShouldProcess(
            "Dev-stack setup in '$DistroName'",
            "Apply the dev-stack Ansible role ($Runtime)",
            "Confirm Dev-Stack Setup"
        )) {
        return $false
    }

    try {
        # 9. WSLInterop binfmt
        Write-Information "Registering WSLInterop in '$DistroName'..."
        $binfmtPath = Join-Path $PSScriptRoot "scripts\setup-binfmt-interop.sh"
        $binfmtExit = Invoke-WslDistroScript -ScriptPath $binfmtPath -DistroName $DistroName -Arguments @() -StopAtError $false -PrintCommand $false
        if ($binfmtExit -ne 0) {
            throw "WSLInterop binfmt setup failed with exit code: $binfmtExit"
        }

        # 10. dev-stack role
        Write-Information "Applying the dev-stack role in '$DistroName' (runtime: $Runtime)..."
        $claudeValue = if ($ClaudeCode) { "true" } else { "false" }
        $scriptPath = Join-Path $PSScriptRoot "scripts\setup-dev-stack.sh"
        $scriptArgs = @(
            "--runtime=$Runtime",
            "--username=$Username",
            "--claude-code=$claudeValue"
        )

        $exitCode = Invoke-WslDistroScript -ScriptPath $scriptPath -DistroName $DistroName -Arguments $scriptArgs -StopAtError $false -PrintCommand $false

        switch ($exitCode) {
            0 {
                Write-Information ""
                Write-Information "Successfully applied the dev-stack role in '$DistroName'."
                Write-Information ""
                Write-Information "Terminating '$DistroName' to apply changes..."
                Stop-WslDistro -Name $DistroName -Confirm:$false | Out-Null
                Write-Information ""
                Write-Information "Next steps:"
                Write-Information "  1. Start the distribution:"
                Write-Information "       wsl.exe --distribution $DistroName  (or: wsl-manager shell $DistroName)"
                Write-Information "  2. Test the container runtime (should work without sudo):"
                Write-Information "       $Runtime ps"
                Write-Information "       $Runtime run hello-world"
                return $true
            }
            1 {
                throw "Prerequisite check failed. The script must run as a non-root user with sudo (no default user makes wsl run it as root: run setup-user first) and all argument values must be set."
            }
            2 {
                throw "Installation of ansible-core and git failed. Check apt-get and the package sources."
            }
            3 {
                throw "Installation of the dev-stack role (ansible-galaxy role install) failed. Check network and proxy."
            }
            4 {
                throw "Argument error. Required parameters are missing or invalid."
            }
            5 {
                throw "The dev-stack playbook (ansible-playbook) failed. Read the Ansible output above."
            }
            default {
                throw "Dev-stack setup failed with exit code: $exitCode"
            }
        }
    }
    catch {
        Write-Error "Dev-stack setup failed: $_"
        return $false
    }
}
