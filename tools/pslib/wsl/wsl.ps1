<#
.DESCRIPTION
    Utility methods for WSL (Windows Subsystem for Linux) operations.

    This file serves as the main entry point for WSL functionality.
    All functions are organized into logical modules in the lib/ directory.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

# Source all WSL modules
. "$PSScriptRoot\lib\core.ps1"
. "$PSScriptRoot\lib\install.ps1"
. "$PSScriptRoot\lib\ops.ps1"
. "$PSScriptRoot\lib\user.ps1"
. "$PSScriptRoot\lib\exec.ps1"
. "$PSScriptRoot\lib\docker.ps1"
