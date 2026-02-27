<#
.DESCRIPTION
    Pester tests for lib/proxy.ps1 - WSL proxy configuration
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\utils\utils.ps1"
    . "$PSScriptRoot\..\wsl.ps1"
}

Describe "Install-WslProxy" {
    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Install-WslProxy -DistroName "" -Confirm:$false } | Should -Throw
        }

        It "Should throw when no proxy URL provided and HTTPS_PROXY not set" {
            $originalValue = $Env:HTTPS_PROXY
            try {
                $Env:HTTPS_PROXY = $null

                Mock Assert-WslDistroExists { }

                { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*HTTPS_PROXY*"
            }
            finally {
                $Env:HTTPS_PROXY = $originalValue
            }
        }

        It "Should include guidance message when proxy URL missing" {
            $originalValue = $Env:HTTPS_PROXY
            try {
                $Env:HTTPS_PROXY = $null

                Mock Assert-WslDistroExists { }

                { Install-WslProxy -DistroName "Debian" -Confirm:$false } | Should -Throw "*setProxy*"
            }
            finally {
                $Env:HTTPS_PROXY = $originalValue
            }
        }
    }

    Context "Prerequisite checks" {
        It "Should throw when distribution does not exist" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false } | Should -Throw "*does not exist*"
        }

        It "Should throw when no default user is configured" {
            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { $null }

            { Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false } | Should -Throw "*default user*"
        }

        It "Should provide setup-user command in error message when no user" {
            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { $null }

            { Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false } | Should -Throw "*setup-user*"
        }
    }

    Context "Environment variable reading" {
        It "Should read ProxyUrl from Env:HTTPS_PROXY when not provided" {
            $originalValue = $Env:HTTPS_PROXY
            try {
                $Env:HTTPS_PROXY = "http://env-proxy:8080"

                Mock Assert-WslDistroExists { }
                Mock Get-WslDefaultUser { "developer" }
                Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

                Install-WslProxy -DistroName "Debian" -Confirm:$false

                Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                    $Arguments -contains "--proxy-url=http://env-proxy:8080"
                }
            }
            finally {
                $Env:HTTPS_PROXY = $originalValue
            }
        }

        It "Should read NoProxy from Env:NO_PROXY when not provided" {
            $originalNoProxy = $Env:NO_PROXY
            try {
                $Env:NO_PROXY = "internal.corp,10.0.0.0/8"

                Mock Assert-WslDistroExists { }
                Mock Get-WslDefaultUser { "developer" }
                Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

                Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false

                Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                    $Arguments -contains "--no-proxy=internal.corp,10.0.0.0/8"
                }
            }
            finally {
                $Env:NO_PROXY = $originalNoProxy
            }
        }

        It "Should default NoProxy to localhost,127.0.0.1 when Env:NO_PROXY not set" {
            $originalNoProxy = $Env:NO_PROXY
            try {
                $Env:NO_PROXY = $null

                Mock Assert-WslDistroExists { }
                Mock Get-WslDefaultUser { "developer" }
                Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

                Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false

                Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                    $Arguments -contains "--no-proxy=localhost,127.0.0.1"
                }
            }
            finally {
                $Env:NO_PROXY = $originalNoProxy
            }
        }
    }

    Context "SupportsShouldProcess" {
        BeforeEach {
            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
        }

        It "Should not execute script when -WhatIf is specified" {
            Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -WhatIf

            Should -Invoke Invoke-WslDistroScript -Times 0
        }

        It "Should execute script when -Confirm:false is specified" {
            Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1
        }
    }

    Context "Script arguments" {
        BeforeEach {
            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
        }

        It "Should pass correct arguments to Invoke-WslDistroScript" {
            Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -NoProxy "localhost,127.0.0.1" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--proxy-url=http://proxy:8080" -and
                $Arguments -contains "--no-proxy=localhost,127.0.0.1" -and
                $Arguments -contains "--username=developer"
            }
        }

        It "Should call script with setup-proxy.sh" {
            Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*setup-proxy.sh*"
            }
        }

        It "Should execute script with AsRoot=true" {
            Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $AsRoot -eq $true
            }
        }
    }

    Context "Exit code handling" {
        BeforeEach {
            Mock Assert-WslDistroExists { }
            Mock Get-WslDefaultUser { "developer" }
        }

        It "Should return true on exit code 0 (success)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

            $result = Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false

            $result | Should -Be $true
        }

        It "Should return false and write error on exit code 1 (prerequisite failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 1; return 1 }

            $result = Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Prerequisite check failed*"
        }

        It "Should return false and write error on exit code 2 (configuration failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            $result = Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Configuration failed*"
        }

        It "Should return false and write error on exit code 3 (verification failure)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 3; return 3 }

            $result = Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Verification failed*"
        }

        It "Should return false and write error on exit code 4 (argument error)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 4; return 4 }

            $result = Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Argument error*"
        }

        It "Should return false and write error on unexpected exit code" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 99; return 99 }

            $result = Install-WslProxy -DistroName "Debian" -ProxyUrl "http://proxy:8080" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*exit code: 99*"
        }
    }
}
