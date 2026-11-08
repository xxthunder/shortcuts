#Requires -Version 7.4

<#
.SYNOPSIS
    Tests for bin/install.ps1 — self-contained installer (FEAT-004).
#>

BeforeAll {
    . "$PSScriptRoot\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    $script:installScript = Join-Path $PSScriptRoot 'install.ps1'
}

AfterAll {
    Stop-SutIsolation
}

Describe 'Install-Scoop' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    Context 'when Scoop is already installed' {
        BeforeAll {
            Mock Get-Command { return @{ Name = 'scoop' } } -ParameterFilter { $Name -eq 'scoop' }
            Mock Invoke-CommandLine {}
            Mock Invoke-Expression {}
            Mock Invoke-RestMethod {}
        }

        It 'skips installation' {
            Install-Scoop
            Should -Not -Invoke Invoke-RestMethod
            Should -Not -Invoke Invoke-Expression
        }
    }

    Context 'when Scoop is not installed' {
        BeforeAll {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'scoop' }
            Mock Invoke-RestMethod { 'echo "scoop installer"' }
            Mock Invoke-Expression {}
            Mock Initialize-EnvPath {}
        }

        It 'downloads and runs Scoop installer' {
            Install-Scoop
            Should -Invoke Invoke-RestMethod -Times 1
            Should -Invoke Invoke-Expression -Times 1
        }

        It 'refreshes PATH after installation' {
            Install-Scoop
            Should -Invoke Initialize-EnvPath -Times 1
        }
    }
}

Describe 'Install-ScoopDependency' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    BeforeEach {
        Mock Invoke-CommandLine {}
    }

    It 'installs dependencies in the correct order: lessmsi, 7zip, innounp, dark' {
        $script:order = @()
        Mock Invoke-CommandLine {
            $script:order += $CommandLine
        }

        Install-ScoopDependency

        $script:order.Count | Should -Be 4
        $script:order[0] | Should -Match 'lessmsi'
        $script:order[1] | Should -Match '7zip'
        $script:order[2] | Should -Match 'innounp'
        $script:order[3] | Should -Match 'dark'
    }

    It 'uses StopAtError false so missing deps do not abort' {
        Mock Invoke-CommandLine {} -ParameterFilter { $StopAtError -eq $false }

        Install-ScoopDependency

        Should -Invoke Invoke-CommandLine -Times 4 -ParameterFilter { $StopAtError -eq $false }
    }
}

Describe 'Install-Git' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    Context 'when git is already in PATH' {
        BeforeAll {
            Mock Get-Command { return @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
            Mock Invoke-CommandLine {}
        }

        It 'skips installation' {
            Install-Git
            Should -Not -Invoke Invoke-CommandLine
        }
    }

    Context 'when git is not in PATH' {
        BeforeAll {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'git' }
            Mock Invoke-CommandLine {}
            Mock Initialize-EnvPath {}
        }

        It 'installs git via scoop' {
            Install-Git
            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like '*scoop install git*'
            }
        }

        It 'refreshes PATH after installation' {
            Install-Git
            Should -Invoke Initialize-EnvPath -Times 1
        }
    }
}

Describe 'Install-MandatoryToolset' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    BeforeEach {
        Mock Invoke-CommandLine {}
    }

    It 'imports scoop_mandatory.json' {
        Install-MandatoryToolset
        Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
            $CommandLine -like '*scoop import*scoop_mandatory.json*'
        }
    }
}

