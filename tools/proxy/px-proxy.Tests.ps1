#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.2.0'}

<#
.SYNOPSIS
    Unit tests for px-proxy.ps1

.DESCRIPTION
    Tests the local px authenticating proxy management tool following a TDD
    approach. External side effects (Scoop, processes, web requests, klist) are
    mocked; the px data directory is redirected to TestDrive.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Mock function parameters are required by the interface but may not be used in test implementations')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    # Prevent auto-execution of main when dot-sourcing
    $env:PXPROXY_LIBRARY_MODE = '1'

    Start-SutIsolation
    . "$PSScriptRoot\px-proxy.ps1"

    $script:TestDataDir = Join-Path $TestDrive '.config\px'

    # SC-067: no unit test may reach the real Startup folder. Every logon start
    # path goes through Get-AutostartPath, so this one file-level mock covers
    # every block, including blocks added later.
    Mock Get-AutostartPath { Join-Path $TestDrive "$Name.lnk" }
}

AfterAll {
    Remove-Item Env:\PXPROXY_LIBRARY_MODE -ErrorAction SilentlyContinue
    Stop-SutIsolation
}

Describe "Test safety" {
    It "redirects the logon start to TestDrive in every block" {
        Get-AutostartPath -Name 'px-proxy' | Should -Be (Join-Path $TestDrive 'px-proxy.lnk')
    }
}

Describe "Get-PxDataDir" {
    <#
    @need test: Get-PxDataDir.returns the px folder in .config under the user profile
    :id: TEST_PX_DATA_DIR_UNDER_PROFILE
    :tests: REQ_PX_FILES
    @endneed
    #>
    It "returns the px folder in .config under the user profile" {
        Get-PxDataDir | Should -BeLike '*\.config\px'
    }
}

Describe "Get-PxConfigPath" {
    <#
    @need test: Get-PxConfigPath.returns px.ini inside the data directory
    :id: TEST_PX_CONFIG_PATH_IN_DATA_DIR
    :tests: REQ_PX_FILES
    @endneed
    #>
    It "returns px.ini inside the data directory" {
        Mock Get-PxDataDir { 'C:\fake\px' }
        Get-PxConfigPath | Should -Be 'C:\fake\px\px.ini'
    }
}

Describe "Test-PxInstalled" {
    <#
    @need test: Test-PxInstalled.returns true when px command is found
    :id: TEST_PX_INSTALLED_TRUE_WHEN_FOUND
    :tests: REQ_PX_INSTALL
    @endneed
    #>
    It "returns true when px command is found" {
        Mock Get-Command { [pscustomobject]@{ Source = 'C:\scoop\shims\px.exe' } } -ParameterFilter { $Name -eq 'px' }
        Test-PxInstalled | Should -BeTrue
    }

    <#
    @need test: Test-PxInstalled.returns false when px command is missing
    :id: TEST_PX_INSTALLED_FALSE_WHEN_MISSING
    :tests: REQ_PX_INSTALL
    @endneed
    #>
    It "returns false when px command is missing" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'px' }
        Test-PxInstalled | Should -BeFalse
    }
}

Describe "Get-PxExecutable" {
    <#
    @need test: Get-PxExecutable.prefers pxw when Windowless is requested and pxw exists
    :id: TEST_PX_EXE_PREFERS_PXW
    :tests: REQ_PX_START
    @endneed
    #>
    It "prefers pxw when Windowless is requested and pxw exists" {
        Mock Get-Command { [pscustomobject]@{ Source = 'C:\scoop\shims\pxw.exe' } } -ParameterFilter { $Name -eq 'pxw' }
        Get-PxExecutable -Windowless | Should -Be 'C:\scoop\shims\pxw.exe'
    }

    <#
    @need test: Get-PxExecutable.falls back to px when the requested variant shim is missing
    :id: TEST_PX_EXE_FALLS_BACK_TO_PX
    :tests: REQ_PX_START
    @endneed
    #>
    It "falls back to px when the requested variant shim is missing" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pxw' }
        Mock Get-Command { [pscustomobject]@{ Source = 'C:\scoop\shims\px.exe' } } -ParameterFilter { $Name -eq 'px' }
        Mock Test-Path { $false }
        Get-PxExecutable -Windowless | Should -Be 'C:\scoop\shims\px.exe'
    }

    <#
    @need test: Get-PxExecutable.returns null when no px executable exists
    :id: TEST_PX_EXE_NULL_WITHOUT_PX
    :tests: REQ_PX_START
    @endneed
    #>
    It "returns null when no px executable exists" {
        Mock Get-Command { $null }
        Get-PxExecutable | Should -BeNullOrEmpty
    }

    <#
    @need test: Get-PxExecutable.uses the pxw.exe sitting next to px when the shim is missing
    :id: TEST_PX_EXE_PXW_NEXT_TO_PX
    :tests: REQ_PX_START
    @endneed
    #>
    It "uses the pxw.exe sitting next to px when the shim is missing" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pxw' }
        Mock Get-Command { [pscustomobject]@{ Source = 'C:\scoop\apps\px\current\px.exe' } } -ParameterFilter { $Name -eq 'px' }
        Mock Test-Path { $true }
        Get-PxExecutable -Windowless | Should -Be 'C:\scoop\apps\px\current\pxw.exe'
    }
}

Describe "Test-PxRunning" {
    <#
    @need test: Test-PxRunning.returns true when a px process is present
    :id: TEST_PX_RUNNING_TRUE
    :tests: REQ_PX_START
    @endneed
    #>
    It "returns true when a px process is present" {
        Mock Get-Process { @([pscustomobject]@{ Id = 42 }) }
        Test-PxRunning | Should -BeTrue
    }

    <#
    @need test: Test-PxRunning.returns false when no px process is present
    :id: TEST_PX_RUNNING_FALSE
    :tests: REQ_PX_START
    @endneed
    #>
    It "returns false when no px process is present" {
        Mock Get-Process { $null }
        Test-PxRunning | Should -BeFalse
    }
}

Describe "Get-PxUserConfigPath" {
    <#
    @need test: Get-PxUserConfigPath.returns px-user.ini inside the data directory
    :id: TEST_PX_USER_CONFIG_PATH_IN_DATA_DIR
    :tests: REQ_PX_FILES
    @endneed
    #>
    It "returns px-user.ini inside the data directory" {
        Mock Get-PxDataDir { 'C:\fake\px' }
        Get-PxUserConfigPath | Should -Be 'C:\fake\px\px-user.ini'
    }
}

