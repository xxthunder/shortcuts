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
}

AfterAll {
    Remove-Item Env:\PXPROXY_LIBRARY_MODE -ErrorAction SilentlyContinue
    Stop-SutIsolation
}

Describe "Get-PxDataDir" {
    It "returns a path under the user profile .config\px" {
        Get-PxDataDir | Should -BeLike '*\.config\px'
    }
}

Describe "Get-PxConfigPath" {
    It "returns px.ini inside the data directory" {
        Mock Get-PxDataDir { 'C:\fake\px' }
        Get-PxConfigPath | Should -Be 'C:\fake\px\px.ini'
    }
}

Describe "Test-PxInstalled" {
    It "returns true when px command is found" {
        Mock Get-Command { [pscustomobject]@{ Source = 'C:\scoop\shims\px.exe' } } -ParameterFilter { $Name -eq 'px' }
        Test-PxInstalled | Should -BeTrue
    }

    It "returns false when px command is missing" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'px' }
        Test-PxInstalled | Should -BeFalse
    }
}

Describe "Get-PxExecutable" {
    It "prefers pxw when Windowless is requested and pxw exists" {
        Mock Get-Command { [pscustomobject]@{ Source = 'C:\scoop\shims\pxw.exe' } } -ParameterFilter { $Name -eq 'pxw' }
        Get-PxExecutable -Windowless | Should -Be 'C:\scoop\shims\pxw.exe'
    }

    It "falls back to px when the requested variant shim is missing" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pxw' }
        Mock Get-Command { [pscustomobject]@{ Source = 'C:\scoop\shims\px.exe' } } -ParameterFilter { $Name -eq 'px' }
        Mock Test-Path { $false }
        Get-PxExecutable -Windowless | Should -Be 'C:\scoop\shims\px.exe'
    }

    It "returns null when no px executable exists" {
        Mock Get-Command { $null }
        Get-PxExecutable | Should -BeNullOrEmpty
    }

    It "uses the pxw.exe sitting next to px when the shim is missing" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pxw' }
        Mock Get-Command { [pscustomobject]@{ Source = 'C:\scoop\apps\px\current\px.exe' } } -ParameterFilter { $Name -eq 'px' }
        Mock Test-Path { $true }
        Get-PxExecutable -Windowless | Should -Be 'C:\scoop\apps\px\current\pxw.exe'
    }
}

Describe "Test-PxRunning" {
    It "returns true when a px process is present" {
        Mock Get-Process { @([pscustomobject]@{ Id = 42 }) }
        Test-PxRunning | Should -BeTrue
    }

    It "returns false when no px process is present" {
        Mock Get-Process { $null }
        Test-PxRunning | Should -BeFalse
    }
}

Describe "Get-KlistOutput" {
    It "returns the output of the klist command" {
        Mock klist { 'Cached Tickets: (0)' }
        Get-KlistOutput | Should -Be 'Cached Tickets: (0)'
    }
}

Describe "Library-mode env restoration" {
    It "restores a pre-existing SETPROXY_LIBRARY_MODE after dot-sourcing setProxy" {
        $env:SETPROXY_LIBRARY_MODE = 'preset'
        try {
            . "$PSScriptRoot\px-proxy.ps1"
            $env:SETPROXY_LIBRARY_MODE | Should -Be 'preset'
        }
        finally {
            Remove-Item Env:\SETPROXY_LIBRARY_MODE -ErrorAction SilentlyContinue
        }
    }
}

Describe "Get-KerberosProxyHost" {
    It "extracts the HTTP SPN host and appends the default port" {
        Mock Get-KlistOutput { @(
                'Cached Tickets: (5)',
                '    Server: HTTP/osproxy.corp.example @ CORP.EXAMPLE'
            ) }
        Get-KerberosProxyHost -WarningAction SilentlyContinue | Should -Be 'osproxy.corp.example:8080'
    }

    It "returns null when no HTTP SPN is present" {
        Mock Get-KlistOutput { @('Cached Tickets: (1)', '    Server: krbtgt/CORP.EXAMPLE') }
        Get-KerberosProxyHost | Should -BeNullOrEmpty
    }

    It "returns null when klist output is empty" {
        Mock Get-KlistOutput { $null }
        Get-KerberosProxyHost | Should -BeNullOrEmpty
    }

    It "warns that the host and port are a guess when it falls back to an SPN" {
        Mock Get-KlistOutput { @('    Server: HTTP/intranet.corp.example @ CORP.EXAMPLE') }
        Mock Write-Warning { }
        Get-KerberosProxyHost | Out-Null
        Should -Invoke Write-Warning -Times 1 -ParameterFilter {
            $Message -match 'intranet\.corp\.example:8080' -and $Message -match '-ProxyHost'
        }
    }

    It "does not warn when no SPN is found" {
        Mock Get-KlistOutput { @('    Server: krbtgt/CORP.EXAMPLE') }
        Mock Write-Warning { }
        Get-KerberosProxyHost | Out-Null
        Should -Invoke Write-Warning -Times 0
    }

    It "returns null when klist is unavailable and throws" {
        Mock Get-KlistOutput { throw 'klist: command not found' }
        Get-KerberosProxyHost | Should -BeNullOrEmpty
    }
}