Describe 'Install-OptionalToolset' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    BeforeEach {
        Mock Invoke-CommandLine {}
    }

    Context 'in CI environment' {
        BeforeAll {
            Mock Test-RunningInCIorTestEnvironment { return $true }
        }

        It 'skips optional tools without prompting' {
            Install-OptionalToolset
            Should -Not -Invoke Invoke-CommandLine
        }
    }

    Context 'in interactive environment without -Force' {
        BeforeAll {
            Mock Test-RunningInCIorTestEnvironment { return $false }
            Mock Get-UserConfirmation { return $true }
        }

        It 'prompts user and installs when confirmed' {
            Install-OptionalToolset
            Should -Invoke Get-UserConfirmation -Times 1
            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like '*scoop import*scoop_optional.json*'
            }
        }
    }

    Context 'in interactive environment when user declines' {
        BeforeAll {
            Mock Test-RunningInCIorTestEnvironment { return $false }
            Mock Get-UserConfirmation { return $false }
        }

        It 'does not install optional tools' {
            Install-OptionalToolset
            Should -Not -Invoke Invoke-CommandLine
        }
    }

    Context 'with -Force switch' {
        BeforeAll {
            Mock Test-RunningInCIorTestEnvironment { return $false }
            Mock Get-UserConfirmation {}
        }

        It 'installs without prompting' {
            Install-OptionalToolset -Force
            Should -Not -Invoke Get-UserConfirmation
            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like '*scoop import*scoop_optional.json*'
            }
        }
    }
}

Describe 'Install-PwshSpectreDependency' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    Context 'when PwshSpectreConsole is already installed' {
        BeforeAll {
            Mock Get-InstalledModule { return @{ Name = 'PwshSpectreConsole'; Version = '2.1.0' } } -ParameterFilter { $Name -eq 'PwshSpectreConsole' }
            Mock Install-Module {}
            Mock Write-Host {}
        }

        It 'skips installation' {
            Install-PwshSpectreDependency
            Should -Not -Invoke Install-Module
        }
    }

    Context 'when PwshSpectreConsole is not installed' {
        BeforeAll {
            Mock Get-InstalledModule { $null } -ParameterFilter { $Name -eq 'PwshSpectreConsole' }
            Mock Get-PackageProvider { return @{ Name = 'NuGet' } } -ParameterFilter { $Name -eq 'NuGet' }
            Mock Install-Module {}
            Mock Write-Host {}
        }

        It 'installs PwshSpectreConsole from PSGallery' {
            Install-PwshSpectreDependency
            Should -Invoke Install-Module -Times 1 -ParameterFilter {
                $Name -eq 'PwshSpectreConsole' -and
                $Repository -eq 'PSGallery' -and
                $Scope -eq 'CurrentUser'
            }
        }
    }

    Context 'when NuGet provider is missing' {
        BeforeAll {
            Mock Get-InstalledModule { $null } -ParameterFilter { $Name -eq 'PwshSpectreConsole' }
            Mock Get-PackageProvider { $null } -ParameterFilter { $Name -eq 'NuGet' }
            Mock Install-PackageProvider {}
            Mock Install-Module {}
            Mock Write-Host {}
        }

        It 'installs NuGet provider before the module' {
            Install-PwshSpectreDependency
            Should -Invoke Install-PackageProvider -Times 1 -ParameterFilter {
                $Name -eq 'NuGet' -and
                $Scope -eq 'CurrentUser'
            }
            Should -Invoke Install-Module -Times 1
        }
    }
}

Describe 'New-Shortcut' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    It 'creates a .lnk shortcut with the correct target path' {
        $script:savedPath = $null
        $mockShortcut = [PSCustomObject]@{ TargetPath = '' }
        $mockShortcut | Add-Member -MemberType ScriptMethod -Name Save -Value { $script:savedPath = $this.TargetPath }
        $mockShell = [PSCustomObject]@{}
        $mockShell | Add-Member -MemberType ScriptMethod -Name CreateShortcut -Value { param([string]$lnkPath) $script:createdLnk = $lnkPath; $mockShortcut } -Force
        Mock New-Object { $mockShell } -ParameterFilter { $ComObject -eq 'WScript.Shell' }

        New-Shortcut -target 'C:\test.lnk' -path 'C:\target.exe'

        $mockShortcut.TargetPath | Should -Be 'C:\target.exe'
    }

    It 'supports -WhatIf and does not create shortcut' {
        Mock New-Object {}

        New-Shortcut -target 'C:\test.lnk' -path 'C:\target.exe' -WhatIf

        Should -Not -Invoke New-Object
    }
}