Describe "Get-PxUserSetting" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        New-Item -ItemType Directory -Path $script:TestDataDir -Force | Out-Null
        Remove-Item (Join-Path $script:TestDataDir 'px-user.ini') -ErrorAction SilentlyContinue
    }

    <#
    @need test: Get-PxUserSetting.returns an empty map when the user file is absent
    :id: TEST_PX_USER_SETTING_EMPTY_WHEN_ABSENT
    :tests: REQ_PX_SETTINGS
    @endneed
    #>
    It "returns an empty map when the user file is absent" {
        (Get-PxUserSetting).Count | Should -Be 0
    }

    <#
    @need test: Get-PxUserSetting.parses [settings] keys and ignores comments and blank lines
    :id: TEST_PX_USER_SETTING_PARSES_SETTINGS
    :tests: REQ_PX_SETTINGS
    @endneed
    #>
    It "parses [settings] keys and ignores comments and blank lines" {
        $userConfig = @'
# a leading comment
[settings]
log = 3
; semicolon comment
workers = 12

threads = 40
'@
        Set-Content -Path (Get-PxUserConfigPath) -Value $userConfig -Encoding ascii

        $settings = Get-PxUserSetting
        $settings.Count | Should -Be 3
        $settings['log'] | Should -Be '3'
        $settings['workers'] | Should -Be '12'
        $settings['threads'] | Should -Be '40'
    }

    <#
    @need test: Get-PxUserSetting.strips inline comments from values
    :id: TEST_PX_USER_SETTING_STRIPS_INLINE_COMMENTS
    :tests: REQ_PX_SETTINGS
    @endneed
    #>
    It "strips inline comments from values" {
        $userConfig = @'
[settings]
log = 0   # inline note
workers = 12 ; another
'@
        Set-Content -Path (Get-PxUserConfigPath) -Value $userConfig -Encoding ascii

        $settings = Get-PxUserSetting
        $settings['log'] | Should -Be '0'
        $settings['workers'] | Should -Be '12'
    }

    <#
    @need test: Get-PxUserSetting.ignores keys outside the [settings] section
    :id: TEST_PX_USER_SETTING_IGNORES_OTHER_SECTIONS
    :tests: REQ_PX_SETTINGS, REQ_PX_ENDPOINT
    @endneed
    #>
    It "ignores keys outside the [settings] section" {
        $userConfig = @'
[proxy]
server = evil.corp:1234
listen = 0.0.0.0

[settings]
log = 3
'@
        Set-Content -Path (Get-PxUserConfigPath) -Value $userConfig -Encoding ascii

        $settings = Get-PxUserSetting
        $settings.ContainsKey('server') | Should -BeFalse
        $settings.ContainsKey('listen') | Should -BeFalse
        $settings['log'] | Should -Be '3'
    }
}

Describe "New-PxUserConfigTemplate" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock New-Directory { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        New-Item -ItemType Directory -Path $script:TestDataDir -Force | Out-Null
        Remove-Item (Join-Path $script:TestDataDir 'px-user.ini') -ErrorAction SilentlyContinue
    }

    <#
    @need test: New-PxUserConfigTemplate.seeds a fully commented template when the file is absent
    :id: TEST_PX_TEMPLATE_SEEDS_COMMENTED
    :tests: REQ_PX_USER_TEMPLATE
    @endneed
    #>
    It "seeds a fully commented template when the file is absent" {
        New-PxUserConfigTemplate
        $path = Get-PxUserConfigPath
        Test-Path $path | Should -BeTrue
        $content = Get-Content -Raw $path
        $content | Should -Match '\[settings\]'
        # Every overridable key ships commented out so an untouched template
        # behaves exactly like no file (pure defaults).
        $content | Should -Match '(?m)^#\s*log\b'
        $content | Should -Match '(?m)^#\s*workers\b'
        $content | Should -Match '(?m)^#\s*proxyreload = 60'
        $content | Should -Match '(?m)^#\s*foreground = 0'
        (Get-PxUserSetting).Count | Should -Be 0
    }

    <#
    @need test: New-PxUserConfigTemplate.never overwrites an existing user file
    :id: TEST_PX_TEMPLATE_NEVER_OVERWRITES
    :tests: REQ_PX_USER_TEMPLATE
    @endneed
    #>
    It "never overwrites an existing user file" {
        Set-Content -Path (Get-PxUserConfigPath) -Value 'MINE' -Encoding ascii
        New-PxUserConfigTemplate
        Get-Content -Raw (Get-PxUserConfigPath) | Should -Match 'MINE'
    }
}