Describe "Resolve-PxUpstreamProxy" {
    It "returns the explicit ProxyHost override when provided" {
        Resolve-PxUpstreamProxy -ProxyHost 'manual.corp:8080' | Should -Be 'manual.corp:8080'
    }

    It "resolves via PAC when the PAC returns a non-direct proxy" {
        Mock Get-InternetSettingsFromRegistry { @{ AutoConfigUrl = 'http://wpad/pac' } }
        Mock Get-ProxyFromPac { @{ ProxyUrl = 'http://pacproxy.corp:8080'; IsDirect = $false } }
        Resolve-PxUpstreamProxy | Should -Be 'pacproxy.corp:8080'
    }

    It "falls back to the Kerberos SPN when PAC is direct" {
        Mock Get-InternetSettingsFromRegistry { @{ } }
        Mock Get-ProxyFromPac { @{ ProxyUrl = $null; IsDirect = $true } }
        Mock Get-KerberosProxyHost { 'spnproxy.corp:8080' }
        Resolve-PxUpstreamProxy | Should -Be 'spnproxy.corp:8080'
    }

    It "throws when nothing resolves in a non-interactive session" {
        Mock Get-InternetSettingsFromRegistry { $null }
        Mock Get-KerberosProxyHost { $null }
        Mock Test-RunningInCIorTestEnvironment { $true }
        { Resolve-PxUpstreamProxy } | Should -Throw
    }

    It "prompts for the host in an interactive session when nothing resolves" {
        Mock Get-InternetSettingsFromRegistry { $null }
        Mock Get-KerberosProxyHost { $null }
        Mock Test-RunningInCIorTestEnvironment { $false }
        Mock Read-Host { 'typed.corp:8080' }
        Resolve-PxUpstreamProxy | Should -Be 'typed.corp:8080'
        Should -Invoke Read-Host -Times 1
    }

    It "throws when the interactive prompt is answered with nothing" {
        Mock Get-InternetSettingsFromRegistry { $null }
        Mock Get-KerberosProxyHost { $null }
        Mock Test-RunningInCIorTestEnvironment { $false }
        Mock Read-Host { '   ' }
        { Resolve-PxUpstreamProxy } | Should -Throw
    }

    It "ignores a PAC result that reports DIRECT" {
        Mock Get-InternetSettingsFromRegistry { @{ AutoConfigUrl = 'http://wpad/pac' } }
        Mock Get-ProxyFromPac { @{ ProxyUrl = $null; IsDirect = $true } }
        Mock Get-KerberosProxyHost { 'spn.corp:8080' }
        Resolve-PxUpstreamProxy | Should -Be 'spn.corp:8080'
    }
}

Describe "Write-PxConfig" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock New-Directory { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    }

    It "writes a px.ini containing the resolved upstream proxy and logging" {
        $path = Write-PxConfig -UpstreamProxy 'up.corp:8080'
        $path | Should -Be (Join-Path $script:TestDataDir 'px.ini')
        $content = Get-Content -Raw $path
        $content | Should -Match 'server = up\.corp:8080'
        $content | Should -Match 'listen = 127\.0\.0\.1'
        $content | Should -Match 'port = 3128'
        $content | Should -Match 'log = 3'
    }

    It "overwrites an existing config on each call" {
        Write-PxConfig -UpstreamProxy 'first.corp:8080' | Out-Null
        $path = Write-PxConfig -UpstreamProxy 'second.corp:8080'
        $content = Get-Content -Raw $path
        $content | Should -Match 'server = second\.corp:8080'
        $content | Should -Not -Match 'first\.corp'
    }
}

