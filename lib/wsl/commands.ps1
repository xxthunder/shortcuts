<#
.DESCRIPTION
    WSL Manager action functions and command dispatcher.
    This file is dot-sourced by manager.ps1 (the orchestration layer).
#>

# Suppress PSAvoidUsingWriteHost - Write-Host is required for colored interactive console output
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive tool requires colored console output')]
param()

# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

# Source dependencies
. "$PSScriptRoot\wsl.ps1"

#region Functions

function Format-DistroListEntry {
    <#
    .SYNOPSIS
        Formats a distribution list entry with state information.

    .PARAMETER Index
        The index number to display.

    .PARAMETER Distro
        The distribution object with Name, State, Version, and IsDefault properties.
    #>
    param(
        [int]$Index,
        [PSCustomObject]$Distro
    )

    $statusParts = @()
    $statusParts += $Distro.State
    $statusParts += "WSL$($Distro.Version)"
    if ($Distro.IsDefault) {
        $statusParts += "Default"
    }
    $status = $statusParts -join ", "

    $stateColor = if ($Distro.State -eq "Running") { "Green" } else { "Gray" }
    Write-Host "  $Index. " -NoNewline -ForegroundColor White
    Write-Host "$($Distro.Name) " -NoNewline -ForegroundColor White
    Write-Host "($status)" -ForegroundColor $stateColor
}

function Show-WslDistroList {
    <#
    .SYNOPSIS
        Displays a list of installed WSL distributions with state information.

    .PARAMETER Distros
        Optional pre-fetched list of distributions. If not provided, fetches from WSL.
    #>
    param(
        [PSCustomObject[]]$Distros = $null
    )

    if ($null -eq $Distros) {
        $Distros = @(Get-WslDistroList -Detailed)
    }

    Write-Host ""
    Write-Host "Installed WSL Distributions:" -ForegroundColor Cyan
    Write-Host "-----------------------------" -ForegroundColor Cyan

    if ($Distros.Count -eq 0) {
        Write-Host "  No WSL distributions found." -ForegroundColor Yellow
    }
    else {
        $index = 1
        foreach ($distro in $Distros) {
            Format-DistroListEntry -Index $index -Distro $distro
            $index++
        }
    }
    Write-Host ""
}

function Select-WslDistro {
    <#
    .SYNOPSIS
        Interactive distro selection helper. Shows a numbered list and resolves user input.

    .PARAMETER Selection
        Pre-provided selection (number or name). If provided, skips the prompt.

    .PARAMETER Distros
        Optional pre-fetched list of distributions. If not provided, fetches from WSL and shows the table.
        When provided (e.g. from the TUI), the table is assumed already visible.

    .OUTPUTS
        The selected distribution name, or $null on cancellation/error.
    #>
    param(
        [string]$Selection = "",
        [PSCustomObject[]]$Distros = $null
    )

    $showTable = $null -eq $Distros
    if ($showTable) {
        $Distros = @(Get-WslDistroList -Detailed)
    }

    if ($Distros.Count -eq 0) {
        Write-WarningMsg "No WSL distributions found."
        return $null
    }

    if ($showTable) {
        Write-Host ""
        Write-Host "Available distributions:" -ForegroundColor Cyan
        $index = 1
        foreach ($distro in $Distros) {
            Format-DistroListEntry -Index $index -Distro $distro
            $index++
        }
        Write-Host ""
    }

    if ([string]::IsNullOrWhiteSpace($Selection)) {
        $Selection = Read-Host "Enter number or name of the distribution"
    }

    if ([string]::IsNullOrWhiteSpace($Selection)) {
        Write-WarningMsg "No selection provided. Cancelling."
        return $null
    }

    if ($Selection -match '^\d+$') {
        $selectionNum = [int]$Selection
        if ($selectionNum -ge 1 -and $selectionNum -le $Distros.Count) {
            return $Distros[$selectionNum - 1].Name
        }
        Write-ErrorMsg "Invalid selection number. Must be between 1 and $($Distros.Count)."
        return $null
    }

    # Validate name against known distributions
    $matched = $Distros | Where-Object { $_.Name -eq $Selection }
    if ($null -eq $matched) {
        Write-ErrorMsg "Distribution '$Selection' not found."
        return $null
    }

    return $Selection
}

