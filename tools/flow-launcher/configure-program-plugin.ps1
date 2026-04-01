#Requires -Version 7.4

<#
.SYNOPSIS
    Configures Flow Launcher's Program plugin to index .url shortcut files.

.DESCRIPTION
    Edits the Program plugin's Settings.json to:
    - Add custom source directories (e.g., links/, shortcuts_private/)
    - Enable .url, .bat, .cmd file suffixes for indexing
    - Preserve all existing settings

    This replaces the Favorites plugin approach by using the built-in Program plugin
    to directly index shortcut files from multiple directories.

    This file is meant to be dot-sourced into other scripts.

.EXAMPLE
    . .\configure-program-plugin.ps1
    Update-ProgramPluginConfig -Directories @("C:\Users\me\shortcuts\links")

.NOTES
    - Idempotent: safe to run multiple times, only writes when changes are needed
    - Creates a .bak backup before modifying Settings.json
    - Flow Launcher must be restarted or reindexed after changes
#>

# DO NOT use Set-StrictMode in dot-sourced files
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

function Get-ProgramPluginSettingsPath {
    <#
    .SYNOPSIS
        Returns the path to the Program plugin's Settings.json.
    #>
    [CmdletBinding()]
    param()

    $path = Join-Path $env:USERPROFILE "scoop\persist\flow-launcher\UserData\Settings\Plugins\Flow.Launcher.Plugin.Program\Settings.json"
    return $path
}

function Read-ProgramPluginSetting {
    <#
    .SYNOPSIS
        Reads and parses the Program plugin Settings.json.

    .PARAMETER SettingsPath
        Path to the Settings.json file.

    .RETURNS
        Hashtable with the parsed settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SettingsPath
    )

    if (-not (Test-Path $SettingsPath)) {
        throw "Program plugin Settings.json not found: $SettingsPath"
    }

    $content = Get-Content -Path $SettingsPath -Raw -Encoding UTF8
    $settings = $content | ConvertFrom-Json

    # Convert PSCustomObject to hashtable for easier manipulation
    $hashtable = @{}
    foreach ($property in $settings.PSObject.Properties) {
        $value = $property.Value
        # Convert nested PSCustomObject arrays to hashtable arrays
        if ($value -is [System.Object[]]) {
            $convertedArray = @()
            foreach ($item in $value) {
                if ($item -is [PSCustomObject]) {
                    $itemHash = @{}
                    foreach ($prop in $item.PSObject.Properties) {
                        $itemHash[$prop.Name] = $prop.Value
                    }
                    $convertedArray += $itemHash
                } else {
                    $convertedArray += $item
                }
            }
            $hashtable[$property.Name] = $convertedArray
        } elseif ($value -is [PSCustomObject]) {
            $nestedHash = @{}
            foreach ($prop in $value.PSObject.Properties) {
                $nestedHash[$prop.Name] = $prop.Value
            }
            $hashtable[$property.Name] = $nestedHash
        } else {
            $hashtable[$property.Name] = $value
        }
    }

    return $hashtable
}

function Add-ProgramSource {
    <#
    .SYNOPSIS
        Adds a directory to the Program plugin's ProgramSources list.

    .PARAMETER Settings
        The settings hashtable to modify.

    .PARAMETER Directory
        The directory path to add as a program source.

    .PARAMETER Name
        Optional display name. Defaults to the directory's leaf name.

    .RETURNS
        The modified settings hashtable (with .Changed property).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $false)]
        [string]$Name
    )

    if (-not $Name) {
        $Name = Split-Path -Path $Directory -Leaf
    }

    # Check if directory already exists in ProgramSources
    foreach ($source in $Settings.ProgramSources) {
        if ($source.Location -eq $Directory) {
            Write-Information "Directory already configured: $Directory"
            $Settings.Changed = $false
            return $Settings
        }
    }

    $newSource = @{
        Location         = $Directory
        Name             = $Name
        Enabled          = $true
        UniqueIdentifier = $Name
    }

    $Settings.ProgramSources = @($Settings.ProgramSources) + @($newSource)
    $Settings.Changed = $true

    return $Settings
}

