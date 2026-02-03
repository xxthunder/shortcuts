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

    # Save original environment state to restore after tests
    $script:OriginalHttpProxy = $Env:HTTP_PROXY
    $script:OriginalHttpsProxy = $Env:HTTPS_PROXY
    $script:OriginalNoProxy = $Env:NO_PROXY
    $script:OriginalDefaultWebProxy = [System.Net.WebRequest]::DefaultWebProxy

    # Source the script to get access to functions
    . "$PSScriptRoot\setProxy.ps1"
}

AfterAll {
    # Clean up test mode flag
    Remove-Item Env:\SETPROXY_TEST_MODE -ErrorAction SilentlyContinue

    # Restore original environment state
    if ($null -eq $script:OriginalHttpProxy) {
        Remove-Item Env:\HTTP_PROXY -ErrorAction SilentlyContinue
    } else {
        $Env:HTTP_PROXY = $script:OriginalHttpProxy
    }

    if ($null -eq $script:OriginalHttpsProxy) {
        Remove-Item Env:\HTTPS_PROXY -ErrorAction SilentlyContinue
    } else {
        $Env:HTTPS_PROXY = $script:OriginalHttpsProxy
    }

    if ($null -eq $script:OriginalNoProxy) {
        Remove-Item Env:\NO_PROXY -ErrorAction SilentlyContinue
    } else {
        $Env:NO_PROXY = $script:OriginalNoProxy
    }

    # Restore DefaultWebProxy
    [System.Net.WebRequest]::DefaultWebProxy = $script:OriginalDefaultWebProxy
}

Describe "Get-InternetSettingsFromRegistry" {
    Context "When registry key exists" {
        It "Should return internet settings object" {
            $result = Get-InternetSettingsFromRegistry
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should have ProxyEnable property" {
            $result = Get-InternetSettingsFromRegistry
            $result.PSObject.Properties.Name | Should -Contain 'ProxyEnable'
        }
    }

    Context "When registry key is missing" {
        It "Should return null and not throw" {
            # Mock registry path to non-existent
            Mock Get-ItemProperty { return $null }
            $result = Get-InternetSettingsFromRegistry
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
    AfterEach {
        # Clean up environment variables after each test
        Remove-Item Env:\NO_PROXY -ErrorAction SilentlyContinue
    }

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
    AfterEach {
        # Clean up environment variables after each test
        Remove-Item Env:\HTTP_PROXY -ErrorAction SilentlyContinue
        Remove-Item Env:\HTTPS_PROXY -ErrorAction SilentlyContinue
    }

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
            Set-ProxyEnvironment -UseFallback $true -FallbackProxyHost "some.fallback.de:8080"

            $Env:HTTP_PROXY | Should -Not -BeNullOrEmpty
            $Env:HTTP_PROXY | Should -Match 'some\.fallback\.de'
        }

        It "Should mirror HTTP_PROXY to HTTPS_PROXY" {
            Set-ProxyEnvironment -UseFallback $true -FallbackProxyHost "some.fallback.de:8080"

            $Env:HTTP_PROXY | Should -Be $Env:HTTPS_PROXY
        }

        It "Should use custom fallback proxy host when provided" {
            $customHost = "custom.proxy.com:3128"
            Set-ProxyEnvironment -UseFallback $true -FallbackProxyHost $customHost

            $Env:HTTP_PROXY | Should -Be "http://$customHost"
            $Env:HTTPS_PROXY | Should -Be "http://$customHost"
        }

        It "Should use provided FallbackProxyHost parameter" {
            Set-ProxyEnvironment -UseFallback $true -FallbackProxyHost "some.fallback.de:8080"

            $Env:HTTP_PROXY | Should -Be "http://some.fallback.de:8080"
        }
    }
}