Describe "Install-PxProxy" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock New-Directory { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        Mock Invoke-CommandLine { }
    }

    It "installs px via Scoop and writes a marker when px is absent" {
        Mock Test-PxInstalled { $false }
        Install-PxProxy
        Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter { $CommandLine -eq 'scoop install px' }
        Test-Path (Get-PxInstalledMarkerPath) | Should -BeTrue
    }

    It "skips Scoop install when px is already present" {
        Mock Test-PxInstalled { $true }
        Install-PxProxy
        Should -Invoke Invoke-CommandLine -Times 0
    }
}

Describe "Stop-PxProxy" {
    It "does nothing when px is not running" {
        Mock Test-PxRunning { $false }
        Mock Invoke-CommandLine { }
        Stop-PxProxy
        Should -Invoke Invoke-CommandLine -Times 0
    }

    It "asks px to quit when running" {
        Mock Test-PxRunning { $true } -ParameterFilter { $true }
        Mock Get-PxExecutable { 'C:\scoop\shims\px.exe' }
        Mock Invoke-CommandLine { }
        Mock Start-Sleep { }
        # After quit, no longer running
        $script:quitCalled = $false
        Mock Test-PxRunning { if ($script:quitCalled) { $false } else { $script:quitCalled = $true; $true } }
        Stop-PxProxy
        Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter { $CommandLine -match '^& ".*" --quit$' }
    }
}

Describe "Start-PxProxy" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock New-Directory { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        Mock Resolve-PxUpstreamProxy { 'up.corp:8080' }
        Mock Get-PxExecutable { 'C:\scoop\shims\pxw.exe' }
        Mock Test-PxRunning { $false }
        Mock Start-Process { }
    }

    It "resolves, writes config, and starts px" {
        Start-PxProxy
        Should -Invoke Resolve-PxUpstreamProxy -Times 1
        Should -Invoke Start-Process -Times 1 -ParameterFilter {
            $FilePath -eq 'C:\scoop\shims\pxw.exe' -and $ArgumentList -match '^--config='
        }
        Test-Path (Join-Path $script:TestDataDir 'px.ini') | Should -BeTrue
    }

    It "stops a running px before starting a fresh one" {
        Mock Test-PxRunning { $true }
        Mock Stop-PxProxy { }
        Start-PxProxy
        Should -Invoke Stop-PxProxy -Times 1
        Should -Invoke Start-Process -Times 1
    }

    It "throws when no px executable is available" {
        Mock Get-PxExecutable { $null }
        { Start-PxProxy } | Should -Throw
    }

    It "fails fast without resolving the proxy or writing config when px is absent" {
        Mock Get-PxExecutable { $null }
        Mock Write-PxConfig { }
        { Start-PxProxy } | Should -Throw
        Should -Invoke Resolve-PxUpstreamProxy -Times 0
        Should -Invoke Write-PxConfig -Times 0
        Should -Invoke Start-Process -Times 0
    }
}

Describe "Test-PxProxy" {
    It "reports success on a 200 response" {
        Mock Invoke-WebRequest { [pscustomobject]@{ StatusCode = 200 } }
        Test-PxProxy | Should -BeTrue
    }

    It "reports failure and returns false on a 407" {
        Mock Invoke-WebRequest {
            $resp = [pscustomobject]@{ StatusCode = 407 }
            $ex = [System.Exception]::new('Proxy auth required')
            $ex | Add-Member -NotePropertyName Response -NotePropertyValue $resp -Force
            throw $ex
        }
        Test-PxProxy -WarningAction SilentlyContinue | Should -BeFalse
    }

    It "returns false on a generic error" {
        Mock Invoke-WebRequest { throw 'connection refused' }
        Test-PxProxy -WarningAction SilentlyContinue | Should -BeFalse
    }

    It "reports a revocation failure as its own diagnostic" {
        Mock Invoke-WebRequest { throw 'The revocation function was unable to check revocation for the certificate.' }
        Mock Write-Warning { }
        Test-PxProxy | Should -BeFalse
        Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -match 'revocation check failed' }
    }

    It "reports a certificate error distinctly from a revocation failure" {
        Mock Invoke-WebRequest { throw 'The remote certificate is invalid according to the validation procedure.' }
        Mock Write-Warning { }
        Test-PxProxy | Should -BeFalse
        Should -Invoke Write-Warning -Times 1 -ParameterFilter { $Message -match 'TLS/certificate error' }
    }
}

