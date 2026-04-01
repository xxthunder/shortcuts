#Requires -Version 7.4

<#
.SYNOPSIS
    Unit tests for configure-program-plugin.ps1
#>

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\configure-program-plugin.ps1"
    . "$PSScriptRoot\..\..\lib\utils\utils.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Get-ProgramPluginSettingsPath" {
    Context "When Flow Launcher is installed via Scoop" {
        It "Should return the correct Settings.json path" {
            # Act
            $result = Get-ProgramPluginSettingsPath

            # Assert
            $result | Should -Match "scoop\\persist\\flow-launcher\\UserData\\Settings\\Plugins\\Flow\.Launcher\.Plugin\.Program\\Settings\.json"
        }
    }
}

Describe "Read-ProgramPluginSetting" {
    Context "When Settings.json exists with valid content" {
        It "Should parse and return the settings object" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "Settings.json"
            $settings = @{
                ProgramSources    = @()
                CustomSuffixes    = @()
                UseCustomSuffixes = $false
            }
            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

            # Act
            $result = Read-ProgramPluginSetting -SettingsPath $settingsPath

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.ProgramSources | Should -HaveCount 0
            $result.CustomSuffixes | Should -HaveCount 0
            $result.UseCustomSuffixes | Should -BeFalse
        }
    }

    Context "When Settings.json does not exist" {
        It "Should throw an error" {
            # Act & Assert
            { Read-ProgramPluginSetting -SettingsPath "C:\nonexistent\Settings.json" } | Should -Throw "*not found*"
        }
    }

    Context "When Settings.json contains invalid JSON" {
        It "Should throw an error" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "BadSettings.json"
            Set-Content -Path $settingsPath -Value "not valid json{{"

            # Act & Assert
            { Read-ProgramPluginSetting -SettingsPath $settingsPath } | Should -Throw
        }
    }
}

Describe "Add-ProgramSource" {
    Context "When adding a new directory to empty ProgramSources" {
        It "Should add the directory with correct properties" {
            # Arrange
            $settings = @{
                ProgramSources         = @()
                DisabledProgramSources = @()
                CustomSuffixes         = @()
                UseCustomSuffixes      = $false
            }
            $directory = "C:\Users\test\shortcuts\links"

            # Act
            $result = Add-ProgramSource -Settings $settings -Directory $directory

            # Assert
            $result.ProgramSources | Should -HaveCount 1
            $result.ProgramSources[0].Location | Should -Be $directory
            $result.ProgramSources[0].Name | Should -Be "links"
            $result.ProgramSources[0].Enabled | Should -BeTrue
            $result.ProgramSources[0].UniqueIdentifier | Should -Be "links"
        }

        It "Should return true for changed" {
            # Arrange
            $settings = @{
                ProgramSources = @()
            }

            # Act
            $result = Add-ProgramSource -Settings $settings -Directory "C:\dir1"

            # Assert
            $result.Changed | Should -BeTrue
        }
    }

    Context "When directory already exists in ProgramSources" {
        It "Should not add a duplicate" {
            # Arrange
            $directory = "C:\Users\test\shortcuts\links"
            $settings = @{
                ProgramSources         = @(
                    @{ Location = $directory; Name = "links"; Enabled = $true }
                )
                DisabledProgramSources = @()
                CustomSuffixes         = @()
                UseCustomSuffixes      = $false
            }

            # Act
            $result = Add-ProgramSource -Settings $settings -Directory $directory

            # Assert
            $result.ProgramSources | Should -HaveCount 1
            $result.Changed | Should -BeFalse
        }
    }

    Context "When adding multiple directories" {
        It "Should add all unique directories" {
            # Arrange
            $settings = @{
                ProgramSources         = @()
                DisabledProgramSources = @()
                CustomSuffixes         = @()
                UseCustomSuffixes      = $false
            }

            # Act
            $result = Add-ProgramSource -Settings $settings -Directory "C:\dir1"
            $result = Add-ProgramSource -Settings $result -Directory "C:\dir2"

            # Assert
            $result.ProgramSources | Should -HaveCount 2
            $result.ProgramSources[0].Location | Should -Be "C:\dir1"
            $result.ProgramSources[1].Location | Should -Be "C:\dir2"
        }
    }

    Context "When directory has a custom name" {
        It "Should use the provided name" {
            # Arrange
            $settings = @{
                ProgramSources         = @()
                DisabledProgramSources = @()
                CustomSuffixes         = @()
                UseCustomSuffixes      = $false
            }

            # Act
            $result = Add-ProgramSource -Settings $settings -Directory "C:\Users\test\shortcuts\links" -Name "My Shortcuts"

            # Assert
            $result.ProgramSources[0].Name | Should -Be "My Shortcuts"
            $result.ProgramSources[0].UniqueIdentifier | Should -Be "My Shortcuts"
        }
    }

    Context "When existing source has extra properties from Flow Launcher" {
        It "Should preserve extra properties like UniqueIdentifier" {
            # Arrange
            $directory = "C:\Users\test\shortcuts"
            $settings = @{
                ProgramSources = @(
                    @{
                        Location         = $directory
                        Name             = "shortcuts"
                        Enabled          = $true
                        UniqueIdentifier = "c:\users\test\shortcuts"
                    }
                )
            }

            # Act
            $result = Add-ProgramSource -Settings $settings -Directory $directory

            # Assert
            $result.ProgramSources | Should -HaveCount 1
            $result.ProgramSources[0].UniqueIdentifier | Should -Be "c:\users\test\shortcuts"
        }
    }
}

