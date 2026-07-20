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
        # No local px by default, so Auto exercises the PAC path deterministically
        # regardless of whether a px happens to be running on the host.
        Mock Test-PxProxyAvailable { $false }
        # Default prompt answers — filtered mocks take precedence, so tests only
        # override the prompts they care about.
        Mock Get-UserChoice -ParameterFilter { $message -like "*Proxy setup*" } -MockWith { "Auto" }
        Mock Get-UserConfirmation -MockWith { $true }
        # Auth method defaults to Basic; credentials are empty unless a test asks.
        Mock Get-UserChoice -ParameterFilter { $message -like "*Auth method*" } -MockWith { 'Basic' }
        Mock Get-ProxyCredentialsFromUser { "" }
    }

    Context "Auto-terminate after successful proxy configuration" {
        It "Should terminate the distribution on success so a fresh shell picks up env vars" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Stop-WslDistro -Times 1 -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should terminate the distribution on Remove teardown success" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Proxy setup*" } -MockWith { "Remove" }

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

    Context "Auto — PAC resolves to proxy URL, with Basic credentials" {
        It "Should embed credentials in proxy URL" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Get-ProxyCredentialsFromUser { "user1:p%40ss@" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://user1:p%40ss@proxy.corp.com:8080"
            }
        }

        It "Should pass the Windows username as the credential-prompt default" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-ProxyCredentialsFromUser -Times 1 -ParameterFilter {
                $DefaultUser -eq $env:USERNAME
            }
        }
    }

    Context "Auto — both px and a corporate PAC proxy detected (menu)" {
        BeforeEach {
            Mock Test-PxProxyAvailable { $true }
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
        }

        It "Should target the px endpoint with no credentials or auth prompt when Local is chosen" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Which proxy*" } -MockWith { 'Local' }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://127.0.0.1:3128"
            }
            Should -Invoke Get-ProxyCredentialsFromUser -Times 0
            Should -Invoke Get-UserChoice -Times 0 -ParameterFilter { $message -like "*Auth method*" }
        }

        It "Should target the corporate proxy and ask for an auth method when Corporate is chosen" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Which proxy*" } -MockWith { 'Corporate' }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://proxy.corp.com:8080"
            }
            Should -Invoke Get-UserChoice -Times 1 -ParameterFilter { $message -like "*Auth method*" }
        }

        It "Should not fire a second yes/no confirmation in the two-source menu case" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Which proxy*" } -MockWith { 'Local' }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-UserConfirmation -Times 0
        }
    }

    Context "Auto — px running but PAC resolves to DIRECT (menu)" {
        BeforeEach {
            Mock Test-PxProxyAvailable { $true }
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = $null; IsDirect = $true } }
        }

        It "Should target the px endpoint when Local is chosen" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Which proxy*" } -MockWith { 'Local' }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://127.0.0.1:3128"
            }
        }

        It "Should tear down proxy config and skip auth when Direct is chosen" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Which proxy*" } -MockWith { 'Direct' }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--remove"
            }
            Should -Invoke Get-UserChoice -Times 0 -ParameterFilter { $message -like "*Auth method*" }
        }
    }

    Context "Auto — only the corporate proxy detected (px down)" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
        }

        It "Should confirm and apply the corporate proxy" {
            Mock Get-UserConfirmation -ParameterFilter { $message -like "*corporate proxy*" } -MockWith { $true }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://proxy.corp.com:8080"
            }
        }

        It "Should throw with a Manual hint and not dispatch when the corporate proxy is declined" {
            Mock Get-UserConfirmation -ParameterFilter { $message -like "*corporate proxy*" } -MockWith { $false }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*declined*Re-run*"
            Should -Invoke Invoke-WslDistroScript -Times 0
        }
    }

    Context "Auto — only px detected (no PAC)" {
        BeforeEach {
            Mock Test-PxProxyAvailable { $true }
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
            Mock Get-ProxyFromPac { $null }
        }

        It "Should confirm and target the px endpoint with no credentials or auth prompt" {
            Mock Get-UserConfirmation -ParameterFilter { $message -like "*local px proxy*" } -MockWith { $true }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://127.0.0.1:3128"
            }
            Should -Invoke Get-ProxyCredentialsFromUser -Times 0
            Should -Invoke Get-UserChoice -Times 0 -ParameterFilter { $message -like "*Auth method*" }
        }

        It "Should throw with a Manual hint when px is declined" {
            Mock Get-UserConfirmation -ParameterFilter { $message -like "*local px proxy*" } -MockWith { $false }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*declined*Re-run*"
            Should -Invoke Invoke-WslDistroScript -Times 0
        }
    }

    Context "Auto — PAC resolves to DIRECT, px down (teardown)" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = $null; IsDirect = $true } }
        }

        It "Should confirm, tear down proxy config, and skip the auth prompt" {
            Mock Get-UserConfirmation -ParameterFilter { $message -like "*DIRECT*" } -MockWith { $true }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--remove" -and
                $Arguments -contains "--username=developer"
            }
            Should -Invoke Get-UserChoice -Times 0 -ParameterFilter { $message -like "*Auth method*" }
        }

        It "Should throw with a Manual hint when the teardown is declined" {
            Mock Get-UserConfirmation -ParameterFilter { $message -like "*DIRECT*" } -MockWith { $false }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*declined*Re-run*"
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

    Context "Mode prompt — Enter defaults to Auto" {
        It "Should present Auto/Manual/Remove via Get-UserChoice with Auto as the Enter default" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-UserChoice -Times 1 -ParameterFilter {
                $message -like "*Proxy setup*" -and
                $defaultOption -eq 'Auto' -and
                ($options -contains 'Auto') -and
                ($options -contains 'Manual') -and
                ($options -contains 'Remove')
            }
        }
    }

    Context "Manual — user enters host:port" {
        It "Should use manually entered proxy URL and not probe PAC or px" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Proxy setup*" } -MockWith { "Manual" }
            Mock Read-Host -ParameterFilter { $Prompt -like "*host:port*" } -MockWith { "myproxy.com:8080" }
            Mock Get-ProxyFromPac { throw "PAC must not be probed on Manual path" }

            $originalNoProxy = $env:NO_PROXY
            try {
                Remove-Item Env:\NO_PROXY -ErrorAction SilentlyContinue

                Install-WslProxy -DistroName "Debian" -Confirm:$false

                Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                    $Arguments -contains "--proxy-url=http://myproxy.com:8080" -and
                    $Arguments -contains "--no-proxy=localhost,127.0.0.1"
                }
                # Neither PAC nor px detection runs on the Manual path
                Should -Invoke Get-ProxyFromPac -Times 0
                Should -Invoke Test-PxProxyAvailable -Times 0
            }
            finally {
                if ($null -ne $originalNoProxy) {
                    $env:NO_PROXY = $originalNoProxy
                }
            }
        }

        It "Should throw when host:port is empty" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Proxy setup*" } -MockWith { "Manual" }
            Mock Read-Host -ParameterFilter { $Prompt -like "*host:port*" } -MockWith { "" }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*host:port*"
            Should -Invoke Invoke-WslDistroScript -Times 0
        }
    }

    Context "Remove — dispatches teardown" {
        It "Should call setup-proxy.sh with --remove flag" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Proxy setup*" } -MockWith { "Remove" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--remove" -and
                $Arguments -contains "--username=developer"
            }
        }

        It "Should skip auth method and credentials prompts" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Proxy setup*" } -MockWith { "Remove" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-UserChoice -Times 0 -ParameterFilter { $message -like "*Auth method*" }
            Should -Invoke Get-ProxyCredentialsFromUser -Times 0
        }

        It "Should not run PAC or px detection" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Proxy setup*" } -MockWith { "Remove" }
            Mock Get-ProxyFromPac { throw "PAC must not be probed on Remove path" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-ProxyFromPac -Times 0
            Should -Invoke Test-PxProxyAvailable -Times 0
        }
    }

    Context "NO_PROXY environment variable" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
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

        It "Should always dispatch to setup-proxy.sh" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*setup-proxy.sh"
            }
        }

        It "Should not embed credentials when Anonymous is chosen" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Auth method*" } -MockWith { 'Anonymous' }
            Mock Get-ProxyCredentialsFromUser { "user1:p%40ss@" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-ProxyCredentialsFromUser -Times 0
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

        It "Should print auth mode in status output (Anonymous)" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*Auth method*" } -MockWith { 'Anonymous' }
            Mock Write-Information { }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*Auth mode:*anonymous*"
            }
        }
    }

    Context "Script artifacts" {
        It "The obsolete setup-proxy-negotiate.sh no longer exists" {
            Test-Path (Join-Path $PSScriptRoot "scripts\setup-proxy-negotiate.sh") | Should -Be $false
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

        It "setup-proxy.sh writes proxy exports to /etc/profile.d (SC-042)" {
            $script = Get-Content (Join-Path $PSScriptRoot "scripts\setup-proxy.sh") -Raw
            $script | Should -Match 'PROFILE_D_FILE="/etc/profile.d/wsl-manager-proxy.sh"'
            $script | Should -Match 'tee "\$PROFILE_D_FILE"'
            $script | Should -Match 'export HTTP_PROXY="\$PROXY_URL"'
        }

        It "setup-proxy.sh sources the exports from /etc/zsh/zshenv for zsh (SC-042)" {
            $script = Get-Content (Join-Path $PSScriptRoot "scripts\setup-proxy.sh") -Raw
            $script | Should -Match 'ZSHENV_FILE="/etc/zsh/zshenv"'
            $script | Should -Match '\. \$PROFILE_D_FILE'
        }

        It "setup-proxy.sh removes the proxy exports on --remove (SC-042)" {
            $script = Get-Content (Join-Path $PSScriptRoot "scripts\setup-proxy.sh") -Raw
            $script | Should -Match 'rm -f "\$PROFILE_D_FILE"'
            $script | Should -Match 'sudo sed -i.*ZSHENV_FILE'
        }

        It "setup-proxy.sh migrates away the legacy ~/.profile and /etc/environment blocks (SC-042)" {
            $script = Get-Content (Join-Path $PSScriptRoot "scripts\setup-proxy.sh") -Raw
            $script | Should -Match '/etc/environment'
            $script | Should -Match 'legacy proxy block from \$PROFILE'
        }

        It "setup-proxy.sh exports CA-trust vars for bundled-store tools, guarded on the system bundle (SC-043)" {
            $script = Get-Content (Join-Path $PSScriptRoot "scripts\setup-proxy.sh") -Raw
            $script | Should -Match '\[ -r /etc/ssl/certs/ca-certificates.crt \]'
            $script | Should -Match 'export SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"'
            $script | Should -Match 'export SSL_CERT_DIR="/etc/ssl/certs"'
            $script | Should -Match 'export NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"'
            $script | Should -Match 'export REQUESTS_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"'
            $script | Should -Match 'export PIP_CERT="/etc/ssl/certs/ca-certificates.crt"'
        }
    }

    Context "Script invocation" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy:8080"; IsDirect = $false } }
        }

        It "Should call script with setup-proxy.sh" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*setup-proxy.sh*"
            }
        }
    }
}
