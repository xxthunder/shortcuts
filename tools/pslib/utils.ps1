<#
.DESCRIPTION
    Utility methods for common tasks.
#>

# Suppress PSAvoidUsingWriteHost for colored console output functions
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host is required for colored console output')]
param()

function Invoke-CommandLine {
    <#
    .SYNOPSIS
        Executes a command line string and handles exit codes.

    .DESCRIPTION
        Invokes a command line expression with proper error handling and output control.
        This function provides consistent error checking across the codebase by validating
        exit codes and providing configurable error handling behavior.

    .PARAMETER CommandLine
        The command line string to execute.

    .PARAMETER StopAtError
        If $true (default), throws an error when the command fails (non-zero exit code).
        If $false, continues execution and logs a warning message.

    .PARAMETER PrintCommand
        If $true (default), prints the command being executed to the output stream.
        If $false, executes silently without printing the command.

    .PARAMETER Silent
        If $true, suppresses all output from the command (stdout and information stream).
        If $false (default), allows command output to display normally.

    .EXAMPLE
        Invoke-CommandLine -CommandLine "git status"
        Executes git status with default settings (prints command, stops on error).

    .EXAMPLE
        Invoke-CommandLine -CommandLine "npm install" -Silent $true
        Executes npm install silently without displaying output.

    .EXAMPLE
        Invoke-CommandLine -CommandLine "test.exe" -StopAtError $false
        Executes test.exe and continues even if it returns a non-zero exit code.

    .NOTES
        Uses Invoke-Expression internally. Only use with trusted command strings.
        Sets $global:LASTEXITCODE to 0 before execution.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Usually this statement must be avoided (https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/avoid-using-invoke-expression?view=powershell-7.3), here it is OK as it does not execute unknown code.')]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$CommandLine,
        [Parameter(Mandatory = $false, Position = 1)]
        [bool]$StopAtError = $true,
        [Parameter(Mandatory = $false, Position = 2)]
        [bool]$PrintCommand = $true,
        [Parameter(Mandatory = $false, Position = 3)]
        [bool]$Silent = $false
    )
    if ($PrintCommand) {
        Write-Output "Executing: $CommandLine"
    }
    $global:LASTEXITCODE = 0

    # Temporarily set ErrorActionPreference to Continue to prevent stderr from native commands
    # from causing terminating errors. This is necessary because native commands (like wsl.exe)
    # often write warnings to stderr which PowerShell captures as error records.
    # With ErrorActionPreference = 'Stop', these would cause the script to terminate even if
    # the command succeeded (exit code 0).
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    try {
        if ($Silent) {
            # Omit information stream (6) and stdout (1)
            Invoke-Expression $CommandLine 6>&1 | Out-Null
        }
        else {
            Invoke-Expression $CommandLine
        }
    }
    finally {
        # Restore original ErrorActionPreference
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($global:LASTEXITCODE -ne 0) {
        if ($StopAtError) {
            Write-Error "Command line call `"$CommandLine`" failed with exit code $global:LASTEXITCODE"
        }
        else {
            Write-Information "Command line call `"$CommandLine`" failed with exit code $global:LASTEXITCODE, continuing ..."
        }
    }
}

# Update/Reload current environment variable PATH with settings from registry
function Initialize-EnvPath {
    # workaround for system-wide installations (e.g. in GitHub Actions)
    if ($Env:USER_PATH_FIRST) {
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    }
    else {
        $Env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
}

function Remove-Path {
    <#
    .SYNOPSIS
        Removes a file or directory.

    .DESCRIPTION
        Safely removes a file or directory if it exists. Handles both files and directories
        with appropriate Remove-Item parameters.

    .PARAMETER Path
        The path to the file or directory to remove.

    .EXAMPLE
        Remove-Path -Path "C:\Temp\MyFolder"
        Removes the directory and all its contents.

    .EXAMPLE
        Remove-Path -Path "C:\Temp\file.txt"
        Removes the specified file.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$Path
    )
    if (Test-Path -Path $Path -PathType Container) {
        Write-Output "Deleting directory '$Path' ..."
        Remove-Item $Path -Force -Recurse
    }
    elseif (Test-Path -Path $Path -PathType Leaf) {
        Write-Output "Deleting file '$Path' ..."
        Remove-Item $Path -Force
    }
}

function New-Directory {
    <#
    .SYNOPSIS
        Creates a new directory if it doesn't exist.

    .DESCRIPTION
        Creates a directory at the specified path if it does not already exist.
        Does nothing if the directory already exists.

    .PARAMETER Path
        The path where the directory should be created.

    .EXAMPLE
        New-Directory -Path "C:\Temp\MyFolder"
        Creates the directory if it doesn't exist.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$Path
    )
    if (-Not (Test-Path -Path $Path)) {
        Write-Output "Creating directory '$Path' ..."
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Test-RunningInCIorTestEnvironment {
    # Check if running in CI environment
    $ciEnvVars = @('CI', 'GITHUB_ACTIONS', 'TF_BUILD', 'JENKINS_URL', 'CIRCLECI')
    foreach ($var in $ciEnvVars) {
        if (Test-Path "Env:\$var") {
            return $true
        }
    }

    # Check if running in Pester test environment
    # Look for PesterPreference in various scopes
    $pesterVar = Get-Variable -Name 'PesterPreference' -Scope Global -ErrorAction SilentlyContinue
    if ($null -ne $pesterVar) {
        return $true
    }

    # Alternative check: look for Pester module in call stack
    $callStack = Get-PSCallStack
    foreach ($frame in $callStack) {
        if ($frame.Command -like '*Pester*' -or $frame.InvocationInfo.MyCommand.ModuleName -eq 'Pester') {
            return $true
        }
    }

    return $false
}

function Get-UserConfirmation {
    <#
    .SYNOPSIS
        Prompts the user for confirmation with Yes/No response.

    .DESCRIPTION
        Displays a confirmation prompt to the user in interactive mode.
        In CI or test environments, automatically returns the specified CI value.

    .PARAMETER message
        The confirmation message to display to the user.

    .PARAMETER defaultValueForUser
        The default value if the user presses Enter without typing anything.
        Default is $true.

    .PARAMETER valueForCi
        The value to return when running in CI or test environment.
        Default is $false.

    .EXAMPLE
        Get-UserConfirmation -message "Continue with installation?"
        Prompts user with default Yes.

    .EXAMPLE
        Get-UserConfirmation -message "Delete files?" -defaultValueForUser $false
        Prompts user with default No.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$message,
        # Default value of the confirmation prompt
        [Parameter(Mandatory = $false)]
        [bool]$defaultValueForUser = $true,
        # Value when running in CI or test environment
        [Parameter(Mandatory = $false)]
        [bool]$valueForCi = $false
    )

    if (Test-RunningInCIorTestEnvironment) {
        return $valueForCi
    }
    else {
        $defaultText = if ($defaultValueForUser) { "[Y/n]" } else { "[y/N]" }
        $userResponse = Read-Host "$message $defaultText"
        if ($userResponse -eq '') {
            return $defaultValueForUser
        }
        elseif ($userResponse -match '^[Yy](es)?$') {
            return $true
        }
        elseif ($userResponse -match '^[Nn](o)?$') {
            return $false
        }
        else {
            # Invalid input, return opposite of default to force explicit choice
            return $false
        }
    }
}

#region Console Output Helpers

function Write-Status {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

#endregion