Describe "Write-PxConfig" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock New-Directory { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        New-Item -ItemType Directory -Path $script:TestDataDir -Force | Out-Null
        Remove-Item (Join-Path $script:TestDataDir 'px-user.ini') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $script:TestDataDir 'px.ini') -ErrorAction SilentlyContinue
    }

    <#
    @need test: Write-PxConfig.writes a px.ini with the resolved upstream proxy and default settings (log off)
    :id: TEST_PX_WRITE_CONFIG_DEFAULTS
    :tests: REQ_PX_ENDPOINT, REQ_PX_SETTINGS, REQ_PX_UPSTREAM
    @endneed
    #>
    It "writes a px.ini with the resolved upstream proxy and default settings (log off)" {
        $path = Write-PxConfig -UpstreamProxy 'up.corp:8080'
        $path | Should -Be (Join-Path $script:TestDataDir 'px.ini')
        $content = Get-Content -Raw $path
        $content | Should -Match 'server = up\.corp:8080'
        $content | Should -Match 'listen = 127\.0\.0\.1'
        $content | Should -Match 'port = 3128'
        $content | Should -Match 'log = 0'
        $content | Should -Match 'idle = 300'
        $content | Should -Match 'socktimeout = 300\.0'
        $content | Should -Match 'workers = 1'
        $content | Should -Match 'threads = 32'
        $content | Should -Match 'proxyreload = 60'
        $content | Should -Match 'foreground = 0'
    }

    <#
    @need test: Write-PxConfig.overwrites an existing config on each call
    :id: TEST_PX_WRITE_CONFIG_OVERWRITES
    :tests: REQ_PX_FILES
    @endneed
    #>
    It "overwrites an existing config on each call" {
        Write-PxConfig -UpstreamProxy 'first.corp:8080' | Out-Null
        $path = Write-PxConfig -UpstreamProxy 'second.corp:8080'
        $content = Get-Content -Raw $path
        $content | Should -Match 'server = second\.corp:8080'
        $content | Should -Not -Match 'first\.corp'
    }

    <#
    @need test: Write-PxConfig.applies user [settings] overrides over the built-in defaults
    :id: TEST_PX_WRITE_CONFIG_USER_OVERRIDES
    :tests: REQ_PX_SETTINGS
    @endneed
    #>
    It "applies user [settings] overrides over the built-in defaults" {
        $userConfig = @'
[settings]
log = 3
workers = 12
'@
        Set-Content -Path (Get-PxUserConfigPath) -Value $userConfig -Encoding ascii

        $content = Get-Content -Raw (Write-PxConfig -UpstreamProxy 'up.corp:8080')
        $content | Should -Match 'log = 3'
        $content | Should -Match 'workers = 12'
        # Untouched keys keep their defaults.
        $content | Should -Match 'threads = 32'
        $content | Should -Match 'idle = 300'
        $content | Should -Match 'socktimeout = 300\.0'
    }

    <#
    @need test: Write-PxConfig.keeps managed [proxy] keys even when the user file tries to set them
    :id: TEST_PX_WRITE_CONFIG_KEEPS_MANAGED_KEYS
    :tests: REQ_PX_ENDPOINT, REQ_PX_SETTINGS
    @endneed
    #>
    It "keeps managed [proxy] keys even when the user file tries to set them" {
        $userConfig = @'
[settings]
server = evil.corp:1234
listen = 0.0.0.0
port = 9999
log = 3
'@
        Set-Content -Path (Get-PxUserConfigPath) -Value $userConfig -Encoding ascii

        $content = Get-Content -Raw (Write-PxConfig -UpstreamProxy 'up.corp:8080')
        $content | Should -Match 'server = up\.corp:8080'
        $content | Should -Match 'listen = 127\.0\.0\.1'
        $content | Should -Match 'port = 3128'
        $content | Should -Not -Match '0\.0\.0\.0'
        $content | Should -Not -Match '9999'
        $content | Should -Not -Match 'evil'
        # A legitimate [settings] override still applies.
        $content | Should -Match 'log = 3'
    }

    <#
    @need test: Write-PxConfig.seeds the user template when it is absent
    :id: TEST_PX_WRITE_CONFIG_SEEDS_TEMPLATE
    :tests: REQ_PX_USER_TEMPLATE
    @endneed
    #>
    It "seeds the user template when it is absent" {
        Write-PxConfig -UpstreamProxy 'up.corp:8080' | Out-Null
        Test-Path (Get-PxUserConfigPath) | Should -BeTrue
    }

    <#
    @need test: Write-PxConfig.writes no upstream when no proxy host is given so px asks Windows on every request
    :id: TEST_PX_WRITE_CONFIG_NO_UPSTREAM
    :tests: REQ_PX_UPSTREAM
    @endneed
    #>
    It "writes no upstream when no proxy host is given so px asks Windows on every request" {
        $content = Get-Content -Raw (Write-PxConfig)
        $content | Should -Not -Match '(?m)^\s*server\s*='
        $content | Should -Not -Match '(?m)^\s*pac\s*='
        $content | Should -Match '(?m)^listen = 127\.0\.0\.1'
        $content | Should -Match '(?m)^port = 3128'
        $content | Should -Match '(?m)^proxyreload = 60'
        $content | Should -Match '(?m)^foreground = 0'
    }

    <#
    @need test: Write-PxConfig.writes no upstream when the proxy host is blank
    :id: TEST_PX_WRITE_CONFIG_BLANK_UPSTREAM
    :tests: REQ_PX_UPSTREAM
    @endneed
    #>
    It "writes no upstream when the proxy host is blank" {
        (Get-Content -Raw (Write-PxConfig -UpstreamProxy '   ')) | Should -Not -Match '(?m)^\s*server\s*='
    }

    <#
    @need test: Write-PxConfig.pins the trimmed proxy host as server
    :id: TEST_PX_WRITE_CONFIG_PINS_SERVER
    :tests: REQ_PX_UPSTREAM
    @endneed
    #>
    It "pins the trimmed proxy host as server" {
        $content = Get-Content -Raw (Write-PxConfig -UpstreamProxy ' up.corp:8080 ')
        $content | Should -Match '(?m)^server = up\.corp:8080\r?$'
        $content | Should -Match '(?m)^proxyreload = 60'
    }

    <#
    @need test: Write-PxConfig.drops a pinned server when rewritten without a proxy host
    :id: TEST_PX_WRITE_CONFIG_DROPS_PINNED_SERVER
    :tests: REQ_PX_UPSTREAM
    @endneed
    #>
    It "drops a pinned server when rewritten without a proxy host" {
        Write-PxConfig -UpstreamProxy 'old.corp:8080' | Out-Null
        (Get-Content -Raw (Write-PxConfig)) | Should -Not -Match 'old\.corp'
    }

    <#
    @need test: Write-PxConfig.lets px-user.ini override proxyreload and foreground each once
    :id: TEST_PX_WRITE_CONFIG_OVERRIDES_RELOAD_FOREGROUND
    :tests: REQ_PX_SETTINGS
    @endneed
    #>
    It "lets px-user.ini override proxyreload and foreground each once" {
        Set-Content -Path (Get-PxUserConfigPath) -Encoding ascii -Value "[settings]`nproxyreload = 30`nforeground = 1"
        $content = Get-Content -Raw (Write-PxConfig)
        $content | Should -Match '(?m)^proxyreload = 30'
        $content | Should -Match '(?m)^foreground = 1'
        ([regex]::Matches($content, '(?m)^proxyreload\s*=')).Count | Should -Be 1
        ([regex]::Matches($content, '(?m)^foreground\s*=')).Count | Should -Be 1
    }

    <#
    @need test: Write-PxConfig.drops a pac key from px-user.ini
    :id: TEST_PX_WRITE_CONFIG_DROPS_PAC
    :tests: REQ_PX_ENDPOINT
    @endneed
    #>
    It "drops a pac key from px-user.ini" {
        Set-Content -Path (Get-PxUserConfigPath) -Encoding ascii -Value "[settings]`npac = http://wpad.corp.example/proxy.pac"
        (Get-Content -Raw (Write-PxConfig)) | Should -Not -Match 'wpad'
    }

    <#
    @need test: Write-PxConfig.drops an auth key from px-user.ini
    :id: TEST_PX_WRITE_CONFIG_DROPS_AUTH
    :tests: REQ_PX_ENDPOINT
    @endneed
    #>
    It "drops an auth key from px-user.ini" {
        Set-Content -Path (Get-PxUserConfigPath) -Encoding ascii -Value "[settings]`nauth = BASIC"
        (Get-Content -Raw (Write-PxConfig)) | Should -Not -Match 'BASIC'
    }
}

