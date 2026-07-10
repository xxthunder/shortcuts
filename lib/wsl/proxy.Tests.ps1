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
        Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "A" }
        Mock Get-UserConfirmation -ParameterFilter { $message -like "*Use this proxy*" } -MockWith { $true }
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

    Context "Auto — local px proxy detected" {
        BeforeEach {
            Mock Test-PxProxyAvailable { $true }
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
        }

        It "Should target the px endpoint with no credentials when the user picks Px" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*px*" } -MockWith { 'Px' }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://127.0.0.1:3128"
            }
            Should -Invoke Get-ProxyCredentialsFromUser -Times 0
        }

        It "Should not prompt for the PAC confirmation or an auth method when Px is chosen" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*px*" } -MockWith { 'Px' }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-UserConfirmation -Times 0 -ParameterFilter { $message -like "*Use this proxy*" }
            Should -Invoke Get-UserChoice -Times 0 -ParameterFilter { $message -like "*Auth method*" }
        }

        It "Should fall through to the PAC proxy when the user picks Pac" {
            Mock Get-UserChoice -ParameterFilter { $message -like "*px*" } -MockWith { 'Pac' }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-UserConfirmation -Times 1 -ParameterFilter { $message -like "*Use this proxy*" }
            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://proxy.corp.com:8080"
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
            Should -Invoke Get-UserChoice -Times 0 -ParameterFilter { $message -like "*Auth method*" }
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
        It "Should use manually entered proxy URL and not probe PAC or px" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "M" }
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

            Should -Invoke Get-UserChoice -Times 0 -ParameterFilter { $message -like "*Auth method*" }
            Should -Invoke Get-ProxyCredentialsFromUser -Times 0
        }

        It "Should not run PAC or px detection" {
            Mock Read-Host -ParameterFilter { $Prompt -like "*Proxy setup*" } -MockWith { "R" }
            Mock Get-ProxyFromPac { throw "PAC must not be probed on Remove path" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Get-ProxyFromPac -Times 0
            Should -Invoke Test-PxProxyAvailable -Times 0
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
