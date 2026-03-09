#Requires -Version 5.1

<#
.SYNOPSIS
    WSL Manager - Manage Windows Subsystem for Linux distributions.

.DESCRIPTION
    Interactive tool for managing WSL distributions.

    Commands:
      list             List installed distributions with state and version
      install          Install a new distribution from the online catalog
      clone            Clone (export/import) an existing distribution
      remove           Unregister and delete a distribution
      update           Update packages in a distribution
      setup-user       Create a user account with sudo privileges
      setup-proxy      Configure corporate proxy settings
      setup-docker     Install Docker Engine (includes systemd and interop setup)
      setup-podman     Install Podman rootless (includes systemd and interop setup)
      repair-interop   Repair Windows interop configuration in wsl.conf
      terminate        Stop a running distribution
      shutdown         Shut down the entire WSL subsystem

    When called without a command, enters an interactive menu.

.PARAMETER Command
    The command to execute: list, install, clone, remove, update, setup-user, setup-proxy, setup-docker, setup-podman, repair-interop, terminate, shutdown.
    If not specified, enters interactive mode.

.PARAMETER Name
    The name of the distribution (used with install and clone commands).
    For install: supports any distribution available from 'wsl.exe --list --online'.
    For clone: the source distribution name to clone from.
    Examples: Debian, Ubuntu, Ubuntu-22.04, Ubuntu-24.04, kali-linux.

.PARAMETER TargetName
    The target name for the cloned distribution (used with clone command).

.EXAMPLE
    .\wsl-manager.ps1
    Starts interactive mode.

.EXAMPLE
    .\wsl-manager.ps1 list
    Lists all installed WSL distributions.

.EXAMPLE
    .\wsl-manager.ps1 install Debian
    Installs a new Debian WSL distribution.

.EXAMPLE
    .\wsl-manager.ps1 install Ubuntu-22.04
    Installs an Ubuntu 22.04 LTS distribution.

.PARAMETER Username
    The username to create (used with setup-user command).
    If not provided, the user is prompted interactively.

.PARAMETER Password
    The password for the new user (used with setup-user command).
    If not provided, the user is prompted interactively.

.EXAMPLE
    .\wsl-manager.ps1 clone Debian MyProject
    Clones the Debian distribution to a new distribution named MyProject.

.EXAMPLE
    .\wsl-manager.ps1 setup-user Ubuntu-24.04 -Username wsluser -Password wsluser
    Creates a user named 'wsluser' in the Ubuntu-24.04 distribution without interactive prompts.

#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Passed through to Invoke-SetupUser for non-interactive WSL user creation.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Username and Password are passed through to Invoke-SetupUser for non-interactive WSL user creation.')]
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("list", "install", "clone", "remove", "update", "setup-user", "setup-proxy", "setup-docker", "setup-podman", "repair-interop", "terminate", "shutdown", "")]
    [string]$Command = "",

    [Parameter(Position = 1)]
    [string]$Name = "",

    [Parameter(Position = 2)]
    [string]$TargetName = "",

    [string]$Username = "",
    [string]$Password = ""
)

. "$PSScriptRoot\lib\manager.ps1"

Invoke-WslManager -Command $Command -Name $Name -TargetName $TargetName -Username $Username -Password $Password