Describe "Install-PxProxy" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock New-Directory { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        Mock Invoke-CommandLine { }
    }

    <#
    @need test: Install-PxProxy.installs px via Scoop and writes a marker when px is absent
    :id: TEST_PX_INSTALL_SCOOP_AND_MARKER
    :tests: REQ_PX_INSTALL
    @endneed
    #>
    It "installs px via Scoop and writes a marker when px is absent" {
        Mock Test-PxInstalled { $false }
        Install-PxProxy
        Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter { $CommandLine -eq 'scoop install px' }
        Test-Path (Get-PxInstalledMarkerPath) | Should -BeTrue
    }

    <#
    @need test: Install-PxProxy.skips Scoop install when px is already present
    :id: TEST_PX_INSTALL_SKIPS_SCOOP
    :tests: REQ_PX_INSTALL
    @endneed
    #>
    It "skips Scoop install when px is already present" {
        Mock Test-PxInstalled { $true }
        Install-PxProxy
        Should -Invoke Invoke-CommandLine -Times 0
    }

    <#
    @need test: Install-PxProxy.seeds the px-user.ini template
    :id: TEST_PX_INSTALL_SEEDS_TEMPLATE
    :tests: REQ_PX_INSTALL, REQ_PX_USER_TEMPLATE
    @endneed
    #>
    It "seeds the px-user.ini template" {
        Mock Test-PxInstalled { $true }
        Remove-Item (Get-PxUserConfigPath) -ErrorAction SilentlyContinue
        Install-PxProxy
        Test-Path (Get-PxUserConfigPath) | Should -BeTrue
    }

    <#
    @need test: Install-PxProxy.writes no px.ini
    :id: TEST_PX_INSTALL_WRITES_NO_PX_INI
    :tests: REQ_PX_INSTALL
    @endneed
    #>
    It "writes no px.ini" {
        Mock Test-PxInstalled { $false }
        Remove-Item (Get-PxConfigPath) -ErrorAction SilentlyContinue
        Install-PxProxy
        Test-Path (Get-PxConfigPath) | Should -BeFalse
    }
}

Describe "Stop-PxProxy" {
    BeforeEach {
        # Safety net (SC-049): never let a unit test reach a real px process.
        # Stop-PxProxy force-kills via Get-Process | Stop-Process when px ignores
        # --quit; mocking both here guarantees no test can terminate a running px.
        Mock Get-Process { }
        Mock Stop-Process { }
        Mock Unregister-Autostart { $true }
    }

    <#
    @need test: Stop-PxProxy.leaves the logon start in place so the restart inside start keeps it
    :id: TEST_PX_STOP_LEAVES_LOGON_START
    :tests: REQ_PX_LOGON
    @endneed
    #>
    It "leaves the logon start in place so the restart inside start keeps it" {
        Mock Get-PxExecutable { 'C:\scoop\shims\px.exe' }
        Mock Invoke-CommandLine { }
        Mock Start-Sleep { }
        $script:quitCalled = $false
        Mock Test-PxRunning { if ($script:quitCalled) { $false } else { $script:quitCalled = $true; $true } }
        Stop-PxProxy
        Should -Invoke Unregister-Autostart -Times 0
    }

    <#
    @need test: Stop-PxProxy.does nothing when px is not running
    :id: TEST_PX_STOP_NOTHING_WHEN_NOT_RUNNING
    :tests: REQ_PX_STOP
    @endneed
    #>
    It "does nothing when px is not running" {
        Mock Test-PxRunning { $false }
        Mock Invoke-CommandLine { }
        Stop-PxProxy
        Should -Invoke Invoke-CommandLine -Times 0
        Should -Invoke Stop-Process -Times 0
    }

    <#
    @need test: Stop-PxProxy.asks px to quit when running and does not force-kill once it exits
    :id: TEST_PX_STOP_ASKS_PX_TO_QUIT
    :tests: REQ_PX_STOP
    @endneed
    #>
    It "asks px to quit when running and does not force-kill once it exits" {
        Mock Get-PxExecutable { 'C:\scoop\shims\px.exe' }
        Mock Invoke-CommandLine { }
        Mock Start-Sleep { }
        # Running before --quit, gone after: the stateful mock alone governs.
        $script:quitCalled = $false
        Mock Test-PxRunning { if ($script:quitCalled) { $false } else { $script:quitCalled = $true; $true } }
        Stop-PxProxy
        Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter { $CommandLine -match '^& ".*" --quit$' }
        Should -Invoke Stop-Process -Times 0
    }

    <#
    @need test: Stop-PxProxy.force-kills px when it ignores --quit
    :id: TEST_PX_STOP_FORCE_KILLS
    :tests: REQ_PX_STOP
    @endneed
    #>
    It "force-kills px when it ignores --quit" {
        Mock Get-PxExecutable { 'C:\scoop\shims\px.exe' }
        Mock Invoke-CommandLine { }
        Mock Start-Sleep { }
        Mock Test-PxRunning { $true }   # still running after --quit
        Mock Get-Process { @([pscustomobject]@{ Id = 4242 }) }
        Stop-PxProxy
        Should -Invoke Stop-Process -Times 1 -ParameterFilter { $Id -eq 4242 }
    }
}

