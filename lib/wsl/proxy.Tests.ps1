<#
.DESCRIPTION
    Pester tests for lib/proxy.ps1 - WSL proxy configuration with auto-detection
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    # Source setProxy.ps1 in library mode so its functions exist for mocking
    $env:SETPROXY_LIBRARY_MODE = '1'
    Start-SutIsolation
    . "$PSScriptRoot\wsl.ps1"
    . "$PSScriptRoot\..\..\tools\proxy\setProxy.ps1"
}

AfterAll {
    Remove-Item Env:\SETPROXY_LIBRARY_MODE -ErrorAction SilentlyContinue
    Stop-SutIsolation
}

Describe "Install-WslProxy" {
    BeforeEach {
        Mock Assert-WslDistroExists { }
        Mock Get-WslDefaultUser { "developer" }
        Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
        Mock Stop-WslDistro { }
        # Default prompt answers — filtered mocks take precedence, so tests only
        # override the prompts they care about. Unfiltered Read-Host mocks at test
        # level still act as the fallback for unmatched prompts (e.g. credentials).
        Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "A" }
        Mock Read-Host -ParameterFilter { $Prompt -like "*Auth method*" } -MockWith { "B" }
        Mock Get-UserConfirmation -ParameterFilter { $message -like "*Use this proxy*" } -MockWith { $true }
        Mock Get-UserConfirmation -ParameterFilter { $message -like "*provide proxy credentials*" } -MockWith { $false }
        # Default Negotiate bootstrap creds — used whenever a test selects the
        # Negotiate auth path. Override per-test to exercise the empty-creds
        # rejection path.
        Mock Get-NegotiateBootstrapCredential { "bsuser:bspass@" }
    }

    Context "Auto-terminate after successful proxy configuration" {
        It "Should terminate the distribution on success so a fresh shell picks up env vars" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Stop-WslDistro -Times 1 -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should terminate the distribution on Remove teardown success" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "R" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Stop-WslDistro -Times 1 -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should not terminate when configuration fails" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            Install-WslProxy -DistroName "Debian" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

            Should -Invoke Stop-WslDistro -Times 0
        }

        It "Should return true and emit a warning (not error) when Stop-WslDistro throws after a successful configuration" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Stop-WslDistro { throw "Failed to terminate distribution 'Debian' after 3 attempts." }
            Mock Write-Warning { }

            $result = Install-WslProxy -DistroName "Debian" -Confirm:$false

            $result | Should -BeTrue
            Should -Invoke Write-Warning -ParameterFilter {
                $Message -like "*Proxy was configured successfully*auto-terminate failed*"
            }
        }
    }

    Context "Auto — PAC resolves to proxy URL, no credentials" {
        It "Should confirm detected proxy and call setup-proxy.sh with proxy URL" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }

            $originalNoProxy = $env:NO_PROXY
            try {
                Remove-Item Env:\NO_PROXY -ErrorAction SilentlyContinue

                Install-WslProxy -DistroName "Debian" -Confirm:$false

                Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                    $Arguments -contains "--proxy-url=http://proxy.corp.com:8080" -and
                    $Arguments -contains "--no-proxy=localhost,127.0.0.1" -and
                    $Arguments -contains "--username=developer"
                }
            }
            finally {
                if ($null -ne $originalNoProxy) {
                    $env:NO_PROXY = $originalNoProxy
                }
            }
        }
    }

    Context "Auto — PAC resolves to proxy URL, with credentials" {
        It "Should embed credentials in proxy URL" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Get-ProxyCredentialsFromUser { "user1:p%40ss@" }
            Mock Get-UserConfirmation -ParameterFilter { $message -like "*provide proxy credentials*" } -MockWith { $true }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://user1:p%40ss@proxy.corp.com:8080"
            }
        }
    }

    Context "Auto — PAC resolves to DIRECT, collapses to Remove teardown" {
        It "Should call setup-proxy.sh with --remove flag and skip auth prompt" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = $null; IsDirect = $true } }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--remove" -and
                $Arguments -contains "--username=developer"
            }
            Should -Invoke Read-Host -Times 0 -ParameterFilter { $Prompt -like "*Auth method*" }
            Should -Invoke Get-UserConfirmation -Times 0 -ParameterFilter { $message -like "*Use this proxy*" }
        }
    }

    Context "Auto — user rejects detected proxy" {
        It "Should throw with a hint to re-run with Manual and not dispatch" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Get-UserConfirmation -ParameterFilter { $message -like "*Use this proxy*" } -MockWith { $false }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*rejected*Re-run*"
            Should -Invoke Invoke-WslDistroScript -Times 0
        }
    }

    Context "Auto — no PAC detected" {
        It "Should throw with a hint to re-run with Manual and not dispatch" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
            Mock Get-ProxyFromPac { $null }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*No PAC*Re-run*"
            Should -Invoke Invoke-WslDistroScript -Times 0
        }
    }

    Context "Manual — user enters host:port" {
        It "Should use manually entered proxy URL" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "M" }
            Mock Read-Host -ParameterFilter { $Prompt -like "*host:port*" } -MockWith { "myproxy.com:8080" }
            Mock Get-ProxyFromPac { throw "PAC must not be probed on Manual path" }
            # Credentials prompt → N (fallback)
            Mock Read-Host { "N" }

            $originalNoProxy = $env:NO_PROXY
            try {
                Remove-Item Env:\NO_PROXY -ErrorAction SilentlyContinue

                Install-WslProxy -DistroName "Debian" -Confirm:$false

                Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                    $Arguments -contains "--proxy-url=http://myproxy.com:8080" -and
                    $Arguments -contains "--no-proxy=localhost,127.0.0.1"
                }
                # PAC detection must not run on the Manual path
                Should -Invoke Get-ProxyFromPac -Times 0
            }
            finally {
                if ($null -ne $originalNoProxy) {
                    $env:NO_PROXY = $originalNoProxy
                }
            }
        }

        It "Should throw when host:port is empty" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "M" }
            Mock Read-Host -ParameterFilter { $Prompt -like "*host:port*" } -MockWith { "" }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*host:port*"
            Should -Invoke Invoke-WslDistroScript -Times 0
        }
    }

    Context "Remove — dispatches teardown" {
        It "Should call setup-proxy.sh with --remove flag" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "R" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--remove" -and
                $Arguments -contains "--username=developer"
            }
        }

        It "Should skip auth method and credentials prompts" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "R" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Read-Host -Times 0 -ParameterFilter { $Prompt -like "*Auth method*" }
            Should -Invoke Get-UserConfirmation -Times 0 -ParameterFilter { $message -like "*provide proxy credentials*" }
        }

        It "Should not run PAC detection" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "R" }
            Mock Get-ProxyFromPac { throw "PAC must not be probed on Remove path" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-ProxyFromPac -Times 0
        }
    }

    Context "Invalid mode choice" {
        It "Should throw on unrecognized input" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "X" }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*Invalid choice*"
            Should -Invoke Invoke-WslDistroScript -Times 0
        }
    }

    Context "NO_PROXY environment variable" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }
        }

        It "Should use existing NO_PROXY env var when set" {
            $originalNoProxy = $env:NO_PROXY
            try {
                $env:NO_PROXY = "localhost,127.0.0.1,*.corp.com,10.0.0.0/8"

                Install-WslProxy -DistroName "Debian" -Confirm:$false

                Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                    $Arguments -contains "--no-proxy=localhost,127.0.0.1,*.corp.com,10.0.0.0/8"
                }
            }
            finally {
                if ($null -eq $originalNoProxy) {
                    Remove-Item Env:\NO_PROXY -ErrorAction SilentlyContinue
                }
                else {
                    $env:NO_PROXY = $originalNoProxy
                }
            }
        }

        It "Should fall back to default when NO_PROXY env var is not set" {
            $originalNoProxy = $env:NO_PROXY
            try {
                Remove-Item Env:\NO_PROXY -ErrorAction SilentlyContinue

                Install-WslProxy -DistroName "Debian" -Confirm:$false

                Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                    $Arguments -contains "--no-proxy=localhost,127.0.0.1"
                }
            }
            finally {
                if ($null -ne $originalNoProxy) {
                    $env:NO_PROXY = $originalNoProxy
                }
            }
        }
    }

    Context "Credential masking in output" {
        It "Should mask credentials in proxy URL output" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Get-ProxyCredentialsFromUser { "user1:p%40ss@" }
            Mock Write-Information { }
            Mock Get-UserConfirmation -ParameterFilter { $message -like "*provide proxy credentials*" } -MockWith { $true }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*Proxy URL:*username*proxy.corp.com:8080*" -and $MessageData -notlike "*p%40ss*"
            }
        }
    }

    Context "Prerequisite checks" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }
        }

        It "Should throw when distribution does not exist" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist." }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*does not exist*"
        }

        It "Should throw when no default user is configured" {
            Mock Get-WslDefaultUser { $null }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*default user*"
        }

        It "Should provide setup-user command in error message when no user" {
            Mock Get-WslDefaultUser { $null }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*setup-user*"
        }
    }

    Context "SupportsShouldProcess" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }
        }

        It "Should not execute script when -WhatIf is specified" {
            Install-WslProxy -DistroName "Debian" -WhatIf

            Should -Invoke Invoke-WslDistroScript -Times 0
        }

        It "Should execute script when -Confirm:false is specified" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1
        }
    }

    Context "Exit code handling" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }
        }

        It "Should return true on exit code 0 (success)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

            $result = Install-WslProxy -DistroName "Debian" -Confirm:$false
            $result | Should -Be $true
        }

        It "Should return false and write error on exit code 1 (prerequisite failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 1; return 1 }

            $result = Install-WslProxy -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Prerequisite check failed*"
        }

        It "Should return false and write error on exit code 2 (configuration failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            $result = Install-WslProxy -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Configuration failed*"
        }

        It "Should return false and write error on exit code 3 (verification failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 3; return 3 }

            $result = Install-WslProxy -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Verification failed*"
        }

        It "Should return false and write error on exit code 4 (argument error)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 4; return 4 }

            $result = Install-WslProxy -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Argument error*"
        }

        It "Should return false and write error on unexpected exit code" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 99; return 99 }

            $result = Install-WslProxy -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*exit code: 99*"
        }
    }

    Context "Auth method selection" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
        }

        It "Should dispatch to setup-proxy.sh when Basic is chosen" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*setup-proxy.sh" -and $ScriptPath -notlike "*setup-proxy-negotiate.sh"
            }
        }

        It "Should dispatch to setup-proxy-negotiate.sh when Negotiate is chosen" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Auth method*" } -MockWith { "N" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*setup-proxy-negotiate.sh"
            }
        }

        It "Should not embed credentials in --proxy-url= when Negotiate is chosen" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Auth method*" } -MockWith { "N" }
            Mock Get-ProxyCredentialsFromUser { "user1:p%40ss@" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            # Basic-mode prompt must not be triggered on the Negotiate path.
            Should -Invoke Get-ProxyCredentialsFromUser -Times 0
            # The clean (cred-less) URL goes on the cmdline; bootstrap creds are
            # piped via stdin instead (asserted in the bootstrap-credentials context).
            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://proxy.corp.com:8080"
            }
        }

        It "Should print auth mode in status output (Basic)" {
            Mock Write-Information { }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*Auth mode:*basic*"
            }
        }

        It "Should print auth mode in status output (Negotiate)" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Auth method*" } -MockWith { "N" }
            Mock Write-Information { }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*Auth mode:*negotiate*"
            }
        }
    }

    Context "Negotiate bootstrap credentials" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Read-Host -ParameterFilter { $Prompt -like "*Auth method*" } -MockWith { "N" }
        }

        It "Should prompt for bootstrap creds via Get-NegotiateBootstrapCredential" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-NegotiateBootstrapCredential -Times 1
        }

        It "Should pipe the bootstrap URL via -StdinInput to Invoke-WslDistroScript" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $StdinInput -eq "http://bsuser:bspass@proxy.corp.com:8080"
            }
        }

        It "Should not include bootstrap creds in --proxy-url= (clean URL on cmdline)" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://proxy.corp.com:8080" -and
                -not ($Arguments -match "bsuser") -and
                -not ($Arguments -match "bspass")
            }
        }

        It "Should throw when no bootstrap creds are provided" {
            Mock Get-NegotiateBootstrapCredential { "" }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*Bootstrap credentials*required*"
            Should -Invoke Invoke-WslDistroScript -Times 0
        }

        It "Should surface a Negotiate-specific error on exit 2 (not the Basic 'file system permissions' message)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            $result = Install-WslProxy -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Negotiate bootstrap install failed*exit 2*"
        }

        It "Should not pipe stdin on the Basic path" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Auth method*" } -MockWith { "B" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            # On the Basic path Install-WslProxy must not call the negotiate
            # script and must not invoke the bootstrap-cred prompt.
            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -notlike "*setup-proxy-negotiate.sh" -and
                [string]::IsNullOrEmpty($StdinInput)
            }
            Should -Invoke Get-NegotiateBootstrapCredential -Times 0
        }

        It "Should report Negotiate Phase-1 targets, not the Basic-mode .profile/Docker/Podman list" {
            # Mis-report guard: the success banner must reflect what bootstrap
            # actually touched (apt config + tooling), not the Basic-mode targets.
            Mock Write-Information { }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*Negotiate Phase 1*bootstrap install*"
            }
            Should -Invoke Write-Information -Times 0 -ParameterFilter {
                $MessageData -like "*~/.docker/config.json*" -or $MessageData -like "*containers.conf*"
            }
        }
    }

    Context "Sibling script artifacts" {
        BeforeAll {
            $script:NegotiateScript = Get-Content (Join-Path $PSScriptRoot "scripts\setup-proxy-negotiate.sh") -Raw
        }

        It "setup-proxy-negotiate.sh exists" {
            Test-Path (Join-Path $PSScriptRoot "scripts\setup-proxy-negotiate.sh") | Should -Be $true
        }

        It "setup-proxy-negotiate.sh reads BOOTSTRAP_PROXY_URL from stdin" {
            $script:NegotiateScript | Should -Match 'read -r BOOTSTRAP_PROXY_URL'
        }

        It "setup-proxy-negotiate.sh refuses to read stdin when invoked from a TTY" {
            $script:NegotiateScript | Should -Match '\[ -t 0 \]'
        }

        It "setup-proxy-negotiate.sh writes the negotiate-bootstrap mode marker" {
            $script:NegotiateScript | Should -Match '/etc/wsl-manager'
            $script:NegotiateScript | Should -Match 'proxy-mode'
            $script:NegotiateScript | Should -Match 'negotiate-bootstrap'
        }

        It "setup-proxy-negotiate.sh traps EXIT to remove the temporary pip.conf" {
            $script:NegotiateScript | Should -Match 'trap cleanup_pip_conf EXIT'
            $script:NegotiateScript | Should -Match 'rm -f "\$PIP_CONF_FILE"'
        }

        It "setup-proxy-negotiate.sh never exports HTTP_PROXY-style env vars" {
            # The threat model rejects HTTP_PROXY=user:pass@... in env. Phase 1
            # writes config files only; no `export` of proxy env vars anywhere.
            $script:NegotiateScript | Should -Not -Match '(?im)^\s*export\s+(HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy)\b'
        }

        It "setup-proxy-negotiate.sh strips the legacy Basic-mode proxy block from .profile and .bashrc" {
            # Migration: a distro previously configured by SC-007 Basic mode has
            # `export http_proxy=user:pass@...` in ~/.profile. Negotiate bootstrap
            # must remove that managed block so the creds stop leaking into env
            # during Phases 1-3 (see SC-036b UAT step 3).
            $script:NegotiateScript | Should -Match 'remove_managed_block "\$PROFILE"'
            $script:NegotiateScript | Should -Match 'remove_managed_block "\$BASHRC"'
            $script:NegotiateScript | Should -Match 'sed -i ".*MARKER_BEGIN.*MARKER_END.*d" "\$file"'
        }

        It "setup-proxy-negotiate.sh treats a 407 from apt-get update as a hard failure" {
            # apt-get update exits 0 even when fetches fail behind a 407, so a
            # wrong bootstrap password would otherwise produce a false success
            # (SC-036b UAT step 5). The script must capture the output and abort
            # on 'Proxy Authentication Required'.
            $script:NegotiateScript | Should -Match 'Proxy Authentication Required'
            $script:NegotiateScript | Should -Match 'apt_update_output=\$\(sudo env LC_ALL=C apt-get update'
        }

        It "setup-proxy-negotiate.sh forces the C locale on apt-get update so the 407 line stays English" {
            # apt localizes its output; a translated 'Proxy Authentication Required'
            # would slip past the grep. LC_ALL=C guarantees the English string.
            $script:NegotiateScript | Should -Match 'sudo env LC_ALL=C apt-get update'
        }

        It "setup-proxy-negotiate.sh also fails on an unreachable proxy, not only a 407" {
            # apt-get update exits 0 on failed fetches, so a wrong proxy host
            # (connection refused) on an already-installed distro would otherwise
            # be a false success. Detect fetch/connect failures too.
            $script:NegotiateScript | Should -Match 'Failed to fetch'
            $script:NegotiateScript | Should -Match 'Could not connect|Unable to connect'
        }

        It "setup-proxy-negotiate.sh locks /etc/apt/apt.conf.d/99proxy to root-only (600)" {
            # The apt proxy file holds Basic-auth creds; tee creates it 644
            # (world-readable). Lock it to 600 so creds are not exposed in Phases 1-3.
            $script:NegotiateScript | Should -Match 'chmod 600 /etc/apt/apt.conf.d/99proxy'
        }

        It "setup-proxy-negotiate.sh installs krb5-user, pipx, and px-proxy" {
            $script:NegotiateScript | Should -Match 'apt-get install.*krb5-user.*pipx'
            $script:NegotiateScript | Should -Match 'pipx install px-proxy'
        }

        It "setup-proxy-negotiate.sh skips pipx install when px-proxy already present" {
            # Idempotent re-run: AC requires no-op on second run.
            $script:NegotiateScript | Should -Match 'pipx list'
        }

        It "setup-proxy.sh writes the basic mode marker on success" {
            $script = Get-Content (Join-Path $PSScriptRoot "scripts\setup-proxy.sh") -Raw
            $script | Should -Match '/etc/wsl-manager'
            $script | Should -Match 'proxy-mode'
            $script | Should -Match 'echo "basic"'
        }

        It "setup-proxy.sh removes the mode marker on --remove" {
            $script = Get-Content (Join-Path $PSScriptRoot "scripts\setup-proxy.sh") -Raw
            $script | Should -Match 'rm -f.*MODE_MARKER_FILE'
        }
    }

    Context "Script invocation" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }
        }

        It "Should call script with setup-proxy.sh" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*setup-proxy.sh*"
            }
        }
    }
}

