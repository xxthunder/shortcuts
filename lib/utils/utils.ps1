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
    if (-not (Test-Path -Path $Path)) {
        Write-Output "Creating directory '$Path' ..."
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function New-ShortcutFile {
    <#
    .SYNOPSIS
        Creates or overwrites a Windows shortcut (.lnk) file.

    .DESCRIPTION
        Writes a shortcut that starts the target with optional arguments in an
        optional working directory. An existing shortcut at the path is
        overwritten completely: arguments and working directory that are not
        given are cleared. The folder of the shortcut must exist.

    .PARAMETER Path
        The path of the .lnk file to write. PowerShell drive paths are accepted.

    .PARAMETER TargetPath
        The program the shortcut starts.

    .PARAMETER Arguments
        Optional command-line arguments for the target.

    .PARAMETER WorkingDirectory
        Optional folder the target starts in.

    .EXAMPLE
        New-ShortcutFile -Path "$env:TEMP\px.lnk" -TargetPath 'C:\tools\pxw.exe' -Arguments '--config="C:\px\px.ini"' -WorkingDirectory 'C:\px'
        Writes a shortcut that starts pxw.exe with the config file in C:\px.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$TargetPath,
        [Parameter(Mandatory = $false)]
        [string]$Arguments,
        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory
    )
    # The COM object only understands file-system paths, not PowerShell drives.
    $fullPath = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($Path)
    $folder = Split-Path -Path $fullPath -Parent
    if (-not (Test-Path -Path $folder -PathType Container)) {
        throw "Cannot write shortcut '$fullPath': the folder '$folder' does not exist."
    }
    if ($PSCmdlet.ShouldProcess($fullPath, "Write shortcut to '$TargetPath'")) {
        # CreateShortcut loads an existing .lnk, so every property is set to
        # overwrite what an earlier call left there.
        $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($fullPath)
        $shortcut.TargetPath = $TargetPath
        $shortcut.Arguments = $Arguments
        $shortcut.WorkingDirectory = $WorkingDirectory
        $shortcut.Save()
    }
}

function Get-AutostartPath {
    <#
    .SYNOPSIS
        Returns the path of a logon start entry in the user's Startup folder.

    .PARAMETER Name
        The name of the entry, without the .lnk extension. Must be a plain file name.

    .EXAMPLE
        Get-AutostartPath -Name 'px-proxy'
        Returns ...\Start Menu\Programs\Startup\px-proxy.lnk.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -lt 0 })]
        [string]$Name
    )
    # The .NET lookup also finds a Startup folder that IT has redirected.
    return (Join-Path ([Environment]::GetFolderPath('Startup')) "$Name.lnk")
}

function Register-Autostart {
    <#
    .SYNOPSIS
        Starts a program at the user's logon through the Startup folder.

    .DESCRIPTION
        Writes (or overwrites) <Name>.lnk in the user's Startup folder. Windows
        starts the target with the arguments in the working directory at each
        logon. Task Manager lists the entry under Startup apps.

    .PARAMETER Name
        The name of the entry, without the .lnk extension.

    .PARAMETER TargetPath
        The program to start at logon.

    .PARAMETER Arguments
        Optional command-line arguments for the target.

    .PARAMETER WorkingDirectory
        Optional folder the target starts in.

    .OUTPUTS
        The path of the entry, or nothing with -WhatIf.

    .EXAMPLE
        Register-Autostart -Name 'px-proxy' -TargetPath 'C:\tools\pxw.exe' -Arguments '--config="C:\px\px.ini"' -WorkingDirectory 'C:\px'
        Starts pxw.exe with the config in C:\px at each logon.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetPath,
        [Parameter(Mandatory = $false)]
        [string]$Arguments,
        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory
    )
    $path = Get-AutostartPath -Name $Name
    if ($PSCmdlet.ShouldProcess($path, "Start '$TargetPath' at logon")) {
        New-ShortcutFile -Path $path -TargetPath $TargetPath -Arguments $Arguments -WorkingDirectory $WorkingDirectory
        return $path
    }
}

function Unregister-Autostart {
    <#
    .SYNOPSIS
        Deletes a logon start entry from the user's Startup folder.

    .PARAMETER Name
        The name of the entry, without the .lnk extension.

    .OUTPUTS
        $true when an entry was deleted; $false when there was none, or with -WhatIf.

    .EXAMPLE
        Unregister-Autostart -Name 'px-proxy'
        Deletes px-proxy.lnk from the Startup folder, if it exists.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    $path = Get-AutostartPath -Name $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return $false
    }
    if ($PSCmdlet.ShouldProcess($path, 'Delete logon start')) {
        Remove-Item -LiteralPath $path -Force
        return $true
    }
    return $false
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