Describe "Start-PxProxy" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock New-Directory { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        Mock Get-PxExecutable { 'C:\scoop\shims\pxw.exe' }
        Mock Test-PxRunning { $false }
        Mock Start-Process { }
        Mock Register-Autostart { Join-Path $TestDrive "$Name.lnk" }
        Mock Unregister-Autostart { $true }
    }

    <#
    @need test: Start-PxProxy.writes the config before it starts px
    :id: TEST_PX_START_WRITES_CONFIG_FIRST
    :tests: REQ_PX_START
    @endneed
    #>
    It "writes the config before it starts px" {
        Start-PxProxy
        Should -Invoke Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq 'C:\scoop\shims\pxw.exe' -and $ArgumentList -match '^--config='
        }
        Test-Path (Join-Path $script:TestDataDir 'px.ini') | Should -BeTrue
    }

    <#
    @need test: Start-PxProxy.registers the logon start: the launched pxw with the px config in the data directory
    :id: TEST_PX_START_REGISTERS_LOGON_START
    :tests: REQ_PX_LOGON
    @endneed
    #>
    It "registers the logon start: the launched pxw with the px config in the data directory" {
        Start-PxProxy
        Should -Invoke Register-Autostart -Times 1 -ParameterFilter {
            $Name -eq 'px-proxy' -and
            $TargetPath -eq 'C:\scoop\shims\pxw.exe' -and
            $Arguments -eq "--config=`"$(Join-Path $script:TestDataDir 'px.ini')`"" -and
            $WorkingDirectory -eq $script:TestDataDir
        }
    }

    <#
    @need test: Start-PxProxy.names the logon start it wrote and the config it starts from
    :id: TEST_PX_START_NAMES_LOGON_START
    :tests: REQ_PX_LOGON
    @endneed
    #>
    It "names the logon start it wrote and the config it starts from" {
        Start-PxProxy -InformationVariable info
        $message = ($info | ForEach-Object { $_.MessageData }) -join "`n"
        $message | Should -Match ([regex]::Escape((Join-Path $TestDrive 'px-proxy.lnk')))
        $message | Should -Match ([regex]::Escape((Join-Path $script:TestDataDir 'px.ini')))
    }

    <#
    @need test: Start-PxProxy.registers no logon start when px cannot be launched
    :id: TEST_PX_START_NO_LOGON_START_ON_LAUNCH_FAILURE
    :tests: REQ_PX_LOGON
    @endneed
    #>
    It "registers no logon start when px cannot be launched" {
        Mock Start-Process { throw 'launch failed' }
        { Start-PxProxy } | Should -Throw
        Should -Invoke Register-Autostart -Times 0
    }

    <#
    @need test: Start-PxProxy.stops a running px before starting a fresh one
    :id: TEST_PX_START_STOPS_RUNNING_PX
    :tests: REQ_PX_START
    @endneed
    #>
    It "stops a running px before starting a fresh one" {
        Mock Test-PxRunning { $true }
        Mock Stop-PxProxy { }
        Start-PxProxy
        Should -Invoke Stop-PxProxy -Times 1
        Should -Invoke Start-Process -Times 1
    }

    <#
    @need test: Start-PxProxy.keeps the logon start when it restarts a running px
    :id: TEST_PX_START_KEEPS_LOGON_START_ON_RESTART
    :tests: REQ_PX_LOGON
    @endneed
    #>
    It "keeps the logon start when it restarts a running px" {
        Mock Test-PxRunning { $true }
        Mock Stop-PxProxy { }
        Start-PxProxy
        Should -Invoke Unregister-Autostart -Times 0
        Should -Invoke Register-Autostart -Times 1
    }

    <#
    @need test: Start-PxProxy.throws when no px executable is available
    :id: TEST_PX_START_THROWS_WITHOUT_PX
    :tests: REQ_PX_START
    @endneed
    #>
    It "throws when no px executable is available" {
        Mock Get-PxExecutable { $null }
        { Start-PxProxy } | Should -Throw
    }

    <#
    @need test: Start-PxProxy.fails fast without writing config when px is absent
    :id: TEST_PX_START_FAILS_FAST_WITHOUT_PX
    :tests: REQ_PX_START
    @endneed
    #>
    It "fails fast without writing config when px is absent" {
        Mock Get-PxExecutable { $null }
        Mock Write-PxConfig { }
        { Start-PxProxy } | Should -Throw
        Should -Invoke Write-PxConfig -Times 0
        Should -Invoke Start-Process -Times 0
        Should -Invoke Register-Autostart -Times 0
    }

    <#
    @need test: Start-PxProxy.starts without a lookup or a prompt when no proxy host is given
    :id: TEST_PX_START_NO_LOOKUP
    :tests: REQ_PX_UPSTREAM
    @endneed
    #>
    It "starts without a lookup or a prompt when no proxy host is given" {
        Mock Test-RunningInCIorTestEnvironment { $false }
        Mock Read-Host { throw 'prompted for the upstream' }
        Mock klist { throw 'klist was called' }
        Start-PxProxy
        (Get-Content -Raw (Join-Path $script:TestDataDir 'px.ini')) | Should -Not -Match '(?m)^\s*server\s*='
        Should -Invoke Read-Host -Times 0
    }

    <#
    @need test: Start-PxProxy.pins the proxy host given with -ProxyHost
    :id: TEST_PX_START_PINS_PROXY_HOST
    :tests: REQ_PX_UPSTREAM
    @endneed
    #>
    It "pins the proxy host given with -ProxyHost" {
        Start-PxProxy -ProxyHost 'up.corp:8080'
        (Get-Content -Raw (Join-Path $script:TestDataDir 'px.ini')) | Should -Match '(?m)^server = up\.corp:8080'
    }

    <#
    @need test: Start-PxProxy.says px takes the upstream from the Windows proxy settings when no proxy host is given
    :id: TEST_PX_START_SAYS_WINDOWS_PROXY
    :tests: REQ_PX_UPSTREAM
    @endneed
    #>
    It "says px takes the upstream from the Windows proxy settings when no proxy host is given" {
        Start-PxProxy -InformationVariable info
        (($info | ForEach-Object { $_.MessageData }) -join "`n") | Should -Match 'Windows proxy settings'
    }

    <#
    @need test: Start-PxProxy.starts the windowless pxw with the px config in the data directory
    :id: TEST_PX_START_LAUNCHES_PXW_IN_DATA_DIR
    :tests: REQ_PX_START
    @endneed
    #>
    It "starts the windowless pxw with the px config in the data directory" {
        Start-PxProxy
        Should -Invoke Get-PxExecutable -ParameterFilter { $Windowless }
        Should -Invoke Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq 'C:\scoop\shims\pxw.exe' -and
            $ArgumentList -eq "--config=`"$(Join-Path $script:TestDataDir 'px.ini')`"" -and
            $WorkingDirectory -eq $script:TestDataDir
        }
    }
}

Describe "Removed upstream lookup" {
    It "no longer defines <_>" -ForEach @('Resolve-PxUpstreamProxy', 'Get-KerberosProxyHost', 'Get-KlistOutput') {
        Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}

Describe "Test-PxProxy" {
    <#
    @need test: Test-PxProxy.reports success on a 200 response
    :id: TEST_PX_TEST_REPORTS_SUCCESS
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "reports success on a 200 response" {
        Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 200 } }
        Test-PxProxy | Should -BeTrue
    }

    <#
    @need test: Test-PxProxy.reports failure and returns false on a 407
    :id: TEST_PX_TEST_FAILS_ON_407
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "reports failure and returns false on a 407" {
        Mock Invoke-WebRequest {
            $resp = [pscustomobject]@{ StatusCode = 407 }
            $ex = [System.Exception]::new('Proxy auth required')
            $ex | Add-Member -NotePropertyName Response -NotePropertyValue $resp -Force
            throw $ex
        }
        Test-PxProxy -WarningAction SilentlyContinue | Should -BeFalse
    }

    <#
    @need test: Test-PxProxy.returns false on a generic error
    :id: TEST_PX_TEST_FAILS_ON_GENERIC_ERROR
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "returns false on a generic error" {
        Mock Invoke-WebRequest { throw 'connection refused' }
        Test-PxProxy -WarningAction SilentlyContinue | Should -BeFalse
    }

    <#
    @need test: Test-PxProxy.reports a revocation failure as its own diagnostic
    :id: TEST_PX_TEST_DIAGNOSES_REVOCATION
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "reports a revocation failure as its own diagnostic" {
        Mock Invoke-WebRequest { throw 'The revocation function was unable to check revocation for the certificate.' }
        Mock Write-Warning { }
        Test-PxProxy | Should -BeFalse
        Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -match 'revocation check failed' }
    }

    <#
    @need test: Test-PxProxy.reports a certificate error distinctly from a revocation failure
    :id: TEST_PX_TEST_DIAGNOSES_CERTIFICATE
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "reports a certificate error distinctly from a revocation failure" {
        Mock Invoke-WebRequest { throw 'The remote certificate is invalid according to the validation procedure.' }
        Mock Write-Warning { }
        Test-PxProxy | Should -BeFalse
        Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -match 'TLS/certificate error' }
    }

    <#
    @need test: Test-PxProxy.sends an HTTPS request through the endpoint with a 20-second timeout and reports the status
    :id: TEST_PX_TEST_REQUEST_THROUGH_ENDPOINT
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "sends an HTTPS request through the endpoint with a 20-second timeout and reports the status" {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 200 } }
        Test-PxProxy -InformationVariable info | Should -BeTrue
        Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter {
            $Uri -eq 'https://www.google.com' -and $Proxy -eq 'http://127.0.0.1:3128' -and $TimeoutSec -eq 20
        }
        (($info | ForEach-Object { $_.MessageData }) -join "`n") | Should -Match 'HTTP 200'
    }

    <#
    @need test: Test-PxProxy.names the upstream authentication as the cause of a 407
    :id: TEST_PX_TEST_NAMES_407_CAUSE
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "names the upstream authentication as the cause of a 407" {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock Invoke-WebRequest {
            $resp = [pscustomobject]@{ StatusCode = 407 }
            $ex = [System.Exception]::new('Proxy auth required')
            $ex | Add-Member -NotePropertyName Response -NotePropertyValue $resp -Force
            throw $ex
        }
        Mock Write-Warning { }
        Test-PxProxy | Should -BeFalse
        Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -match '407.*authenticate to the upstream proxy' }
    }
}

