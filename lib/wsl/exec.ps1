<#
.DESCRIPTION
    WSL command execution functions for running commands inside distributions.
#>

# Source dependencies
. "$PSScriptRoot\..\utils\utils.ps1"

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

    # Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

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

function Invoke-WslDistroScript {
    <#
    .SYNOPSIS
        Executes a bash script file inside a WSL distribution.

    .DESCRIPTION
        Converts Windows script paths to WSL mount paths and executes the script
        via bash. Supports argument passing and exit code handling.

    .PARAMETER ScriptPath
        Windows path to the bash script (e.g., C:\path\to\script.sh)

    .PARAMETER DistroName
        Name of the WSL distribution to execute the script in

    .PARAMETER Arguments
        Optional array of arguments to pass to the script

    .PARAMETER StopAtError
        If true, throws on non-zero exit code. Default: true

    .PARAMETER PrintCommand
        If true, prints the command before execution. Default: true

    .OUTPUTS
        System.Int32
        Returns the exit code from the script execution.

    .EXAMPLE
        Invoke-WslDistroScript -ScriptPath "C:\scripts\setup.sh" -DistroName "Debian"

    .EXAMPLE
        Invoke-WslDistroScript -ScriptPath "C:\scripts\install.sh" -DistroName "Ubuntu" `
            -Arguments @("--user=developer", "--mode=production")

    .EXAMPLE
        $exitCode = Invoke-WslDistroScript -ScriptPath "C:\scripts\test.sh" -DistroName "Debian" -StopAtError $false
        if ($exitCode -ne 0) {
            Write-Host "Script failed with exit code: $exitCode"
        }

    .PARAMETER StdinInput
        Optional string piped to the script's stdin. Used to pass secrets without
        exposing them in /proc/<pid>/cmdline (env vars persist for every child shell;
        cmdline persists for the script's lifetime). Bypasses Invoke-CommandLine
        because Invoke-Expression cannot pipe stdin.

    .PARAMETER Interactive
        If set, runs the script with stdin attached to the console (not piped, not
        suppressed) so WSL allocates a pty and interactive prompts inside the script
        — e.g. kinit's Kerberos password prompt — reach /dev/tty. Mutually exclusive
        with StdinInput (a piped stdin closes the terminal the prompt needs).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DistroName,

        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @(),

        [Parameter(Mandatory = $false)]
        [bool]$StopAtError = $true,

        [Parameter(Mandatory = $false)]
        [bool]$PrintCommand = $true,

        [Parameter(Mandatory = $false)]
        [string]$StdinInput,

        [Parameter(Mandatory = $false)]
        [switch]$Interactive
    )

    # Validate script exists
    if (-not (Test-Path $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }

    # Validate distribution exists
    Assert-WslDistroExists -DistroName $DistroName

    # Convert Windows path to WSL mount path
    # Extract drive letter and convert to lowercase (C:, D:, etc.)
    $driveLetter = $ScriptPath.Substring(0, 1).ToLower()
    $driveLetterUpper = $driveLetter.ToUpper()

    # Convert to WSL path: replace drive letter with /mnt/X/ and backslashes with forward slashes
    # First, replace the drive letter (e.g., "C:" or "c:" -> "/mnt/c") - case insensitive
    $drivePattern = "^[${driveLetter}${driveLetterUpper}]:"
    $wslPath = $ScriptPath -replace $drivePattern, "/mnt/${driveLetter}"
    # Then convert backslashes to forward slashes
    $wslPath = $wslPath.Replace('\', '/')

    # Build WSL command with arguments
    $argString = ""
    if ($Arguments.Count -gt 0) {
        $argString = " " + ($Arguments -join ' ')
    }

    # Stdin path: bypass Invoke-CommandLine (Invoke-Expression cannot pipe stdin).
    # Used for secrets that must not appear in /proc/<pid>/cmdline.
    if ($PSBoundParameters.ContainsKey('StdinInput')) {
        if ($PrintCommand) {
            Write-Verbose "Executing (stdin piped): wsl.exe --distribution $DistroName --exec bash -l `"$wslPath`"$argString"
        }
        $exitCode = Invoke-WslExeWithStdin -DistroName $DistroName -WslPath $wslPath -Arguments $Arguments -StdinInput $StdinInput
        if ($exitCode -ne 0 -and $StopAtError) {
            throw "Script execution failed with exit code: $exitCode"
        }
        return $exitCode
    }

    # Interactive path: leave stdin on the console so WSL allocates a pty and the
    # script can prompt (e.g. kinit). Bypasses Invoke-CommandLine, which redirects
    # stdout to Out-Null and would hide the prompt's surrounding output.
    if ($Interactive) {
        if ($PrintCommand) {
            Write-Verbose "Executing (interactive): wsl.exe --distribution $DistroName --exec bash -l `"$wslPath`"$argString"
        }
        $exitCode = Invoke-WslExeInteractive -DistroName $DistroName -WslPath $wslPath -Arguments $Arguments
        if ($exitCode -ne 0 -and $StopAtError) {
            throw "Script execution failed with exit code: $exitCode"
        }
        return $exitCode
    }

    # Execute via bash login shell (no need for script to be +x since we're invoking bash directly)
    # -l (login shell) causes bash to source /etc/profile and ~/.profile,
    # making proxy env vars configured by setup-proxy available to curl and other tools.
    # Note: scripts handle their own privilege escalation via sudo internally,
    # so we always run as the default (non-root) user to preserve environment
    # variables (e.g. proxy settings configured in .profile).
    $commandLine = "wsl.exe --distribution $DistroName --exec bash -l `"$wslPath`"$argString"

    # Execute and suppress output (we only care about exit code)
    Invoke-CommandLine -CommandLine $commandLine -StopAtError $StopAtError -PrintCommand $PrintCommand | Out-Null

    # Return exit code
    return $LASTEXITCODE
}

function Invoke-WslExeWithStdin {
    <#
    .SYNOPSIS
        Runs wsl.exe with a string piped to the script's stdin. Mockable wrapper
        around the native invocation so tests don't shell out.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)][string]$DistroName,
        [Parameter(Mandatory = $true)][string]$WslPath,
        [Parameter(Mandatory = $false)][string[]]$Arguments = @(),
        [Parameter(Mandatory = $true)][string]$StdinInput
    )

    # Out-Host (not Out-Null): stream the script's stdout to the console so the
    # user sees install progress live during a multi-minute apt/pipx run, while
    # keeping it out of the pipeline so $LASTEXITCODE stays the only return value.
    $global:LASTEXITCODE = 0
    $StdinInput | & wsl.exe --distribution $DistroName --exec bash -l $WslPath @Arguments | Out-Host
    return $LASTEXITCODE
}

