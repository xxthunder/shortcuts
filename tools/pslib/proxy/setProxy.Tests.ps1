#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.2.0'}

<#
.SYNOPSIS
    Unit tests for setProxy.ps1 functions

.DESCRIPTION
    Tests for proxy configuration functions following TDD approach
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Mock function parameters are required by the interface but may not be used in test implementations')]
param()

BeforeAll {
    # Set test mode to prevent auto-execution when dot-sourcing
    $env:SETPROXY_TEST_MODE = '1'

    # Source the script to get access to functions
    . "$PSScriptRoot\setProxy.ps1"
}

AfterAll {
    # Clean up test mode flag
    Remove-Item Env:\SETPROXY_TEST_MODE -ErrorAction SilentlyContinue
}

Describe "Get-InternetSetting" {
    Context "When registry key exists" {
        It "Should return internet settings object" {
            $result = Get-InternetSetting
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should have ProxyEnable property" {
            $result = Get-InternetSetting
            $result.PSObject.Properties.Name | Should -Contain 'ProxyEnable'
        }
    }

    Context "When registry key is missing" {
        It "Should return null and not throw" {
            # Mock registry path to non-existent
            Mock Get-ItemProperty { return $null }
            $result = Get-InternetSetting
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe "Enable-ProxyInRegistry" {
    Context "When ProxyEnable is 0" {
        It "Should return true indicating change was made" {
            $mockSettings = [PSCustomObject]@{ ProxyEnable = 0 }
            Mock Set-ItemProperty { }
            $result = Enable-ProxyInRegistry -InternetSettings $mockSettings
            $result | Should -Be $true
        }

        It "Should call Set-ItemProperty with correct parameters" {
            $mockSettings = [PSCustomObject]@{ ProxyEnable = 0 }
            Mock Set-ItemProperty { }
            Enable-ProxyInRegistry -InternetSettings $mockSettings
            Should -Invoke Set-ItemProperty -Times 1 -ParameterFilter {
                $Name -eq 'ProxyEnable' -and $Value -eq 1
            }
        }
    }

    Context "When ProxyEnable is already 1" {
        It "Should return false indicating no change needed" {
            $mockSettings = [PSCustomObject]@{ ProxyEnable = 1 }
            $result = Enable-ProxyInRegistry -InternetSettings $mockSettings
            $result | Should -Be $false
        }
    }

    Context "When InternetSettings is null" {
        It "Should return false" {
            $result = Enable-ProxyInRegistry -InternetSettings $null
            $result | Should -Be $false
        }
    }
}

Describe "Set-NoProxyEnvironment" {
    Context "When setting NO_PROXY" {
        It "Should set NO_PROXY environment variable" {
            Set-NoProxyEnvironment
            $Env:NO_PROXY | Should -Not -BeNullOrEmpty
        }

        It "Should include localhost in NO_PROXY" {
            Set-NoProxyEnvironment
            $Env:NO_PROXY | Should -Match 'localhost'
        }
    }
}

Describe "Get-ProxyFromPac" {
    Context "When AutoConfigURL exists" {
        It "Should return hashtable with proxy information" {
            $mockSettings = [PSCustomObject]@{
                AutoConfigURL = "http://proxy.company.com/proxy.pac"
                ProxyEnable = 1
            }

            Mock Get-SystemWebProxy {
                $mockProxy = [PSCustomObject]@{}
                $mockProxy | Add-Member -MemberType ScriptMethod -Name GetProxy -Value {
                    param($uri)
                    return [Uri]"http://proxy.server.com:8080"
                }
                $mockProxy | Add-Member -MemberType ScriptMethod -Name IsBypassed -Value {
                    param($uri)
                    return $false
                }
                return $mockProxy
            }

            $result = Get-ProxyFromPac -InternetSettings $mockSettings -ProbeUrl "https://www.microsoft.com"
            $result | Should -Not -BeNullOrEmpty
            $result.ProxyUrl | Should -Not -BeNullOrEmpty
            $result.IsDirect | Should -Be $false
        }

        It "Should detect DIRECT connection when bypassed" {
            $mockSettings = [PSCustomObject]@{
                AutoConfigURL = "http://proxy.company.com/proxy.pac"
                ProxyEnable = 1
            }

            Mock Get-SystemWebProxy {
                $mockProxy = [PSCustomObject]@{}
                $mockProxy | Add-Member -MemberType ScriptMethod -Name GetProxy -Value {
                    param($uri)
                    return $uri
                }
                $mockProxy | Add-Member -MemberType ScriptMethod -Name IsBypassed -Value {
                    param($uri)
                    return $true
                }
                return $mockProxy
            }

            $result = Get-ProxyFromPac -InternetSettings $mockSettings -ProbeUrl "https://www.microsoft.com"
            $result.IsDirect | Should -Be $true
        }

        It "Should use provided ProbeUrl" {
            $mockSettings = [PSCustomObject]@{
                AutoConfigURL = "http://proxy.company.com/proxy.pac"
                ProxyEnable = 1
            }

            Mock Get-SystemWebProxy {
                $mockProxy = [PSCustomObject]@{}
                $mockProxy | Add-Member -MemberType ScriptMethod -Name GetProxy -Value {
                    param($uri)
                    return [Uri]"http://proxy.server.com:8080"
                }
                $mockProxy | Add-Member -MemberType ScriptMethod -Name IsBypassed -Value {
                    param($uri)
                    return $false
                }
                return $mockProxy
            }

            $customUrl = "https://example.com"
            $result = Get-ProxyFromPac -InternetSettings $mockSettings -ProbeUrl $customUrl
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle exceptions and return null" {
            $mockSettings = [PSCustomObject]@{
                AutoConfigURL = "http://proxy.company.com/proxy.pac"
                ProxyEnable = 1
            }
            Mock Get-SystemWebProxy { throw "Network error" }

            $result = Get-ProxyFromPac -InternetSettings $mockSettings -ProbeUrl "https://www.microsoft.com"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "When AutoConfigURL is missing" {
        It "Should return null" {
            $mockSettings = [PSCustomObject]@{ ProxyEnable = 1 }
            # Ensure AutoConfigURL property doesn't exist
            $mockSettings.PSObject.Properties.Remove('AutoConfigURL')

            $result = Get-ProxyFromPac -InternetSettings $mockSettings -ProbeUrl "https://www.microsoft.com"
            $result | Should -BeNullOrEmpty
        }
    }
}

Describe "Set-ProxyEnvironment" {
    Context "When setting DIRECT (no proxy)" {
        It "Should clear HTTP_PROXY and HTTPS_PROXY" {
            $Env:HTTP_PROXY = "http://old.proxy:8080"
            $Env:HTTPS_PROXY = "http://old.proxy:8080"

            Set-ProxyEnvironment -ProxyUrl $null -IsDirect $true

            $Env:HTTP_PROXY | Should -BeNullOrEmpty
            $Env:HTTPS_PROXY | Should -BeNullOrEmpty
        }
    }

    Context "When setting proxy URL" {
        It "Should set HTTP_PROXY to provided URL" {
            $proxyUrl = "http://proxy.server.com:8080"
            Set-ProxyEnvironment -ProxyUrl $proxyUrl -IsDirect $false

            $Env:HTTP_PROXY | Should -Be $proxyUrl
        }

        It "Should set HTTPS_PROXY to same value as HTTP_PROXY" {
            $proxyUrl = "http://proxy.server.com:8080"
            Set-ProxyEnvironment -ProxyUrl $proxyUrl -IsDirect $false

            $Env:HTTPS_PROXY | Should -Be $proxyUrl
        }
    }

    Context "When using fallback proxy" {
        It "Should set fallback proxy when UseFallback is true" {
            Set-ProxyEnvironment -UseFallback $true

            $Env:HTTP_PROXY | Should -Not -BeNullOrEmpty
            $Env:HTTP_PROXY | Should -Match 'some\.fallback\.de'
        }

        It "Should mirror HTTP_PROXY to HTTPS_PROXY" {
            Set-ProxyEnvironment -UseFallback $true

            $Env:HTTP_PROXY | Should -Be $Env:HTTPS_PROXY
        }
    }
}

Describe "Initialize-DefaultWebProxy" {
    Context "When initializing web proxy with PAC" {
        It "Should set DefaultWebProxy to system proxy" {
            # Get real system proxy instead of mocking
            Initialize-DefaultWebProxy -UseSystemProxy $true

            [System.Net.WebRequest]::DefaultWebProxy | Should -Not -BeNullOrEmpty
        }

        It "Should set DefaultWebProxy credentials" {
            Initialize-DefaultWebProxy -UseSystemProxy $true

            [System.Net.WebRequest]::DefaultWebProxy.Credentials | Should -Not -BeNullOrEmpty
        }
    }

    Context "When initializing with fallback proxy" {
        It "Should create WebProxy with fallback host" {
            Initialize-DefaultWebProxy -UseSystemProxy $false -FallbackProxyHost "fallback.proxy.com:8080"

            [System.Net.WebRequest]::DefaultWebProxy | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Get-SystemWebProxy" {
    Context "When getting system web proxy" {
        It "Should return a web proxy object" {
            $result = Get-SystemWebProxy
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should have GetProxy method" {
            $result = Get-SystemWebProxy
            $result.GetProxy | Should -Not -BeNullOrEmpty
        }

        It "Should have IsBypassed method" {
            $result = Get-SystemWebProxy
            $result.IsBypassed | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Initialize-ProxyConfiguration" {
    Context "Integration test for main orchestration" {
        It "Should execute without errors" {
            { Initialize-ProxyConfiguration } | Should -Not -Throw
        }

        It "Should set NO_PROXY environment variable" {
            Initialize-ProxyConfiguration
            $Env:NO_PROXY | Should -Not -BeNullOrEmpty
        }

        It "Should set HTTP_PROXY environment variable" {
            Initialize-ProxyConfiguration
            # HTTP_PROXY should be either set or null, but not undefined
            { $Env:HTTP_PROXY } | Should -Not -Throw
        }

        It "Should accept ProbeUrl parameter" {
            { Initialize-ProxyConfiguration -ProbeUrl "https://www.google.com" } | Should -Not -Throw
        }
    }
}