Describe "Script entry point" {
    <#
    @need test: Script entry point.dispatches the action and exits 0 when not in library mode
    :id: TEST_PX_ENTRY_EXITS_ZERO
    :tests: REQ_PX_EXIT
    @endneed
    #>
    # Invokes the script as a program (library mode off) so the guard's
    # 'exit (Invoke-PxProxyMain ...)' runs. Invoked with '&', so exit returns
    # control here and sets $LASTEXITCODE rather than killing the test host.
    # 'stop' is the only action that is a pure no-op when px is not running and
    # no logon entry exists; skipped outright if px happens to be running or the
    # real logon entry exists (SC-067), so the test never stops a developer's
    # live px and never deletes their logon start.
    It "dispatches the action and exits 0 when not in library mode" -Skip:(
        [bool](Get-Process -Name 'px', 'pxw' -ErrorAction SilentlyContinue) -or
        (Test-Path (Join-Path ([Environment]::GetFolderPath('Startup')) 'px-proxy.lnk'))
    ) {
        Remove-Item Env:\PXPROXY_LIBRARY_MODE -ErrorAction SilentlyContinue
        try {
            & "$PSScriptRoot\px-proxy.ps1" stop *> $null
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            $env:PXPROXY_LIBRARY_MODE = '1'
        }
    }

    <#
    @need test: Script entry point.defaults to the start action
    :id: TEST_PX_ENTRY_DEFAULT_ACTION_START
    :tests: REQ_PX_START
    @endneed
    #>
    It "defaults to the start action" {
        # Inspects the parameter default instead of running the script: 'start'
        # is the one action that must never run against a real px in a test.
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'px-proxy.ps1'), [ref]$tokens, [ref]$errors)
        $action = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Action' }
        $action.DefaultValue.Value | Should -Be 'start'
    }

    <#
    @need test: Script entry point.waits for a key by default
    :id: TEST_PX_ENTRY_WAITS_FOR_KEY_BY_DEFAULT
    :tests: REQ_PX_WAIT_KEY
    @endneed
    #>
    It "waits for a key by default" {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'px-proxy.ps1'), [ref]$tokens, [ref]$errors)
        $waitForKey = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'WaitForKey' }
        $waitForKey.DefaultValue.Extent.Text | Should -Be '$true'
    }
}