Describe "Get-NegotiateBootstrapCredential" {
    BeforeEach {
        # Silence the informational guidance the function prints.
        Mock Write-Information { }
    }

    It "Returns 'user:percent-encoded-password@' so the URL is safe to embed" {
        # Build the SecureString via AppendChar rather than ConvertTo-SecureString
        # -AsPlainText (which PSScriptAnalyzer rejects even in tests).
        Mock Read-Host -ParameterFilter { $AsSecureString } -MockWith {
            $ss = [System.Security.SecureString]::new()
            'p@ss word'.ToCharArray() | ForEach-Object { $ss.AppendChar($_) }
            $ss
        }
        Mock Read-Host -ParameterFilter { -not $AsSecureString } -MockWith { 'guentherk' }

        $result = Get-NegotiateBootstrapCredential

        # '@' -> %40 and ' ' -> %20, so the creds can be spliced into http://<this>host
        $result | Should -Be 'guentherk:p%40ss%20word@'
    }

    It "Percent-encodes a domain/UPN username so the userinfo segment stays valid" {
        # Corporate logins are often 'DOMAIN\user' or 'user@corp.com'. An
        # unescaped '\' or '@' would corrupt the spliced URL, so the username
        # must be encoded just like the password.
        Mock Read-Host -ParameterFilter { $AsSecureString } -MockWith {
            $ss = [System.Security.SecureString]::new()
            'pw'.ToCharArray() | ForEach-Object { $ss.AppendChar($_) }
            $ss
        }
        Mock Read-Host -ParameterFilter { -not $AsSecureString } -MockWith { 'DOMAIN\user@corp' }

        $result = Get-NegotiateBootstrapCredential

        # '\' -> %5C and '@' -> %40
        $result | Should -Be 'DOMAIN%5Cuser%40corp:pw@'
    }

    It "Returns empty string, warns, and does not prompt for a password when the username is blank" {
        Mock Read-Host -ParameterFilter { -not $AsSecureString } -MockWith { '' }
        Mock Read-Host -ParameterFilter { $AsSecureString } -MockWith { [System.Security.SecureString]::new() }
        Mock Write-Warning { }

        $result = Get-NegotiateBootstrapCredential

        $result | Should -Be ''
        Should -Invoke Write-Warning -Times 1
        Should -Invoke Read-Host -Times 0 -ParameterFilter { $AsSecureString }
    }
}