function Invoke-CreateDistro {
    <#
    .SYNOPSIS
        Handles the create distribution workflow.
    .PARAMETER Name
        The name of the distribution to create. If empty, prompts the user.
    #>
    [CmdletBinding()]
    param(
        [string]$Name = ""
    )

    # Get available distributions dynamically
    $availableDistros = Get-WslAvailableDistro

    # If Name is not provided, prompt for it
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Host ""
        Write-Host "Available distributions:" -ForegroundColor Cyan

        # Show available distributions with numbers
        $index = 1
        foreach ($distro in $availableDistros) {
            Write-Host "  $index. $distro" -ForegroundColor White
            $index++
        }
        Write-Host ""

        $selection = Read-Host "Enter number or name of the distribution to create"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            Write-WarningMsg "No selection provided. Cancelling."
            return
        }

        # Check if selection is a number
        if ($selection -match '^\d+$') {
            $selectionNum = [int]$selection
            if ($selectionNum -ge 1 -and $selectionNum -le $availableDistros.Count) {
                $Name = $availableDistros[$selectionNum - 1]
            }
            else {
                Write-ErrorMsg "Invalid selection number. Must be between 1 and $($availableDistros.Count)."
                return
            }
        }
        else {
            $Name = $selection
        }
    }

    # Validate the distribution name
    if ($Name -notin $availableDistros) {
        Write-ErrorMsg "Distribution '$Name' is not available."
        Write-Host ""
        Write-Host "Available distributions:" -ForegroundColor Yellow
        foreach ($distro in $availableDistros) {
            Write-Host "  - $distro" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Run 'wsl.exe --list --online' to see all available distributions." -ForegroundColor Yellow
        return
    }

    # Create the distribution (skip confirmation since we're handling it interactively)
    New-WslDistro -Name $Name -Confirm:$false
}

function Invoke-RemoveDistro {
    <#
    .SYNOPSIS
        Handles the remove distribution workflow.
    .PARAMETER Name
        The name or number of the distribution to remove. If not provided, user is prompted.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
    #>
    [CmdletBinding()]
    param(
        [string]$Name = "",
        [PSCustomObject[]]$Distros = $null
    )

    $selectedName = Select-WslDistro -Selection $Name -Distros $Distros
    if ($null -eq $selectedName) { return }

    Remove-WslDistro -Name $selectedName -Confirm:$false
}

function Invoke-UpdateDistro {
    <#
    .SYNOPSIS
        Handles the update distribution workflow.
    .PARAMETER Name
        The name or number of the distribution to update. If not provided, user is prompted.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
    #>
    [CmdletBinding()]
    param(
        [string]$Name = "",
        [PSCustomObject[]]$Distros = $null
    )

    $selectedName = Select-WslDistro -Selection $Name -Distros $Distros
    if ($null -eq $selectedName) { return }

    Update-WslDistro -Name $selectedName -Confirm:$false
}

function Invoke-TerminateDistro {
    <#
    .SYNOPSIS
        Handles the terminate distribution workflow.
    .PARAMETER Name
        The name of the distribution to terminate. If not provided, user is prompted.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
        Numbers entered by the user correspond to the full list (consistent with the TUI).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Name,
        [PSCustomObject[]]$Distros = $null
    )

    # Fetch distros for running-state check; keep original param for Select-WslDistro table logic
    $allDistros = if ($null -ne $Distros) { $Distros } else { @(Get-WslDistroList -Detailed) }

    # Check if any distributions are running
    $hasRunning = $false
    foreach ($distro in $allDistros) {
        if ($distro.State -eq "Running") {
            $hasRunning = $true
            break
        }
    }

    if (-not $hasRunning) {
        Write-WarningMsg "No running WSL distributions found."
        return
    }

    # If Name is provided, use it directly
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        Stop-WslDistro -Name $Name -Confirm:$false
        return
    }

    # CI/Test Environment Check
    if (Test-RunningInCIorTestEnvironment) {
        throw "Cannot run interactive 'terminate' command in CI/Test environment. Please provide -Name parameter."
    }

    $selectedName = Select-WslDistro -Distros $Distros
    if ($null -eq $selectedName) { return }

    # Validate that the selected distribution is running
    $selectedDistro = $allDistros | Where-Object { $_.Name -eq $selectedName }
    if ($null -eq $selectedDistro) {
        Write-ErrorMsg "Distribution '$selectedName' is not in the list of distributions."
        return
    }
    if ($selectedDistro.State -ne "Running") {
        Write-ErrorMsg "Distribution '$selectedName' is not in the list of running distributions."
        return
    }

    Stop-WslDistro -Name $selectedName -Confirm:$false
}

