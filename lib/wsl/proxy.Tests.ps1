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
    }

    Context "PAC detected, resolves to proxy, no credentials" {
        It "Should auto-detect proxy and call setup-proxy.sh with proxy URL" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://proxy.corp.com:8080" -and
                $Arguments -contains "--no-proxy=localhost,127.0.0.1" -and
                $Arguments -contains "--username=developer"
            }
        }
    }

    Context "PAC detected, resolves to proxy, with credentials" {
        It "Should embed credentials in proxy URL" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy.corp.com:8080"; IsDirect = $false } }
            Mock Get-ProxyCredentialsFromUser { "user1:p%40ss@" }
            # First Read-Host: credentials question → Y
            Mock Read-Host { "Y" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://user1:p%40ss@proxy.corp.com:8080"
            }
        }
    }

    Context "PAC detected, resolves to DIRECT, user confirms DIRECT" {
        It "Should call setup-proxy.sh with --remove flag" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = $null; IsDirect = $true } }
            Mock Read-Host { "D" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--remove" -and
                $Arguments -contains "--username=developer"
            }
        }
    }

    Context "PAC detected, DIRECT, user chooses manual entry" {
        It "Should use manually entered proxy URL" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ AutoConfigURL = "http://pac.corp.com/proxy.pac" } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = $null; IsDirect = $true } }
            # First Read-Host: D/M choice → M, Second: host:port, Third: credentials → N
            $script:readHostCallCount = 0
            Mock Read-Host {
                $script:readHostCallCount++
                switch ($script:readHostCallCount) {
                    1 { "M" }
                    2 { "manual.proxy.com:3128" }
                    3 { "N" }
                    default { "" }
                }
            }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://manual.proxy.com:3128"
            }
        }
    }

    Context "No PAC, user enters manual proxy" {
        It "Should prompt for manual proxy and configure it" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
            Mock Get-ProxyFromPac { $null }
            # First Read-Host: M/D choice → M, Second: host:port, Third: credentials → N
            $script:readHostCallCount = 0
            Mock Read-Host {
                $script:readHostCallCount++
                switch ($script:readHostCallCount) {
                    1 { "M" }
                    2 { "myproxy.com:8080" }
                    3 { "N" }
                    default { "" }
                }
            }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://myproxy.com:8080" -and
                $Arguments -contains "--no-proxy=localhost,127.0.0.1"
            }
        }
    }

    Context "No PAC, user chooses DIRECT" {
        It "Should call setup-proxy.sh with --remove flag" {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
            Mock Get-ProxyFromPac { $null }
            Mock Read-Host { "D" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--remove" -and
                $Arguments -contains "--username=developer"
            }
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
            # First Read-Host: credentials question → Y
            Mock Read-Host { "Y" }

            Install-WslProxy -DistroName "Debian" -Confirm:$false

            # Verify masked URL is shown (***username:***@) instead of plaintext credentials
            Should -Invoke Write-Information -ParameterFilter {
                $MessageData -like "*Proxy URL:*username*proxy.corp.com:8080*" -and $MessageData -notlike "*p%40ss*"
            }
        }
    }

    Context "Prerequisite checks" {
        It "Should throw when distribution does not exist" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist." }
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*does not exist*"
        }

        It "Should throw when no default user is configured" {
            Mock Get-WslDefaultUser { $null }
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*default user*"
        }

        It "Should provide setup-user command in error message when no user" {
            Mock Get-WslDefaultUser { $null }
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }

            { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*setup-user*"
        }
    }

    Context "SupportsShouldProcess" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
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
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
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

    Context "Script invocation" {
        BeforeEach {
            Mock Get-InternetSettingsFromRegistry { [PSCustomObject]@{ } }
            Mock Get-ProxyFromPac { @{ ProxyUrl = "http://proxy:8080"; IsDirect = $false } }
            Mock Read-Host { "N" }
        }

        It "Should call script with setup-proxy.sh" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*setup-proxy.sh*"
            }
        }

        It "Should execute script with AsRoot=true" {
            Install-WslProxy -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $AsRoot -eq $true
            }
        }
    }
}