function Set-CustomSuffix {
    <#
    .SYNOPSIS
        Ensures custom file suffixes are present in the Program plugin configuration.

    .PARAMETER Settings
        The settings hashtable to modify.

    .PARAMETER Suffixes
        Array of file suffixes to ensure are present (without dots, e.g., "url", "bat").

    .RETURNS
        The modified settings hashtable (with .Changed property).
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $true)]
        [string[]]$Suffixes
    )

    if (-not $PSCmdlet.ShouldProcess("CustomSuffixes", "Ensure suffixes: $($Suffixes -join ', ')")) {
        return $Settings
    }

    $changed = $false

    # Ensure CustomSuffixes is an array
    if (-not $Settings.CustomSuffixes) {
        $Settings.CustomSuffixes = @()
    }

    $existingSuffixes = @($Settings.CustomSuffixes)

    foreach ($suffix in $Suffixes) {
        if ($suffix -notin $existingSuffixes) {
            $existingSuffixes += $suffix
            $changed = $true
        }
    }

    $Settings.CustomSuffixes = $existingSuffixes

    # Ensure UseCustomSuffixes is true
    if (-not $Settings.UseCustomSuffixes) {
        $Settings.UseCustomSuffixes = $true
        $changed = $true
    }

    $Settings.Changed = $changed

    return $Settings
}

function Write-ProgramPluginSetting {
    <#
    .SYNOPSIS
        Writes the settings hashtable to Settings.json with backup.

    .PARAMETER Settings
        The settings hashtable to write.

    .PARAMETER SettingsPath
        Path to write the Settings.json file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $true)]
        [string]$SettingsPath
    )

    $outputDir = Split-Path -Path $SettingsPath -Parent
    if (-not (Test-Path $outputDir)) {
        throw "Output directory does not exist: $outputDir"
    }

    # Remove internal tracking property before writing
    $settingsToWrite = $Settings.Clone()
    $settingsToWrite.Remove('Changed')

    # Create backup if original file exists
    if (Test-Path $SettingsPath) {
        $backupPath = "$SettingsPath.bak"
        Copy-Item -Path $SettingsPath -Destination $backupPath -Force
        Write-Information "Backup created: $backupPath"
    }

    # Convert to JSON and write
    $json = $settingsToWrite | ConvertTo-Json -Depth 10
    Set-Content -Path $SettingsPath -Value $json -Encoding UTF8 -Force

    Write-Information "Settings written to: $SettingsPath"
}

function Update-ProgramPluginConfig {
    <#
    .SYNOPSIS
        High-level function to configure the Program plugin for shortcut indexing.

    .DESCRIPTION
        Reads the current Program plugin settings, adds source directories,
        ensures custom suffixes are present, and writes back only if changes
        were made. Idempotent - safe to run multiple times without side effects.

    .PARAMETER SettingsPath
        Path to the Settings.json file. Defaults to the standard Scoop persist location.

    .PARAMETER Directories
        Array of directory paths to add as program sources.

    .PARAMETER Suffixes
        Array of file suffixes to ensure are present. Defaults to @("bat", "cmd", "url").

    .EXAMPLE
        Update-ProgramPluginConfig -Directories @("C:\Users\me\shortcuts\links", "C:\Users\me\shortcuts_private")
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SettingsPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Directories,

        [Parameter(Mandatory = $false)]
        [string[]]$Suffixes = @("bat", "cmd", "url")
    )

    if (-not $SettingsPath) {
        $SettingsPath = Get-ProgramPluginSettingsPath
    }

    if (-not $PSCmdlet.ShouldProcess($SettingsPath, "Update Program plugin configuration")) {
        return
    }

    # Read current settings
    $settings = Read-ProgramPluginSetting -SettingsPath $SettingsPath

    # Track whether any changes were made
    $anyChanged = $false

    # Add each directory as a program source
    foreach ($directory in $Directories) {
        $settings = Add-ProgramSource -Settings $settings -Directory $directory
        if ($settings.Changed) { $anyChanged = $true }
    }

    # Ensure custom suffixes are present
    $settings = Set-CustomSuffix -Settings $settings -Suffixes $Suffixes -Confirm:$false
    if ($settings.Changed) { $anyChanged = $true }

    # Ensure required boolean settings are true
    $requiredBooleans = @(
        @{ Path = "EnablePathSource"; Nested = $false },
        @{ Path = "HideDuplicatedWindowsApp"; Nested = $false },
        @{ Path = "http"; Nested = $true; Parent = "BuiltinProtocolsStatus" }
    )
    foreach ($setting in $requiredBooleans) {
        if ($setting.Nested) {
            if (-not $settings[$setting.Parent]) {
                $settings[$setting.Parent] = @{}
            }
            if (-not $settings[$setting.Parent][$setting.Path]) {
                $settings[$setting.Parent][$setting.Path] = $true
                $anyChanged = $true
            }
        } else {
            if (-not $settings[$setting.Path]) {
                $settings[$setting.Path] = $true
                $anyChanged = $true
            }
        }
    }

    # Only write if something actually changed
    if ($anyChanged) {
        Write-ProgramPluginSetting -Settings $settings -SettingsPath $SettingsPath
        Write-Information "Program plugin configuration updated."
    } else {
        Write-Information "Program plugin already configured. No changes needed."
    }
}
