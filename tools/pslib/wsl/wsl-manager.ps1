#Requires -Version 5.1

<#
.SYNOPSIS
    WSL Manager - Manage Windows Subsystem for Linux distributions.

.DESCRIPTION
    Interactive tool for managing WSL distributions. Supports listing,
    creating, and removing distributions.

.PARAMETER Command
    The command to execute: list, create, clone, remove, update, setup-user, setup-proxy, setup-docker, setup-podman, repair-interop, terminate.
    If not specified, enters interactive mode.

.PARAMETER Name
    The name of the distribution (used with create and clone commands).
    For create: supports any distribution available from 'wsl.exe --list --online'.
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
    .\wsl-manager.ps1 create Debian
    Creates a new Debian WSL distribution.

.EXAMPLE
    .\wsl-manager.ps1 create Ubuntu-22.04
    Creates an Ubuntu 22.04 LTS distribution.

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
    [ValidateSet("list", "install", "clone", "remove", "update", "setup-user", "setup-proxy", "setup-docker", "setup-podman", "repair-interop", "terminate", "")]
    [string]$Command = "",

    [Parameter(Position = 1)]
    [string]$Name = "",

    [Parameter(Position = 2)]
    [string]$TargetName = "",

    [string]$Username = "",
    [string]$Password = ""
)

. "$PSScriptRoot\lib\commands.ps1"

Invoke-WslManager -Command $Command -Name $Name -TargetName $TargetName -Username $Username -Password $Password