function Invoke-WslExeInteractive {
    <#
    .SYNOPSIS
        Runs wsl.exe as a child that inherits the real console, so the script can
        prompt the user interactively (e.g. kinit's Kerberos password) and its
        output appears live. Mockable wrapper so tests don't shell out.

    .DESCRIPTION
        Uses Start-Process -NoNewWindow -Wait -PassThru rather than the call
        operator. The call operator does not work here: WSL allocates a pty only
        when its std handles are console handles, but PowerShell captures a native
        command's stdout whenever the result is consumed up the call chain (here
        Install-WslProxy assigns the exit code). That capture replaces stdout with
        a pipe — so the output is swallowed (blinking cursor) AND no pty is
        allocated, which corrupts kinit's password read. Earlier piping to Out-Host
        showed output but still broke the pty (kinit reported "Password incorrect"
        for a correct password — SC-036c UAT). Start-Process -NoNewWindow gives the
        child the parent console directly (real pty, live I/O) and -PassThru yields
        the exit code without the pipeline ever touching the child's stdout.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)][string]$DistroName,
        [Parameter(Mandatory = $true)][string]$WslPath,
        [Parameter(Mandatory = $false)][string[]]$Arguments = @()
    )

    $argList = @('--distribution', $DistroName, '--exec', 'bash', '-l', $WslPath) + $Arguments
    $proc = Start-Process -FilePath 'wsl.exe' -ArgumentList $argList -NoNewWindow -Wait -PassThru
    return $proc.ExitCode
}