function Invoke-SetupUser {
    <#
    .SYNOPSIS
        Handles the user setup workflow.
    .PARAMETER DistroName
        The name of the distribution to create a user in. If not provided, prompts the user.
    .PARAMETER Username
        The username to create. If not provided, user is prompted.
    .PARAMETER Password
        The password for the new user. If not provided, user is prompted.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Plain-text password is required by chpasswd inside the WSL distribution.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Username and Password are required together for non-interactive WSL user creation.')]
    [CmdletBinding()]
    param(
        [string]$DistroName = "",

        [string]$Username = "",
        [string]$Password = "",

        [PSCustomObject[]]$Distros = $null
    )

    if ([string]::IsNullOrWhiteSpace($DistroName)) {
        $DistroName = Select-WslDistro -Distros $Distros
        if ([string]::IsNullOrWhiteSpace($DistroName)) { return }
    }

    if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($Password)) {
        # CI guard - only fires when prompting is needed
        if (Test-RunningInCIorTestEnvironment) {
            Write-Host "Skipping user setup in CI/test environment." -ForegroundColor Yellow
            return
        }

        Write-Host ""
        Write-Host "Setting up user account in '$DistroName' ..." -ForegroundColor Cyan
        Write-Host ""

        if ([string]::IsNullOrWhiteSpace($Username)) {
            $Username = Read-Host "Enter username"
            if ([string]::IsNullOrWhiteSpace($Username)) {
                Write-WarningMsg "No username provided. Cancelling user setup."
                return
            }
        }

        if ([string]::IsNullOrWhiteSpace($Password)) {
            $securePassword = Read-Host "Enter password" -AsSecureString
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
            $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }

    try {
        New-WslUser -DistroName $DistroName -Username $Username -Password $Password -Confirm:$false

        Write-Host ""
        Write-Success "Successfully created user '$Username' in '$DistroName'."
        Write-Host ""
        Write-Host "To apply the default user change, restart the distribution with:" -ForegroundColor Yellow
        Write-Host "  wsl.exe --terminate $DistroName" -ForegroundColor Yellow
    }
    finally {
        $Password = $null
    }
}

function Invoke-SetupProxy {
    <#
    .SYNOPSIS
        Handles the proxy setup workflow for a WSL distribution.
    .PARAMETER DistroName
        The name of the distribution to configure proxy in. If not provided, prompts the user.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
    #>
    [CmdletBinding()]
    param(
        [string]$DistroName = "",
        [PSCustomObject[]]$Distros = $null
    )

    if ([string]::IsNullOrWhiteSpace($DistroName)) {
        $DistroName = Select-WslDistro -Distros $Distros
        if ([string]::IsNullOrWhiteSpace($DistroName)) { return }
    }

    Write-Host ""
    Write-Host "Setting up proxy in '$DistroName' ..." -ForegroundColor Cyan
    Write-Host ""

    $result = Install-WslProxy -DistroName $DistroName -Confirm:$false

    if ($result) {
        Write-Host ""
        Write-Success "Successfully configured proxy in '$DistroName'."
    }
}

function Invoke-SetupDocker {
    <#
    .SYNOPSIS
        Handles the Docker setup workflow for a WSL distribution.
    .PARAMETER DistroName
        The name of the distribution to install Docker in. If not provided, prompts the user.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
    #>
    [CmdletBinding()]
    param(
        [string]$DistroName = "",
        [PSCustomObject[]]$Distros = $null
    )

    if ([string]::IsNullOrWhiteSpace($DistroName)) {
        $DistroName = Select-WslDistro -Distros $Distros
        if ([string]::IsNullOrWhiteSpace($DistroName)) { return }
    }

    Write-Host ""
    Write-Host "Setting up Docker in '$DistroName' ..." -ForegroundColor Cyan
    Write-Host ""

    # Install Docker Engine (skip confirmation since we're handling it interactively)
    $result = Install-WslDockerEngine -DistroName $DistroName -Confirm:$false

    if ($result) {
        Write-Host ""
        Write-Success "Successfully installed Docker in '$DistroName'."
    }
}

