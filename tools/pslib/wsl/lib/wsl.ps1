<#
.DESCRIPTION
    Utility methods for WSL (Windows Subsystem for Linux) operations.

    This file serves as the main entry point for WSL functionality.
    All functions are organized into logical modules in the lib/ directory.
#>

# Source dependencies
. "$PSScriptRoot\..\..\utils\utils.ps1"

# Source all WSL modules
. "$PSScriptRoot\core.ps1"
. "$PSScriptRoot\install.ps1"
. "$PSScriptRoot\ops.ps1"
. "$PSScriptRoot\user.ps1"
. "$PSScriptRoot\exec.ps1"
. "$PSScriptRoot\docker.ps1"
. "$PSScriptRoot\podman.ps1"
. "$PSScriptRoot\proxy.ps1"