Describe 'New-StartupShortcut' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    It 'delegates to New-Shortcut with the startup folder path' {
        Mock New-Shortcut {}

        New-StartupShortcut -Name 'myapp' -path 'C:\myapp.exe'

        $expectedDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
        $expectedLnk = Join-Path $expectedDir 'myapp.lnk'
        Should -Invoke New-Shortcut -Times 1 -ParameterFilter {
            $target -eq $expectedLnk -and $path -eq 'C:\myapp.exe'
        }
    }

    It 'supports -WhatIf and does not delegate' {
        Mock New-Shortcut {}

        New-StartupShortcut -Name 'myapp' -path 'C:\myapp.exe' -WhatIf

        Should -Not -Invoke New-Shortcut
    }
}

Describe 'Start-Launcher' {
    BeforeAll {
        . $script:installScript -InPlace
        $script:originalUserProfile = $Env:USERPROFILE
    }

    BeforeEach {
        $Env:USERPROFILE = Join-Path $TestDrive 'home'
        Mock Start-Process {}
    }

    AfterEach {
        $Env:USERPROFILE = $script:originalUserProfile
    }

    AfterAll {
        $Env:USERPROFILE = $script:originalUserProfile
    }

    It 'starts PowerToys only outside CI' {
        Mock Test-RunningInCIorTestEnvironment { $false }

        Start-Launcher

        Should -Invoke Start-Process -Times 1 -Exactly
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq (Join-Path $Env:USERPROFILE 'scoop\apps\powertoys\current\PowerToys.exe')
        }
        Should -Invoke Start-Process -Times 0 -Exactly -ParameterFilter {
            $FilePath -like '*keypirinha*'
        }
    }

    It 'starts no launcher in CI' {
        Mock Test-RunningInCIorTestEnvironment { $true }

        Start-Launcher

        Should -Invoke Start-Process -Times 0
    }
}

Describe 'scoop_mandatory.json' {
    BeforeAll {
        $script:manifest = Get-Content (Join-Path $PSScriptRoot '..\scoop_mandatory.json') -Raw | ConvertFrom-Json
    }

    It 'lists powertoys from the extras bucket' {
        $entries = @($script:manifest.apps | Where-Object { $_.Name -eq 'powertoys' })

        $entries | Should -HaveCount 1
        $entries[0].Source | Should -Be 'extras'
    }

    It 'lists no keypirinha entry' {
        @($script:manifest.apps | Where-Object { $_.Name -eq 'keypirinha' }) | Should -HaveCount 0
    }
}