function Invoke-SetupPodman {
    <#
    .SYNOPSIS
        Handles the Podman setup workflow for a WSL distribution.
    .PARAMETER DistroName
        The name of the distribution to install Podman in. If not provided, prompts the user.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
    #>
    [CmdletBinding()]
    param(
        [string]$DistroName = "",
        [PSCustomObject[]]$Distros = $null
    )

    if ([string]::IsNullOrWhiteSpace($DistroName)) {
        $DistroName = Select-WslDistro -Distros $Distros
        if ([string]::IsNullOrWhiteSpace($DistroName)) { return }
    }

    Write-Host ""
    Write-Host "Setting up Podman in '$DistroName' ..." -ForegroundColor Cyan
    Write-Host ""

    # Install Podman (skip confirmation since we're handling it interactively)
    $result = Install-WslPodman -DistroName $DistroName -Confirm:$false

    if ($result) {
        Write-Host ""
        Write-Success "Successfully installed Podman in '$DistroName'."
    }
}

function Invoke-SetupDevPod {
    <#
    .SYNOPSIS
        Handles the DevPod setup workflow for a WSL distribution.
    .PARAMETER DistroName
        The name of the distribution to install DevPod in. If not provided, prompts the user.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
    #>
    [CmdletBinding()]
    param(
        [string]$DistroName = "",
        [PSCustomObject[]]$Distros = $null
    )

    if ([string]::IsNullOrWhiteSpace($DistroName)) {
        $DistroName = Select-WslDistro -Distros $Distros
        if ([string]::IsNullOrWhiteSpace($DistroName)) { return }
    }

    Write-Host ""
    Write-Host "Setting up DevPod in '$DistroName' ..." -ForegroundColor Cyan
    Write-Host ""

    $result = Install-WslDevPod -DistroName $DistroName -Confirm:$false

    if ($result) {
        Write-Host ""
        Write-Success "Successfully installed DevPod in '$DistroName'."
    }
}

function Invoke-RepairInterop {
    <#
    .SYNOPSIS
        Handles the repair-interop workflow for a WSL distribution.
    .PARAMETER DistroName
        The name of the distribution to repair interop in. If not provided, prompts the user.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
    #>
    [CmdletBinding()]
    param(
        [string]$DistroName = "",
        [PSCustomObject[]]$Distros = $null
    )

    if ([string]::IsNullOrWhiteSpace($DistroName)) {
        $DistroName = Select-WslDistro -Distros $Distros
        if ([string]::IsNullOrWhiteSpace($DistroName)) { return }
    }

    Write-Host ""
    Write-Host "Repairing Windows interop in '$DistroName' ..." -ForegroundColor Cyan
    Write-Host ""

    # Check current interop state
    $interopConfigured = Test-WslInteropConfigured -DistroName $DistroName

    if ($interopConfigured) {
        Write-Host "Windows interop is already configured in '$DistroName'." -ForegroundColor Green
        return
    }

    # Configure interop via wsl.conf
    $sections = @{
        interop = @{
            enabled           = "true"
            appendWindowsPath = "true"
        }
    }

    Write-Host "Configuring Windows interop in wsl.conf ..." -ForegroundColor Cyan
    Set-WslConf -DistroName $DistroName -Sections $sections -Confirm:$false

    Write-Host ""
    Write-Success "Successfully configured Windows interop in '$DistroName'."
    Write-Host ""
    Write-Host "To apply the changes, restart the distribution with:" -ForegroundColor Yellow
    Write-Host "  wsl.exe --terminate $DistroName" -ForegroundColor Yellow
}

function Invoke-CloneDistro {
    <#
    .SYNOPSIS
        Handles the clone distribution workflow.
    .PARAMETER SourceName
        The source distribution to clone from. If empty, prompts the user.
    .PARAMETER TargetName
        The target name for the cloned distribution. If empty, prompts the user.
    .PARAMETER Distros
        Optional pre-fetched list of distributions. If provided, skips fetching and reprinting the table.
    #>
    [CmdletBinding()]
    param(
        [string]$SourceName = "",
        [string]$TargetName = "",
        [PSCustomObject[]]$Distros = $null
    )

    # If SourceName is not provided, prompt for it
    if ([string]::IsNullOrWhiteSpace($SourceName)) {
        $SourceName = Select-WslDistro -Distros $Distros
        if ([string]::IsNullOrWhiteSpace($SourceName)) { return }
    }

    # If TargetName is not provided, prompt for it
    if ([string]::IsNullOrWhiteSpace($TargetName)) {
        Write-Host ""
        $targetInput = Read-Host "Enter the target name for the cloned distribution"

        if ([string]::IsNullOrWhiteSpace($targetInput)) {
            Write-WarningMsg "No target name provided. Cancelling."
            return
        }

        $TargetName = $targetInput
    }

    # Clone the distribution (skip confirmation since we're handling it interactively)
    Copy-WslDistro -SourceName $SourceName -TargetName $TargetName -Confirm:$false
}

