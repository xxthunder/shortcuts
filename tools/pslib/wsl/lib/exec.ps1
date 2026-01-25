<#
.DESCRIPTION
    WSL command execution functions for running commands inside distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\..\utils\utils.ps1"

function Invoke-WslDistroCommand {
    <#
    .SYNOPSIS
        Executes a command inside a WSL distribution.

    .DESCRIPTION
        Runs a command within a specified WSL distribution using bash.
        Provides consistent error handling. By default, output flows to the console
        in real-time. Use -PassThru to capture and return the output as a string.

    .PARAMETER DistroName
        The name of the WSL distribution in which to execute the command.

    .PARAMETER Command
        The command to execute inside the distribution.

    .PARAMETER StopAtError
        If $true (default), throws an error when the command fails (non-zero exit code).
        If $false, continues execution.

    .PARAMETER PrintCommand
        If $true (default), prints the command being executed.
        If $false, executes silently without printing the command.

    .PARAMETER Silent
        If $true, suppresses command output display.
        If $false (default), displays output in real-time.

    .PARAMETER PassThru
        If specified, captures and returns the command output as a string.
        If not specified (default), output flows to console in real-time.

    .OUTPUTS
        System.String (only when -PassThru is specified)
        Returns the command output as a joined string when -PassThru is used.

    .EXAMPLE
        Invoke-WslDistroCommand -DistroName "Debian" -Command "apt update"
        Executes "apt update" with real-time console output.

    .EXAMPLE
        Invoke-WslDistroCommand -DistroName "Ubuntu" -Command "apt update" -PrintCommand $false
        Updates package lists without printing the command, output flows to console.

    .EXAMPLE
        $output = Invoke-WslDistroCommand -DistroName "Debian" -Command 'grep "^ID=" /etc/os-release' -PassThru
        Captures the output of a command for further processing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [bool]$StopAtError = $true,

        [Parameter(Mandatory = $false)]
        [bool]$PrintCommand = $true,

        [Parameter(Mandatory = $false)]
        [bool]$Silent = $false,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    if (-not (Test-WslInstalled)) {
        throw "WSL is not installed. Please install WSL first."
    }

    # Validate distribution exists
    $distros = Get-WslDistroList
    if ($DistroName -notin $distros) {
        throw "Distribution '$DistroName' does not exist."
    }

    # Escape double quotes for bash and dollar signs for PowerShell
    # We use double quotes around the command to allow bash variable expansion (e.g., $ID from /etc/os-release)
    # But we need to escape $ for PowerShell so it doesn't try to expand bash variables
    $escapedCommand = $Command.Replace('"', '\"').Replace('$', '`$')

    # Build the WSL command using expandable string with backtick-escaped command
    # The backticks in $escapedCommand will protect bash variables from PowerShell expansion
    $wslCommand = "wsl.exe --distribution $DistroName --exec bash -c `"$escapedCommand`""

    # Execute the command - capture output only if -PassThru is specified
    if ($PassThru) {
        $capturedOutput = Invoke-CommandLine -CommandLine $wslCommand -StopAtError $StopAtError -PrintCommand $PrintCommand -Silent $Silent

        # Return captured output as a joined string
        if ($capturedOutput) {
            return ($capturedOutput -join "`n")
        }
    }
    else {
        # Let output flow to console in real-time, don't return it
        Invoke-CommandLine -CommandLine $wslCommand -StopAtError $StopAtError -PrintCommand $PrintCommand -Silent $Silent
    }
}