Describe "Set-CustomSuffix" {
    Context "When adding suffixes to empty list" {
        It "Should add all specified suffixes and enable custom suffixes" {
            # Arrange
            $settings = @{
                ProgramSources    = @()
                CustomSuffixes    = @()
                UseCustomSuffixes = $false
            }

            # Act
            $result = Set-CustomSuffix -Settings $settings -Suffixes @("url", "bat", "cmd")

            # Assert
            $result.CustomSuffixes | Should -HaveCount 3
            $result.CustomSuffixes | Should -Contain "url"
            $result.CustomSuffixes | Should -Contain "bat"
            $result.CustomSuffixes | Should -Contain "cmd"
            $result.UseCustomSuffixes | Should -BeTrue
            $result.Changed | Should -BeTrue
        }
    }

    Context "When some suffixes already exist" {
        It "Should add only new suffixes" {
            # Arrange
            $settings = @{
                ProgramSources    = @()
                CustomSuffixes    = @("url")
                UseCustomSuffixes = $true
            }

            # Act
            $result = Set-CustomSuffix -Settings $settings -Suffixes @("url", "bat")

            # Assert
            $result.CustomSuffixes | Should -HaveCount 2
            $result.CustomSuffixes | Should -Contain "url"
            $result.CustomSuffixes | Should -Contain "bat"
            $result.Changed | Should -BeTrue
        }
    }

    Context "When all suffixes already exist and UseCustomSuffixes is true" {
        It "Should not duplicate them and report no change" {
            # Arrange
            $settings = @{
                ProgramSources    = @()
                CustomSuffixes    = @("url", "bat")
                UseCustomSuffixes = $true
            }

            # Act
            $result = Set-CustomSuffix -Settings $settings -Suffixes @("url", "bat")

            # Assert
            $result.CustomSuffixes | Should -HaveCount 2
            $result.Changed | Should -BeFalse
        }
    }

    Context "When UseCustomSuffixes is false but suffixes exist" {
        It "Should set UseCustomSuffixes to true and report change" {
            # Arrange
            $settings = @{
                ProgramSources    = @()
                CustomSuffixes    = @("url", "bat")
                UseCustomSuffixes = $false
            }

            # Act
            $result = Set-CustomSuffix -Settings $settings -Suffixes @("url", "bat")

            # Assert
            $result.UseCustomSuffixes | Should -BeTrue
            $result.Changed | Should -BeTrue
        }
    }
}

Describe "Write-ProgramPluginSetting" {
    Context "When writing valid settings" {
        It "Should write JSON to the specified path" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "WriteTest.json"
            $settings = @{
                ProgramSources    = @(
                    @{ Location = "C:\test"; Name = "test"; Enabled = $true }
                )
                CustomSuffixes    = @("url")
                UseCustomSuffixes = $true
            }

            # Act
            Write-ProgramPluginSetting -Settings $settings -SettingsPath $settingsPath

            # Assert
            $settingsPath | Should -Exist
            $written = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            $written.ProgramSources | Should -HaveCount 1
            $written.ProgramSources[0].Location | Should -Be "C:\test"
            $written.CustomSuffixes | Should -HaveCount 1
            $written.CustomSuffixes[0] | Should -Be "url"
            $written.UseCustomSuffixes | Should -BeTrue
        }

        It "Should create a backup of the original file" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "BackupTest.json"
            $originalSettings = @{
                ProgramSources    = @()
                CustomSuffixes    = @()
                UseCustomSuffixes = $false
            }
            $originalSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

            $newSettings = @{
                ProgramSources    = @(
                    @{ Location = "C:\test"; Name = "test"; Enabled = $true }
                )
                CustomSuffixes    = @("url")
                UseCustomSuffixes = $true
            }

            # Act
            Write-ProgramPluginSetting -Settings $newSettings -SettingsPath $settingsPath

            # Assert
            $backupPath = "$settingsPath.bak"
            $backupPath | Should -Exist
            $backupContent = Get-Content -Path $backupPath -Raw | ConvertFrom-Json
            $backupContent.ProgramSources | Should -HaveCount 0
        }
    }

    Context "When output directory does not exist" {
        It "Should throw an error" {
            # Arrange
            $settings = @{ ProgramSources = @() }

            # Act & Assert
            { Write-ProgramPluginSetting -Settings $settings -SettingsPath "C:\nonexistent\dir\Settings.json" } | Should -Throw
        }
    }
}