Describe "Invoke-PxProxyMain" {
    <#
    @need test: Invoke-PxProxyMain.returns 0 when the action succeeds
    :id: TEST_PX_MAIN_RETURNS_ZERO
    :tests: REQ_PX_EXIT
    @endneed
    #>
    It "returns 0 when the action succeeds" {
        Mock Invoke-PxProxy { }
        Invoke-PxProxyMain -Action stop | Should -Be 0
    }

    <#
    @need test: Invoke-PxProxyMain.returns 1 and reports the failure when the action throws
    :id: TEST_PX_MAIN_RETURNS_ONE_AND_NAMES_ACTION
    :tests: REQ_PX_EXIT
    @endneed
    #>
    It "returns 1 and reports the failure when the action throws" {
        Mock Invoke-PxProxy { throw 'boom' }
        Mock Write-Error { }
        Invoke-PxProxyMain -Action start | Should -Be 1
        Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -match "px-proxy 'start' failed: boom" }
    }

    <#
    @need test: Invoke-PxProxyMain.passes the ProxyHost override through to the dispatcher
    :id: TEST_PX_MAIN_PASSES_PROXY_HOST
    :tests: REQ_PX_UPSTREAM
    @endneed
    #>
    It "passes the ProxyHost override through to the dispatcher" {
        Mock Invoke-PxProxy { }
        Invoke-PxProxyMain -Action start -ProxyHost 'x.corp:8080' | Should -Be 0
        Should -Invoke Invoke-PxProxy -Times 1 -ParameterFilter { $ProxyHost -eq 'x.corp:8080' }
    }

    <#
    @need test: Invoke-PxProxyMain.pauses before returning when -WaitForKey is set and the action succeeds
    :id: TEST_PX_MAIN_PAUSES_ON_SUCCESS
    :tests: REQ_PX_WAIT_KEY
    @endneed
    #>
    It "pauses before returning when -WaitForKey is set and the action succeeds" {
        Mock Invoke-PxProxy { }
        Mock Wait-ForKeyPress { }
        Invoke-PxProxyMain -Action stop -WaitForKey | Should -Be 0
        Should -Invoke Wait-ForKeyPress -Times 1
    }

    <#
    @need test: Invoke-PxProxyMain.pauses before returning even when the action fails so the error stays visible
    :id: TEST_PX_MAIN_PAUSES_ON_FAILURE
    :tests: REQ_PX_WAIT_KEY
    @endneed
    #>
    It "pauses before returning even when the action fails so the error stays visible" {
        Mock Invoke-PxProxy { throw 'boom' }
        Mock Write-Error { }
        Mock Wait-ForKeyPress { }
        Invoke-PxProxyMain -Action start -WaitForKey | Should -Be 1
        Should -Invoke Wait-ForKeyPress -Times 1
    }

    <#
    @need test: Invoke-PxProxyMain.does not pause when -WaitForKey is not set
    :id: TEST_PX_MAIN_NO_PAUSE_WITHOUT_SWITCH
    :tests: REQ_PX_WAIT_KEY
    @endneed
    #>
    It "does not pause when -WaitForKey is not set" {
        Mock Invoke-PxProxy { }
        Mock Wait-ForKeyPress { }
        Invoke-PxProxyMain -Action stop | Should -Be 0
        Should -Invoke Wait-ForKeyPress -Times 0
    }
}

Describe "Wait-ForKeyPress" {
    <#
    @need test: Wait-ForKeyPress.does not read a key in a CI/test environment
    :id: TEST_PX_WAIT_KEY_SKIPPED_IN_CI
    :tests: REQ_PX_WAIT_KEY
    @endneed
    #>
    It "does not read a key in a CI/test environment" {
        Mock Test-RunningInCIorTestEnvironment { $true }
        Mock Read-SingleKey { }
        Wait-ForKeyPress
        Should -Invoke Read-SingleKey -Times 0
    }

    <#
    @need test: Wait-ForKeyPress.reads a key when interactive
    :id: TEST_PX_WAIT_KEY_READS_WHEN_INTERACTIVE
    :tests: REQ_PX_WAIT_KEY
    @endneed
    #>
    It "reads a key when interactive" {
        Mock Test-RunningInCIorTestEnvironment { $false }
        Mock Read-SingleKey { }
        Mock Write-Host { }
        Wait-ForKeyPress
        Should -Invoke Read-SingleKey -Times 1
    }

    <#
    @need test: Wait-ForKeyPress.does not throw when the console has no interactive key reader
    :id: TEST_PX_WAIT_KEY_NO_CONSOLE
    :tests: REQ_PX_WAIT_KEY
    @endneed
    #>
    It "does not throw when the console has no interactive key reader" {
        Mock Test-RunningInCIorTestEnvironment { $false }
        Mock Read-SingleKey { throw 'no console' }
        Mock Write-Host { }
        { Wait-ForKeyPress } | Should -Not -Throw
    }
}

Describe "Remove-PxProxy" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock Stop-PxProxy { }
        Mock Invoke-CommandLine { }
        Mock Unregister-Autostart { $true }
        New-Item -ItemType Directory -Path $script:TestDataDir -Force | Out-Null
    }

    <#
    @need test: Remove-PxProxy.removes the logon start
    :id: TEST_PX_REMOVE_LOGON_START
    :tests: REQ_PX_REMOVE
    @endneed
    #>
    It "removes the logon start" {
        Remove-PxProxy
        Should -Invoke Unregister-Autostart -Times 1 -ParameterFilter { $Name -eq 'px-proxy' }
    }

    <#
    @need test: Remove-PxProxy.uninstalls px when the marker exists
    :id: TEST_PX_REMOVE_UNINSTALLS_WITH_MARKER
    :tests: REQ_PX_REMOVE
    @endneed
    #>
    It "uninstalls px when the marker exists" {
        Set-Content -Path (Get-PxInstalledMarkerPath) -Value 'x'
        Mock Test-PxInstalled { $true }
        Remove-PxProxy
        Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter { $CommandLine -eq 'scoop uninstall px' }
        Test-Path (Get-PxInstalledMarkerPath) | Should -BeFalse
    }

    <#
    @need test: Remove-PxProxy.does not uninstall px when no marker exists
    :id: TEST_PX_REMOVE_KEEPS_PX_WITHOUT_MARKER
    :tests: REQ_PX_REMOVE
    @endneed
    #>
    It "does not uninstall px when no marker exists" {
        Remove-Item (Get-PxInstalledMarkerPath) -ErrorAction SilentlyContinue
        Remove-PxProxy
        Should -Invoke Invoke-CommandLine -Times 0
    }

    <#
    @need test: Remove-PxProxy.keeps the marker when the uninstall is skipped because px is not on PATH
    :id: TEST_PX_REMOVE_KEEPS_MARKER_WITHOUT_PX
    :tests: REQ_PX_REMOVE
    @endneed
    #>
    It "keeps the marker when the uninstall is skipped because px is not on PATH" {
        Set-Content -Path (Get-PxInstalledMarkerPath) -Value 'x'
        Mock Test-PxInstalled { $false }
        Remove-PxProxy
        Should -Invoke Invoke-CommandLine -Times 0
        Test-Path (Get-PxInstalledMarkerPath) | Should -BeTrue
    }

    <#
    @need test: Remove-PxProxy.deletes the px config file
    :id: TEST_PX_REMOVE_DELETES_CONFIG
    :tests: REQ_PX_REMOVE
    @endneed
    #>
    It "deletes the px config file" {
        Set-Content -Path (Get-PxConfigPath) -Value 'stale'
        Remove-PxProxy
        Test-Path (Get-PxConfigPath) | Should -BeFalse
    }

    <#
    @need test: Remove-PxProxy.preserves the user config file so tuning survives a reinstall
    :id: TEST_PX_REMOVE_KEEPS_USER_CONFIG
    :tests: REQ_PX_REMOVE
    @endneed
    #>
    It "preserves the user config file so tuning survives a reinstall" {
        Set-Content -Path (Get-PxUserConfigPath) -Value 'MINE' -Encoding ascii
        Set-Content -Path (Get-PxConfigPath) -Value 'stale'
        Remove-PxProxy
        Test-Path (Get-PxConfigPath) | Should -BeFalse
        Test-Path (Get-PxUserConfigPath) | Should -BeTrue
        Get-Content -Raw (Get-PxUserConfigPath) | Should -Match 'MINE'
    }

    <#
    @need test: Remove-PxProxy.deletes the debug logs
    :id: TEST_PX_REMOVE_DELETES_DEBUG_LOGS
    :tests: REQ_PX_REMOVE
    @endneed
    #>
    It "deletes the debug logs" {
        Set-Content -Path (Join-Path $script:TestDataDir 'debug-1234.log') -Value 'log' -Encoding ascii
        Set-Content -Path (Join-Path $script:TestDataDir 'debug-77.log') -Value 'log' -Encoding ascii
        Remove-PxProxy
        Test-Path (Join-Path $script:TestDataDir 'debug-1234.log') | Should -BeFalse
        Test-Path (Join-Path $script:TestDataDir 'debug-77.log') | Should -BeFalse
    }
}