Describe 'Set-CommandPaletteHotkey' {
    BeforeAll {
        . $script:installScript -InPlace
        $script:originalLocalAppData = $Env:LOCALAPPDATA
    }

    BeforeEach {
        $script:settings = Join-Path $TestDrive 'cp\LocalState\settings.json'
        Remove-Item (Split-Path $script:settings -Parent) -Recurse -Force -ErrorAction SilentlyContinue
    }

    AfterEach {
        $Env:LOCALAPPDATA = $script:originalLocalAppData
    }

    AfterAll {
        $Env:LOCALAPPDATA = $script:originalLocalAppData
    }

    It 'creates the directory and a file holding only Hotkey when there is none' {
        Set-CommandPaletteHotkey -SettingsPath $script:settings

        $json = Get-Content $script:settings -Raw | ConvertFrom-Json
        @($json.PSObject.Properties.Name) | Should -Be @('Hotkey')
        $json.Hotkey.win | Should -BeFalse
        $json.Hotkey.ctrl | Should -BeFalse
        $json.Hotkey.alt | Should -BeTrue
        $json.Hotkey.shift | Should -BeFalse
        $json.Hotkey.code | Should -Be 32
        $json.Hotkey.key | Should -Be ''
    }

    It 'sets Alt+Space and keeps every other key of an existing file' {
        New-Item -ItemType Directory -Path (Split-Path $script:settings -Parent) -Force | Out-Null
        Set-Content -Path $script:settings -Value '{"Hotkey":{"win":true,"ctrl":false,"alt":true,"shift":false,"code":32,"key":""},"ShowAppDetails":true,"Dock":{"Enabled":true}}'

        Set-CommandPaletteHotkey -SettingsPath $script:settings

        $json = Get-Content $script:settings -Raw | ConvertFrom-Json
        $json.Hotkey.win | Should -BeFalse
        $json.Hotkey.ctrl | Should -BeFalse
        $json.Hotkey.alt | Should -BeTrue
        $json.Hotkey.shift | Should -BeFalse
        $json.Hotkey.code | Should -Be 32
        $json.Hotkey.key | Should -Be ''
        $json.ShowAppDetails | Should -BeTrue
        $json.Dock.Enabled | Should -BeTrue
    }

    It 'writes nothing with -WhatIf' {
        Set-CommandPaletteHotkey -SettingsPath $script:settings -WhatIf

        Test-Path $script:settings | Should -BeFalse
    }

    It 'leaves an existing file unchanged with -WhatIf' {
        New-Item -ItemType Directory -Path (Split-Path $script:settings -Parent) -Force | Out-Null
        $original = '{"Hotkey":{"win":true,"ctrl":false,"alt":true,"shift":false,"code":32,"key":""}}'
        Set-Content -Path $script:settings -Value $original

        Set-CommandPaletteHotkey -SettingsPath $script:settings -WhatIf

        (Get-Content $script:settings -Raw).Trim() | Should -Be $original
    }

    It 'treats an empty file as no file' {
        New-Item -ItemType Directory -Path (Split-Path $script:settings -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllBytes($script:settings, [byte[]]@())

        Set-CommandPaletteHotkey -SettingsPath $script:settings

        $json = Get-Content $script:settings -Raw | ConvertFrom-Json
        $json.Hotkey.alt | Should -BeTrue
        $json.Hotkey.code | Should -Be 32
    }

    It 'treats a whitespace-only file as no file' {
        New-Item -ItemType Directory -Path (Split-Path $script:settings -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllText($script:settings, "  `r`n ")

        Set-CommandPaletteHotkey -SettingsPath $script:settings

        $json = Get-Content $script:settings -Raw | ConvertFrom-Json
        $json.Hotkey.alt | Should -BeTrue
        $json.Hotkey.code | Should -Be 32
    }

    It 'leaves a malformed file untouched and warns' {
        New-Item -ItemType Directory -Path (Split-Path $script:settings -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllText($script:settings, '{ not json')
        $before = [System.IO.File]::ReadAllBytes($script:settings)

        # Called directly (not in a scriptblock) so $w lands in this scope; a throw still fails the It.
        Set-CommandPaletteHotkey -SettingsPath $script:settings -WarningVariable w -WarningAction SilentlyContinue

        [System.IO.File]::ReadAllBytes($script:settings) | Should -Be $before
        $w | Should -Not -BeNullOrEmpty
    }

    It 'leaves a file whose root is not an object untouched and warns' {
        New-Item -ItemType Directory -Path (Split-Path $script:settings -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllText($script:settings, '[1,2]')
        $before = [System.IO.File]::ReadAllBytes($script:settings)

        # Called directly (not in a scriptblock) so $w lands in this scope; a throw still fails the It.
        Set-CommandPaletteHotkey -SettingsPath $script:settings -WarningVariable w -WarningAction SilentlyContinue

        [System.IO.File]::ReadAllBytes($script:settings) | Should -Be $before
        $w | Should -Not -BeNullOrEmpty
    }

    It 'writes UTF-8 without a byte order mark' {
        Set-CommandPaletteHotkey -SettingsPath $script:settings

        $bytes = [System.IO.File]::ReadAllBytes($script:settings)
        ($bytes[0..2] -join ',') | Should -Not -Be '239,187,191'
    }

    It 'keeps non-ASCII settings intact' {
        $alias = 'M' + [char]0xFC + 'ller ' + [char]0x2713 + ' ' + [char]0x65E5 + [char]0x672C
        New-Item -ItemType Directory -Path (Split-Path $script:settings -Parent) -Force | Out-Null
        $text = '{"Alias":"' + $alias + '","Hotkey":{"win":true,"ctrl":false,"alt":true,"shift":false,"code":32,"key":""}}'
        [System.IO.File]::WriteAllText($script:settings, $text, (New-Object System.Text.UTF8Encoding $false))

        Set-CommandPaletteHotkey -SettingsPath $script:settings

        $json = [System.IO.File]::ReadAllText($script:settings, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json
        $json.Alias | Should -BeExactly $alias
        $json.Hotkey.alt | Should -BeTrue
        $json.Hotkey.win | Should -BeFalse
    }

    It 'defaults to the Command Palette package settings under LOCALAPPDATA' {
        $Env:LOCALAPPDATA = Join-Path $TestDrive 'local'

        Set-CommandPaletteHotkey

        $expected = Join-Path $Env:LOCALAPPDATA 'Packages\Microsoft.CommandPalette_8wekyb3d8bbwe\LocalState\settings.json'
        Test-Path $expected | Should -BeTrue
        (Get-Content $expected -Raw | ConvertFrom-Json).Hotkey.alt | Should -BeTrue
    }
}

Describe 'Invoke-Install' {
    BeforeAll {
        . $script:installScript -InPlace
        $script:originalUserProfile = $Env:USERPROFILE
    }

    BeforeEach {
        $Env:USERPROFILE = Join-Path $TestDrive 'home'
        $script:calls = [System.Collections.Generic.List[string]]::new()
        foreach ($step in 'Install-Scoop', 'Install-ScoopDependency', 'Install-Git', 'Install-MandatoryToolset',
            'Install-PwshSpectreDependency', 'Install-OptionalToolset', 'Set-CommandPaletteHotkey', 'Start-Launcher') {
            $name = $step
            $calls = $script:calls
            Mock $name { $calls.Add($name) }.GetNewClosure()
        }
        Mock New-Directory { $script:calls.Add('New-Directory') }
        Mock New-StartupShortcut { $script:calls.Add('New-StartupShortcut') }
    }

    AfterEach {
        $Env:USERPROFILE = $script:originalUserProfile
    }

    AfterAll {
        $Env:USERPROFILE = $script:originalUserProfile
    }

    Context 'with autohotkey installed' {
        BeforeEach {
            Mock Get-Command { @{ Name = 'autohotkey' } } -ParameterFilter { $Name -eq 'autohotkey' }
        }

        It 'runs the steps in order' {
            Invoke-Install -ShortcutsDir 'C:\sc'

            $script:calls | Should -Be @(
                'Install-Scoop', 'Install-ScoopDependency', 'Install-Git', 'Install-MandatoryToolset',
                'Install-PwshSpectreDependency', 'Install-OptionalToolset', 'New-Directory',
                'New-StartupShortcut', 'Set-CommandPaletteHotkey', 'Start-Launcher')
        }

        It 'creates the private shortcuts directory' {
            Invoke-Install -ShortcutsDir 'C:\sc'

            Should -Invoke New-Directory -Times 1 -Exactly -ParameterFilter {
                $Path -eq "$Env:USERPROFILE\shortcuts_private"
            }
        }

        It 'creates the AutoHotkey startup shortcut once' {
            Invoke-Install -ShortcutsDir 'C:\sc'

            Should -Invoke New-StartupShortcut -Times 1 -Exactly -ParameterFilter {
                $name -eq 'shortcuts_hotkeys' -and $path -eq 'C:\sc\tools\AutoHotKey\hotkeys.cmd'
            }
        }

        It 'no longer has Copy-Config' {
            Get-Command Copy-Config -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }

    Context 'without autohotkey' {
        BeforeEach {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'autohotkey' }
        }

        It 'creates no startup shortcut' {
            Invoke-Install -ShortcutsDir 'C:\sc'

            Should -Invoke New-StartupShortcut -Times 0 -Exactly
        }

        It 'still configures the hotkey and starts the launcher last' {
            Invoke-Install -ShortcutsDir 'C:\sc'

            $script:calls[-2..-1] | Should -Be @('Set-CommandPaletteHotkey', 'Start-Launcher')
        }
    }
}