Describe "Update-ProgramPluginConfig" {
    Context "When configuring with default suffixes" {
        It "Should add source directories and enable bat, cmd, url suffixes" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "FullTest.json"
            $initialSettings = @{
                LastIndexTime            = "2026-02-08T11:09:21.5261541+01:00"
                ProgramSources           = @()
                DisabledProgramSources   = @()
                CustomSuffixes           = @()
                CustomProtocols          = @()
                BuiltinSuffixesStatus    = @{ exe = $true; "appref-ms" = $true; lnk = $true }
                BuiltinProtocolsStatus   = @{ steam = $true; epic = $true; http = $false }
                UseCustomSuffixes        = $false
                UseCustomProtocols       = $false
                EnableStartMenuSource    = $true
                EnableDescription        = $false
                HideAppsPath             = $true
                HideUninstallers         = $false
                EnableRegistrySource     = $true
                EnablePathSource         = $false
                EnableUWP                = $true
                HideDuplicatedWindowsApp = $false
            }
            $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

            $directories = @("C:\Users\test\shortcuts\links")

            # Act
            Update-ProgramPluginConfig -SettingsPath $settingsPath -Directories $directories

            # Assert
            $result = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            $result.ProgramSources | Should -HaveCount 1
            $result.ProgramSources[0].Location | Should -Be "C:\Users\test\shortcuts\links"
            $result.CustomSuffixes | Should -Contain "bat"
            $result.CustomSuffixes | Should -Contain "cmd"
            $result.CustomSuffixes | Should -Contain "url"
            $result.UseCustomSuffixes | Should -BeTrue
            # Boolean settings that must be set to true
            $result.BuiltinProtocolsStatus.http | Should -BeTrue
            $result.EnablePathSource | Should -BeTrue
            $result.HideDuplicatedWindowsApp | Should -BeTrue
        }
    }

    Context "When boolean settings are already true" {
        It "Should report no change" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "BoolAlready.json"
            $initialSettings = @{
                ProgramSources           = @(
                    @{ Location = "C:\dir1"; Name = "dir1"; Enabled = $true; UniqueIdentifier = "dir1" }
                )
                DisabledProgramSources   = @()
                CustomSuffixes           = @("bat", "cmd", "url")
                UseCustomSuffixes        = $true
                BuiltinProtocolsStatus   = @{ steam = $true; epic = $true; http = $true }
                EnablePathSource         = $true
                HideDuplicatedWindowsApp = $true
            }
            $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
            $backupPath = "$settingsPath.bak"
            if (Test-Path $backupPath) { Remove-Item $backupPath }

            # Act
            Update-ProgramPluginConfig -SettingsPath $settingsPath -Directories @("C:\dir1")

            # Assert - no backup means no write occurred
            $backupPath | Should -Not -Exist
        }
    }

    Context "When called with multiple directories" {
        It "Should add all directories" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "MultiDir.json"
            $initialSettings = @{
                ProgramSources         = @()
                DisabledProgramSources = @()
                CustomSuffixes         = @()
                UseCustomSuffixes      = $false
            }
            $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

            $directories = @("C:\dir1", "C:\dir2")

            # Act
            Update-ProgramPluginConfig -SettingsPath $settingsPath -Directories $directories

            # Assert
            $result = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            $result.ProgramSources | Should -HaveCount 2
        }
    }

    Context "When called idempotently (multiple times)" {
        It "Should not duplicate sources or suffixes" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "Idempotent.json"
            $initialSettings = @{
                ProgramSources         = @()
                DisabledProgramSources = @()
                CustomSuffixes         = @()
                UseCustomSuffixes      = $false
            }
            $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

            $directories = @("C:\dir1")

            # Act - run twice
            Update-ProgramPluginConfig -SettingsPath $settingsPath -Directories $directories
            Update-ProgramPluginConfig -SettingsPath $settingsPath -Directories $directories

            # Assert
            $result = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            $result.ProgramSources | Should -HaveCount 1
            $result.CustomSuffixes | Should -HaveCount 3
            $result.CustomSuffixes | Should -Contain "bat"
            $result.CustomSuffixes | Should -Contain "cmd"
            $result.CustomSuffixes | Should -Contain "url"
        }
    }

    Context "When already fully configured" {
        It "Should not write the file (no backup created)" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "NoWrite.json"
            $initialSettings = @{
                ProgramSources           = @(
                    @{ Location = "C:\dir1"; Name = "dir1"; Enabled = $true; UniqueIdentifier = "dir1" }
                )
                DisabledProgramSources   = @()
                CustomSuffixes           = @("bat", "cmd", "url")
                UseCustomSuffixes        = $true
                BuiltinProtocolsStatus   = @{ steam = $true; epic = $true; http = $true }
                EnablePathSource         = $true
                HideDuplicatedWindowsApp = $true
            }
            $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
            $backupPath = "$settingsPath.bak"

            # Remove any pre-existing backup
            if (Test-Path $backupPath) { Remove-Item $backupPath }

            # Act
            Update-ProgramPluginConfig -SettingsPath $settingsPath -Directories @("C:\dir1")

            # Assert - no backup means no write occurred
            $backupPath | Should -Not -Exist
        }
    }

    Context "When preserving existing settings" {
        It "Should not modify unrelated settings" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "Preserve.json"
            $initialSettings = @{
                LastIndexTime            = "2026-02-08T11:09:21.5261541+01:00"
                ProgramSources           = @()
                DisabledProgramSources   = @()
                CustomSuffixes           = @()
                CustomProtocols          = @()
                BuiltinSuffixesStatus    = @{ exe = $true; "appref-ms" = $true; lnk = $true }
                BuiltinProtocolsStatus   = @{ steam = $true; epic = $true; http = $false }
                UseCustomSuffixes        = $false
                UseCustomProtocols       = $false
                EnableStartMenuSource    = $true
                EnableDescription        = $false
                HideAppsPath             = $true
                HideUninstallers         = $false
                EnableRegistrySource     = $true
                EnablePathSource         = $false
                EnableUWP                = $true
                HideDuplicatedWindowsApp = $false
            }
            $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

            # Act
            Update-ProgramPluginConfig -SettingsPath $settingsPath -Directories @("C:\test")

            # Assert
            $result = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            $result.EnableStartMenuSource | Should -BeTrue
            $result.EnableRegistrySource | Should -BeTrue
            $result.EnableUWP | Should -BeTrue
            $result.HideAppsPath | Should -BeTrue
            $result.BuiltinSuffixesStatus.exe | Should -BeTrue
        }
    }

    Context "When adding suffixes alongside existing custom suffixes" {
        It "Should merge with existing suffixes without removing any" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "MergeSuffix.json"
            $initialSettings = @{
                ProgramSources         = @()
                DisabledProgramSources = @()
                CustomSuffixes         = @("ps1")
                UseCustomSuffixes      = $true
            }
            $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

            # Act
            Update-ProgramPluginConfig -SettingsPath $settingsPath -Directories @("C:\test")

            # Assert
            $result = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            $result.CustomSuffixes | Should -HaveCount 4
            $result.CustomSuffixes | Should -Contain "ps1"
            $result.CustomSuffixes | Should -Contain "bat"
            $result.CustomSuffixes | Should -Contain "cmd"
            $result.CustomSuffixes | Should -Contain "url"
        }
    }

    Context "When preserving existing ProgramSources" {
        It "Should not remove existing sources when adding new ones" {
            # Arrange
            $settingsPath = Join-Path $TestDrive "PreserveSources.json"
            $initialSettings = @{
                ProgramSources         = @(
                    @{
                        Location         = "C:\existing"
                        Name             = "existing"
                        Enabled          = $true
                        UniqueIdentifier = "c:\existing"
                    }
                )
                DisabledProgramSources = @()
                CustomSuffixes         = @("bat", "cmd", "url")
                UseCustomSuffixes      = $true
            }
            $initialSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

            # Act
            Update-ProgramPluginConfig -SettingsPath $settingsPath -Directories @("C:\new")

            # Assert
            $result = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
            $result.ProgramSources | Should -HaveCount 2
            $result.ProgramSources[0].Location | Should -Be "C:\existing"
            $result.ProgramSources[0].UniqueIdentifier | Should -Be "c:\existing"
            $result.ProgramSources[1].Location | Should -Be "C:\new"
        }
    }
}