Describe "Invoke-PxProxy" {
    BeforeEach {
        Mock Unregister-Autostart { $true }
    }

    <#
    @need test: Invoke-PxProxy.dispatches install
    :id: TEST_PX_DISPATCH_INSTALL
    :tests: REQ_PX_INSTALL
    @endneed
    #>
    It "dispatches install" {
        Mock Install-PxProxy { }
        Invoke-PxProxy -Action install
        Should -Invoke Install-PxProxy -Times 1
    }

    <#
    @need test: Invoke-PxProxy.dispatches start with the ProxyHost override
    :id: TEST_PX_DISPATCH_START
    :tests: REQ_PX_START, REQ_PX_UPSTREAM
    @endneed
    #>
    It "dispatches start with the ProxyHost override" {
        Mock Start-PxProxy { }
        Invoke-PxProxy -Action start -ProxyHost 'x.corp:8080'
        Should -Invoke Start-PxProxy -Times 1 -ParameterFilter { $ProxyHost -eq 'x.corp:8080' }
    }

    <#
    @need test: Invoke-PxProxy.dispatches stop and removes the logon start
    :id: TEST_PX_DISPATCH_STOP_REMOVES_LOGON_START
    :tests: REQ_PX_STOP
    @endneed
    #>
    It "dispatches stop and removes the logon start" {
        Mock Stop-PxProxy { }
        Invoke-PxProxy -Action stop
        Should -Invoke Stop-PxProxy -Times 1
        Should -Invoke Unregister-Autostart -Times 1 -ParameterFilter { $Name -eq 'px-proxy' }
    }

    <#
    @need test: Invoke-PxProxy.reports on stop that px no longer starts at logon
    :id: TEST_PX_DISPATCH_STOP_REPORTS_LOGON_START
    :tests: REQ_PX_STOP
    @endneed
    #>
    It "reports on stop that px no longer starts at logon" {
        Mock Stop-PxProxy { }
        Invoke-PxProxy -Action stop -InformationVariable info
        ($info | ForEach-Object { $_.MessageData }) -join "`n" | Should -Match 'no longer starts at logon'
    }

    <#
    @need test: Invoke-PxProxy.reports nothing about the logon start on stop when there was none
    :id: TEST_PX_DISPATCH_STOP_REPORTS_NOTHING_WITHOUT_LOGON_START
    :tests: REQ_PX_STOP
    @endneed
    #>
    It "reports nothing about the logon start on stop when there was none" {
        Mock Stop-PxProxy { }
        Mock Unregister-Autostart { $false }
        Invoke-PxProxy -Action stop -InformationVariable info
        ($info | ForEach-Object { $_.MessageData }) -join "`n" | Should -Not -Match 'logon'
    }

    <#
    @need test: Invoke-PxProxy.keeps the logon start when it dispatches start
    :id: TEST_PX_DISPATCH_START_KEEPS_LOGON_START
    :tests: REQ_PX_LOGON
    @endneed
    #>
    It "keeps the logon start when it dispatches start" {
        Mock Start-PxProxy { }
        Invoke-PxProxy -Action start
        Should -Invoke Unregister-Autostart -Times 0
    }

    <#
    @need test: Invoke-PxProxy.dispatches test
    :id: TEST_PX_DISPATCH_TEST
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "dispatches test" {
        Mock Test-PxProxy { $true }
        Invoke-PxProxy -Action test
        Should -Invoke Test-PxProxy -Times 1
    }

    <#
    @need test: Invoke-PxProxy.throws when the test action fails so the caller sees a non-zero exit code
    :id: TEST_PX_DISPATCH_TEST_THROWS_ON_FAILURE
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "throws when the test action fails so the caller sees a non-zero exit code" {
        Mock Test-PxProxy { $false }
        { Invoke-PxProxy -Action test } | Should -Throw
    }

    <#
    @need test: Invoke-PxProxy.does not throw when the test action succeeds
    :id: TEST_PX_DISPATCH_TEST_OK
    :tests: REQ_PX_TEST
    @endneed
    #>
    It "does not throw when the test action succeeds" {
        Mock Test-PxProxy { $true }
        { Invoke-PxProxy -Action test } | Should -Not -Throw
    }

    <#
    @need test: Invoke-PxProxy.dispatches remove
    :id: TEST_PX_DISPATCH_REMOVE
    :tests: REQ_PX_REMOVE
    @endneed
    #>
    It "dispatches remove" {
        Mock Remove-PxProxy { }
        Invoke-PxProxy -Action remove
        Should -Invoke Remove-PxProxy -Times 1
    }
}