function Get-UserChoice {
    <#
    .SYNOPSIS
        Prompts the user to pick one option from a fixed set, with an Enter default.

    .DESCRIPTION
        Single-choice counterpart to Get-UserConfirmation. Mirrors its conventions:
        the default option is returned when the user presses Enter, the prompt marks
        the default by capitalizing its first letter (e.g. "[A]uto / [m]anual /
        [r]emove"), invalid input re-prompts, and CI/test environments short-circuit
        to a fixed value without prompting. The user selects by typing either the
        full option label or its first letter (case-insensitive); option initials are
        assumed distinct.

    .PARAMETER message
        The prompt text. The option hint and "(Enter = <default>)" suffix are
        appended automatically.

    .PARAMETER options
        Ordered list of option labels (e.g. 'Auto','Manual','Remove').

    .PARAMETER defaultOption
        The label returned when the user presses Enter. Must be one of -options.

    .PARAMETER valueForCi
        The label returned in CI/test environments. Defaults to -defaultOption.

    .PARAMETER maxAttempts
        How many times to re-prompt on invalid input before throwing. Guards against
        an infinite loop when input is non-interactive but not detected as CI.

    .OUTPUTS
        The selected option label, in its original casing (always a member of -options).

    .EXAMPLE
        Get-UserChoice -message "Proxy setup" -options @('Auto','Manual','Remove') -defaultOption 'Auto'
        Prompts "Proxy setup [A]uto / [m]anual / [r]emove (Enter = Auto)"; Enter returns 'Auto'.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$message,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$options,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$defaultOption,
        [Parameter(Mandatory = $false)]
        [string]$valueForCi,
        [Parameter(Mandatory = $false)]
        [int]$maxAttempts = 3
    )

    # Resolve the default against the option list so callers can't typo a default
    # that the user could never select.
    $default = $options | Where-Object { $_ -ieq $defaultOption } | Select-Object -First 1
    if (-not $default) {
        throw "defaultOption '$defaultOption' is not one of: $($options -join ', ')."
    }

    if (Test-RunningInCIorTestEnvironment) {
        if ($PSBoundParameters.ContainsKey('valueForCi')) {
            return $valueForCi
        }
        return $default
    }

    # Build the hint: capitalize the default's first letter, lowercase the rest,
    # matching Get-UserConfirmation's [Y/n] convention (capital = Enter default).
    $hint = (
        $options | ForEach-Object {
            $first = $_.Substring(0, 1)
            $rest = $_.Substring(1)
            $first = if ($_ -ieq $default) { $first.ToUpper() } else { $first.ToLower() }
            "[$first]$rest"
        }
    ) -join ' / '

    for ($attempt = 0; $attempt -lt $maxAttempts; $attempt++) {
        $response = (Read-Host "$message $hint (Enter = $default)").Trim()
        if ([string]::IsNullOrEmpty($response)) {
            return $default
        }
        $match = $options | Where-Object {
            $_ -ieq $response -or $_.Substring(0, 1) -ieq $response
        } | Select-Object -First 1
        if ($match) {
            return $match
        }
        Write-Warning "Invalid choice '$response'. Expected one of: $($options -join ', ')."
    }

    throw "Invalid choice after $maxAttempts attempts. Expected one of: $($options -join ', ')."
}

function Install-NpmPackage {
    <#
    .SYNOPSIS
        Installs or updates a global npm package, ensuring Node.js is installed via Scoop.

    .DESCRIPTION
        This function checks if Scoop is installed, ensures Node.js is installed/updated via Scoop,
        verifies npm availability, and then installs or updates the specified npm package globally.

    .PARAMETER PackageName
        The name of the npm package to install (e.g., "@anthropic-ai/claude-code").

    .PARAMETER CheckCommand
        Optional. A command to check after installation to verify success (e.g., "claude").
        If not provided, the package installation is considered verified if npm install succeeds.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $false)]
        [string]$CheckCommand
    )

    # Check if Scoop is installed
    Write-Status "Checking for Scoop..."
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Error "Scoop is not installed. Please install Scoop first!"
        return
    }
    Write-Success "Scoop is installed"

    # Install or update Node.js via Scoop
    Write-Status "Checking Node.js installation..."
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $nodeVersion = node --version
        Write-Information "  Current Node.js version: $nodeVersion"

        Write-Status "Updating Node.js via Scoop..."
        # We don't use 'scoop update nodejs' directly because we want to handle failures gracefully
        Invoke-CommandLine -CommandLine "scoop update nodejs" -StopAtError $false -PrintCommand $false -Silent $true

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Scoop update failed, but Node.js is already installed"
        }

        $newNodeVersion = node --version
        if ($nodeVersion -eq $newNodeVersion) {
            Write-Success "Node.js is up to date ($newNodeVersion)"
        } else {
            Write-Success "Node.js updated from $nodeVersion to $newNodeVersion"
        }
    } else {
        Write-Status "Installing Node.js via Scoop..."
        Invoke-CommandLine -CommandLine "scoop install nodejs" -StopAtError $true
        Write-Success "Node.js installed"
    }

    # Verify npm is available
    Write-Status "Verifying npm installation..."
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Error "npm not found. Node.js installation may be incomplete."
        return
    }
    $npmVersion = npm --version
    Write-Success "npm version: $npmVersion"

    # Install or update the Package via npm
    Write-Status "Checking $PackageName installation..."

    # Check if package is installed globally
    $isInstalled = $false
    try {
        Invoke-CommandLine -CommandLine "npm list -g $PackageName --depth=0" -StopAtError $false -Silent $true
        if ($LASTEXITCODE -eq 0) {
            $isInstalled = $true
        }
    } catch {
        # Ignore errors from npm list
        $null = $_
    }

    if ($isInstalled) {
        Write-Information "  $PackageName is already installed"
        Write-Status "Updating $PackageName..."
        Invoke-CommandLine -CommandLine "npm update -g $PackageName" -StopAtError $true
        Write-Success "$PackageName updated"
    } else {
        Write-Status "Installing $PackageName..."
        Invoke-CommandLine -CommandLine "npm install -g $PackageName" -StopAtError $true
        Write-Success "$PackageName installed"
    }

    # Verify installation if CheckCommand is provided
    if (-not [string]::IsNullOrEmpty($CheckCommand)) {
        Write-Status "Verifying $CheckCommand installation..."
        if (Get-Command $CheckCommand -ErrorAction SilentlyContinue) {
            $cmdVersion = & $CheckCommand --version
            if ($null -ne $cmdVersion) {
                 Write-Success "$CheckCommand version: $cmdVersion"
            } else {
                 Write-Success "$CheckCommand is available"
            }
        } else {
            Write-Warning "$CheckCommand command not found even after installation."
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