function Invoke-ConfigureWslDefault {
    <#
    .SYNOPSIS
        Handles the configure-wsl workflow (idempotent .wslconfig defaults).
    .DESCRIPTION
        Applies default WSL global settings to %USERPROFILE%\.wslconfig.
        Existing user values are never overwritten.
    #>
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "Applying default WSL global settings to .wslconfig ..." -ForegroundColor Cyan
    Write-Host ""

    Invoke-ConfigureWsl -Confirm:$false

    Write-Host ""
    Write-Success "Done."
}

function Invoke-ShutdownWsl {
    <#
    .SYNOPSIS
        Handles the WSL shutdown workflow.
    .DESCRIPTION
        Warns the user about running distributions and shuts down the entire WSL subsystem.
    #>
    [CmdletBinding()]
    param()

    # List running distributions as a warning
    $allDistros = @(Get-WslDistroList -Detailed)
    $runningDistros = @($allDistros | Where-Object { $_.State -eq "Running" })

    if ($runningDistros.Count -gt 0) {
        Write-Host ""
        Write-Host "Warning: The following distributions are currently running and will be stopped:" -ForegroundColor Yellow
        foreach ($distro in $runningDistros) {
            Write-Host "  - $($distro.Name)" -ForegroundColor Yellow
        }
    }

    Stop-WslSubsystem -Confirm:$false
}

function Invoke-WslCommand {
    <#
    .SYNOPSIS
        Central command dispatcher for WSL Manager actions.
    .DESCRIPTION
        Routes a command name to the corresponding action function. Called by
        Invoke-WslManager (CLI) and Start-InteractiveMode (TUI) to avoid
        duplicating the dispatch logic.
    .PARAMETER Command
        The command to execute.
    .PARAMETER Name
        Distribution name or selection (passed as Name, SourceName, or DistroName depending on the command).
    .PARAMETER TargetName
        Target distribution name for clone operations.
    .PARAMETER Username
        Username for setup-user command.
    .PARAMETER Password
        Password for setup-user command.
    .PARAMETER Distros
        Optional pre-fetched list of distributions (used by the TUI to avoid re-fetching).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password', Justification = 'Passed through to Invoke-SetupUser for non-interactive WSL user creation.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '', Justification = 'Username and Password are passed through to Invoke-SetupUser for non-interactive WSL user creation.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("list", "install", "clone", "remove", "update", "setup-user", "setup-proxy", "setup-docker", "setup-podman", "setup-devpod", "repair-interop", "terminate", "shutdown", "configure-wsl")]
        [string]$Command,

        [string]$Name = "",
        [string]$TargetName = "",
        [string]$Username = "",
        [string]$Password = "",
        [PSCustomObject[]]$Distros = $null
    )

    switch ($Command) {
        "list" {
            Show-WslDistroList -Distros $Distros
        }
        "install" {
            Invoke-CreateDistro -Name $Name
        }
        "clone" {
            Invoke-CloneDistro -SourceName $Name -TargetName $TargetName -Distros $Distros
        }
        "remove" {
            Invoke-RemoveDistro -Name $Name -Distros $Distros
        }
        "update" {
            Invoke-UpdateDistro -Name $Name -Distros $Distros
        }
        "setup-user" {
            Invoke-SetupUser -DistroName $Name -Username $Username -Password $Password -Distros $Distros
        }
        "setup-proxy" {
            Invoke-SetupProxy -DistroName $Name -Distros $Distros
        }
        "setup-docker" {
            Invoke-SetupDocker -DistroName $Name -Distros $Distros
        }
        "setup-podman" {
            Invoke-SetupPodman -DistroName $Name -Distros $Distros
        }
        "setup-devpod" {
            Invoke-SetupDevPod -DistroName $Name -Distros $Distros
        }
        "repair-interop" {
            Invoke-RepairInterop -DistroName $Name -Distros $Distros
        }
        "terminate" {
            Invoke-TerminateDistro -Name $Name -Distros $Distros
        }
        "shutdown" {
            Invoke-ShutdownWsl
        }
        "configure-wsl" {
            Invoke-ConfigureWslDefault
        }
    }
}

#endregion
