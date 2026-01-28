<#
.DESCRIPTION
    Installation of Shortcuts
#>

param (
    [Parameter(Mandatory = $false, HelpMessage = 'Install in place without cloning/updating the repository. (Switch, default: false)')]
    [switch]$InPlace = $false
)

Function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if running with administrator privileges and fail if so
if (Test-AdminRights) {
    Write-Host "ERROR: This script should not be run with administrator privileges. Please run it from a normal PowerShell console." -ForegroundColor Red
    exit 1
}

Function Copy-Config {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$target,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$source
    )
    robocopy $target $source /E /IS /IT
    if ($LASTEXITCODE -ge 8) {
        Write-Error "Copying '$source' failed"
    }
}

Function New-Shortcut {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$target,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$path
    )
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($target)
    $Shortcut.TargetPath = $path
    $Shortcut.Save()
}

Function New-Startup-Shortcut {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$name,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$path
    )
    $startupPath = Join-Path -Path $env:APPDATA -ChildPath "Microsoft\Windows\Start Menu\Programs\Startup"
    New-Shortcut -target (Join-Path -Path $startupPath -ChildPath "$name.lnk") -path $path
}

# Initial bootstrapping (scoop and other dependencies)
function Invoke-Bootstrap {
    # Download bootstrap scripts from external repository
    Invoke-RestMethod -Uri https://raw.githubusercontent.com/avengineers/bootstrap-installer/refs/tags/$bootstrap_git_tag/install.ps1 | Invoke-Expression
    # Execute bootstrap script
    . .\.bootstrap\bootstrap.ps1
}

## start of script
# Always set the $InformationPreference variable to "Continue" globally,
# this way it gets printed on execution and continues execution afterwards.
$InformationPreference = "Continue"

# Stop on first error
$ErrorActionPreference = "Stop"

$repoUrl = "https://github.com/xxthunder/shortcuts.git"
$shortcutsDir = "$Env:USERPROFILE\shortcuts"
$branch = "develop"

$bootstrap_git_tag = "v1.17.2"

# Load utility methods
Invoke-RestMethod -Uri https://raw.githubusercontent.com/avengineers/bootstrap/refs/tags/$bootstrap_git_tag/utils.ps1 | Invoke-Expression

if (-not $InPlace) {
    # Get the latest commit of this repository
    CloneOrPullGitRepo -RepoUrl $repoUrl -TargetDirectory $shortcutsDir -Branch $branch

    Push-Location $shortcutsDir
}
else {
    # Run in place, no cloning
    Push-Location $PSScriptRoot.TrimEnd("\bin")
}

try {
    Invoke-Bootstrap

    # automatically start AutoHotkey
    New-Startup-Shortcut -name "shortcuts_hotkeys" -path "$shortcutsDir\tools\AutoHotKey\hotkeys.cmd"

    # Create Keypirinha default settings
    Copy-Config "config\keypirinha\portable\Profile" "$Env:USERPROFILE\scoop\apps\keypirinha\current\portable\Profile"

    # Create directory for private shortcuts
    $shortcutsPrivateDir = "$Env:USERPROFILE\shortcuts_private"
    New-Directory $shortcutsPrivateDir

    # Start Keypirinha
    & "$Env:USERPROFILE\scoop\apps\keypirinha\current\keypirinha.exe"

    Write-Output "Installation/Update of Shortcuts was successful."
}
finally {
    Pop-Location
    Read-Host -Prompt "Press Enter to continue ..."
}
## end of script