Describe "Script entry point" {
    # Invokes the script as a program (library mode off) so the guard's
    # 'exit (Invoke-PxProxyMain ...)' runs. Invoked with '&', so exit returns
    # control here and sets $LASTEXITCODE rather than killing the test host.
    # 'stop' is the only action that is a pure no-op when px is not running;
    # skipped outright if px happens to be running, so the test never stops a
    # developer's live px.
    It "dispatches the action and exits 0 when not in library mode" -Skip:([bool](Get-Process -Name 'px', 'pxw' -ErrorAction SilentlyContinue)) {
        Remove-Item Env:\PXPROXY_LIBRARY_MODE -ErrorAction SilentlyContinue
        try {
            & "$PSScriptRoot\px-proxy.ps1" stop *> $null
            $LASTEXITCODE | Should -Be 0
        }
        finally {
            $env:PXPROXY_LIBRARY_MODE = '1'
        }
    }
}

Describe "Invoke-PxProxyMain" {
    It "returns 0 when the action succeeds" {
        Mock Invoke-PxProxy { }
        Invoke-PxProxyMain -Action stop | Should -Be 0
    }

    It "returns 1 and reports the failure when the action throws" {
        Mock Invoke-PxProxy { throw 'boom' }
        Mock Write-Error { }
        Invoke-PxProxyMain -Action start | Should -Be 1
        Should -Invoke Write-Error -Times 1 -ParameterFilter { $Message -match "px-proxy 'start' failed: boom" }
    }

    It "passes the ProxyHost override through to the dispatcher" {
        Mock Invoke-PxProxy { }
        Invoke-PxProxyMain -Action start -ProxyHost 'x.corp:8080' | Should -Be 0
        Should -Invoke Invoke-PxProxy -Times 1 -ParameterFilter { $ProxyHost -eq 'x.corp:8080' }
    }
}

Describe "Remove-PxProxy" {
    BeforeEach {
        Mock Get-PxDataDir { $script:TestDataDir }
        Mock Stop-PxProxy { }
        Mock Invoke-CommandLine { }
        New-Item -ItemType Directory -Path $script:TestDataDir -Force | Out-Null
    }

    It "uninstalls px when the marker exists" {
        Set-Content -Path (Get-PxInstalledMarkerPath) -Value 'x'
        Mock Test-PxInstalled { $true }
        Remove-PxProxy
        Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter { $CommandLine -eq 'scoop uninstall px' }
        Test-Path (Get-PxInstalledMarkerPath) | Should -BeFalse
    }

    It "does not uninstall px when no marker exists" {
        Remove-Item (Get-PxInstalledMarkerPath) -ErrorAction SilentlyContinue
        Remove-PxProxy
        Should -Invoke Invoke-CommandLine -Times 0
    }

    It "keeps the marker when the uninstall is skipped because px is not on PATH" {
        Set-Content -Path (Get-PxInstalledMarkerPath) -Value 'x'
        Mock Test-PxInstalled { $false }
        Remove-PxProxy
        Should -Invoke Invoke-CommandLine -Times 0
        Test-Path (Get-PxInstalledMarkerPath) | Should -BeTrue
    }

    It "deletes the px config file" {
        Set-Content -Path (Get-PxConfigPath) -Value 'stale'
        Remove-PxProxy
        Test-Path (Get-PxConfigPath) | Should -BeFalse
    }
}

Describe "Invoke-PxProxy" {
    It "dispatches install" {
        Mock Install-PxProxy { }
        Invoke-PxProxy -Action install
        Should -Invoke Install-PxProxy -Times 1
    }

    It "dispatches start with the ProxyHost override" {
        Mock Start-PxProxy { }
        Invoke-PxProxy -Action start -ProxyHost 'x.corp:8080'
        Should -Invoke Start-PxProxy -Times 1 -ParameterFilter { $ProxyHost -eq 'x.corp:8080' }
    }

    It "dispatches stop" {
        Mock Stop-PxProxy { }
        Invoke-PxProxy -Action stop
        Should -Invoke Stop-PxProxy -Times 1
    }

    It "dispatches test" {
        Mock Test-PxProxy { $true }
        Invoke-PxProxy -Action test
        Should -Invoke Test-PxProxy -Times 1
    }

    It "throws when the test action fails, so the caller sees a non-zero exit code" {
        Mock Test-PxProxy { $false }
        { Invoke-PxProxy -Action test } | Should -Throw
    }

    It "does not throw when the test action succeeds" {
        Mock Test-PxProxy { $true }
        { Invoke-PxProxy -Action test } | Should -Not -Throw
    }

    It "dispatches remove" {
        Mock Remove-PxProxy { }
        Invoke-PxProxy -Action remove
        Should -Invoke Remove-PxProxy -Times 1
    }
}