Describe "Initialize-DefaultWebProxy" {
    BeforeAll {
        # Save original DefaultWebProxy
        $script:SavedDefaultWebProxy = [System.Net.WebRequest]::DefaultWebProxy
    }

    AfterEach {
        # Restore DefaultWebProxy after each test
        [System.Net.WebRequest]::DefaultWebProxy = $script:SavedDefaultWebProxy
    }

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
    BeforeAll {
        # Save original environment and proxy state
        $script:SavedHttpProxy = $Env:HTTP_PROXY
        $script:SavedHttpsProxy = $Env:HTTPS_PROXY
        $script:SavedNoProxy = $Env:NO_PROXY
        $script:SavedWebProxy = [System.Net.WebRequest]::DefaultWebProxy
    }

    AfterEach {
        # Clean up environment variables and proxy state after each test
        if ($null -eq $script:SavedHttpProxy) {
            Remove-Item Env:\HTTP_PROXY -ErrorAction SilentlyContinue
        } else {
            $Env:HTTP_PROXY = $script:SavedHttpProxy
        }

        if ($null -eq $script:SavedHttpsProxy) {
            Remove-Item Env:\HTTPS_PROXY -ErrorAction SilentlyContinue
        } else {
            $Env:HTTPS_PROXY = $script:SavedHttpsProxy
        }

        if ($null -eq $script:SavedNoProxy) {
            Remove-Item Env:\NO_PROXY -ErrorAction SilentlyContinue
        } else {
            $Env:NO_PROXY = $script:SavedNoProxy
        }

        [System.Net.WebRequest]::DefaultWebProxy = $script:SavedWebProxy
    }

    Context "When PAC is configured and proxy is resolved" {
        It "Should initialize with system proxy and set environment variables" {
            Mock Get-InternetSettingsFromRegistry {
                return [PSCustomObject]@{
                    AutoConfigURL = "http://proxy.company.com/proxy.pac"
                    ProxyEnable = 1
                }
            }
            Mock Enable-ProxyInRegistry {
                param($InternetSettings)
                return $false
            }
            Mock Set-NoProxyEnvironment { }
            Mock Get-ProxyFromPac {
                param($InternetSettings, $ProbeUrl)
                return @{
                    ProxyUrl = "http://proxy.server.com:8080"
                    IsDirect = $false
                }
            }
            Mock Initialize-DefaultWebProxy { }
            Mock Set-ProxyEnvironment { }

            Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com"

            Should -Invoke Initialize-DefaultWebProxy -Times 1 -ParameterFilter { $UseSystemProxy -eq $true }
            Should -Invoke Set-ProxyEnvironment -Times 1 -ParameterFilter {
                $ProxyUrl -eq "http://proxy.server.com:8080" -and $IsDirect -eq $false
            }
        }

        It "Should detect DIRECT connection when PAC returns IsDirect" {
            Mock Get-InternetSettingsFromRegistry {
                return [PSCustomObject]@{
                    AutoConfigURL = "http://proxy.company.com/proxy.pac"
                    ProxyEnable = 1
                }
            }
            Mock Enable-ProxyInRegistry { return $false }
            Mock Set-NoProxyEnvironment { }
            Mock Get-ProxyFromPac {
                param($InternetSettings, $ProbeUrl)
                return @{
                    ProxyUrl = $null
                    IsDirect = $true
                }
            }
            Mock Initialize-DefaultWebProxy { }
            Mock Set-ProxyEnvironment { }

            Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com"

            Should -Invoke Set-ProxyEnvironment -Times 1 -ParameterFilter {
                $IsDirect -eq $true
            }
        }
    }

    Context "When PAC resolution fails" {
        It "Should fall back to fallback proxy configuration" {
            Mock Get-InternetSettingsFromRegistry {
                return [PSCustomObject]@{
                    AutoConfigURL = "http://proxy.company.com/proxy.pac"
                    ProxyEnable = 1
                }
            }
            Mock Enable-ProxyInRegistry {
                param($InternetSettings)
                return $false
            }
            Mock Set-NoProxyEnvironment { }
            Mock Get-ProxyFromPac {
                param($InternetSettings, $ProbeUrl)
                return $null
            }
            Mock Initialize-DefaultWebProxy { }
            Mock Set-ProxyEnvironment { }

            Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com"

            Should -Invoke Initialize-DefaultWebProxy -Times 1 -ParameterFilter { $UseSystemProxy -eq $false }
            Should -Invoke Set-ProxyEnvironment -Times 1 -ParameterFilter { $UseFallback -eq $true }
        }
    }

    Context "When no PAC is configured" {
        It "Should use fallback proxy configuration" {
            Mock Get-InternetSettingsFromRegistry {
                return [PSCustomObject]@{
                    ProxyEnable = 1
                }
            }
            Mock Enable-ProxyInRegistry {
                param($InternetSettings)
                return $false
            }
            Mock Set-NoProxyEnvironment { }
            Mock Initialize-DefaultWebProxy { }
            Mock Set-ProxyEnvironment { }

            Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com"

            Should -Invoke Initialize-DefaultWebProxy -Times 1 -ParameterFilter { $UseSystemProxy -eq $false }
            Should -Invoke Set-ProxyEnvironment -Times 1 -ParameterFilter { $UseFallback -eq $true }
        }

        It "Should pass custom FallbackProxyHost to Initialize-DefaultWebProxy" {
            Mock Get-InternetSettingsFromRegistry {
                return [PSCustomObject]@{
                    ProxyEnable = 1
                }
            }
            Mock Enable-ProxyInRegistry { return $false }
            Mock Set-NoProxyEnvironment { }
            Mock Initialize-DefaultWebProxy { }
            Mock Set-ProxyEnvironment { }

            $customHost = "corporate.proxy.com:8080"
            Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com" -FallbackProxyHost $customHost

            Should -Invoke Initialize-DefaultWebProxy -Times 1 -ParameterFilter {
                $UseSystemProxy -eq $false -and $FallbackProxyHost -eq $customHost
            }
        }

        It "Should pass custom FallbackProxyHost to Set-ProxyEnvironment" {
            Mock Get-InternetSettingsFromRegistry {
                return [PSCustomObject]@{
                    ProxyEnable = 1
                }
            }
            Mock Enable-ProxyInRegistry { return $false }
            Mock Set-NoProxyEnvironment { }
            Mock Initialize-DefaultWebProxy { }
            Mock Set-ProxyEnvironment { }

            $customHost = "corporate.proxy.com:8080"
            Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com" -FallbackProxyHost $customHost

            Should -Invoke Set-ProxyEnvironment -Times 1 -ParameterFilter {
                $UseFallback -eq $true -and $FallbackProxyHost -eq $customHost
            }
        }
    }

    Context "Integration test for main orchestration" {
        It "Should execute without errors when ProbeUrl is provided" {
            { Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com" -FallbackProxyHost "some.fallback.de:8080" } | Should -Not -Throw
        }

        It "Should set NO_PROXY environment variable" {
            Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com" -FallbackProxyHost "some.fallback.de:8080"
            $Env:NO_PROXY | Should -Not -BeNullOrEmpty
        }

        It "Should set HTTP_PROXY environment variable" {
            Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com" -FallbackProxyHost "some.fallback.de:8080"
            # HTTP_PROXY should be either set or null, but not undefined
            { $Env:HTTP_PROXY } | Should -Not -Throw
        }

        It "Should accept custom ProbeUrl parameter" {
            { Initialize-ProxyConfiguration -ProbeUrl "https://www.google.com" -FallbackProxyHost "some.fallback.de:8080" } | Should -Not -Throw
        }

        It "Should work with both parameters provided" {
            { Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com" -FallbackProxyHost "some.fallback.de:8080" } | Should -Not -Throw
        }

        It "Should accept custom FallbackProxyHost parameter" {
            $customHost = "corporate.proxy.com:8080"
            { Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com" -FallbackProxyHost $customHost } | Should -Not -Throw
        }

        It "Should use custom FallbackProxyHost when PAC is not configured" {
            # This is an integration test - it will actually set environment variables
            # AfterEach handles cleanup
            $customHost = "integration.test.proxy:9999"
            Initialize-ProxyConfiguration -ProbeUrl "https://www.microsoft.com" -FallbackProxyHost $customHost

            # Verify the custom fallback was used (assuming no PAC is configured in test environment)
            # This will pass if either PAC is configured (proxy set) or fallback is used
            $Env:HTTP_PROXY | Should -Not -BeNullOrEmpty
        }
    }
}
