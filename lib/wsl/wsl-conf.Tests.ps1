<#
.DESCRIPTION
    Pester tests for lib/wsl-conf.ps1 - WSL wsl.conf management functions
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\wsl.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Test-WslSystemdConfigured" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Test-WslSystemdConfigured -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should return false when wsl.conf is not found" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When systemd is configured in wsl.conf" {
        It "Should return true when systemd=true is set in [boot] section" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=true`n[user]`ndefault=developer"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true when systemd=true with spaces around equals" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd = true"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true when systemd=true with extra whitespace" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`n  systemd  =  true  "
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $true
        }
    }

    Context "When systemd is not configured in wsl.conf" {
        It "Should return false when [boot] section does not exist" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[user]`ndefault=developer"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when systemd is not set in [boot] section" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`n# systemd=true"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when systemd=false" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=false"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when wsl.conf is empty" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When systemd setting is in different sections" {
        It "Should only check [boot] section, not [other] sections" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[other]`nsystemd=true`n[boot]`nsystemd=false"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Defensive parsing with malformed content" {
        It "Should return false when wsl.conf has missing closing bracket" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                @"
[boot
systemd=true
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when wsl.conf has invalid characters in value" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                @"
[boot]
systemd=tr@ue!
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            # Should return false since value is not "true"
            $result | Should -Be $false
        }

        It "Should return false when wsl.conf has empty [boot] section" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                @"
[boot]

[user]
default=testuser
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return true for first value when wsl.conf has duplicate systemd keys" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                @"
[boot]
systemd=true
systemd=false
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            # Should return true based on first match (early return in parsing logic)
            $result | Should -Be $true
        }

        It "Should not throw exception on any malformed content" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "completely invalid content with no structure @#$%^&*()"
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            # Should gracefully return false without throwing
            { Test-WslSystemdConfigured -DistroName "Debian" } | Should -Not -Throw
            $result = Test-WslSystemdConfigured -DistroName "Debian"
            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslSystemdConfigured -DistroName "" } | Should -Throw
        }
    }
}

Describe "Test-WslInteropConfigured" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Test-WslInteropConfigured -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should return false when wsl.conf is not found" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When Windows interop is fully configured in wsl.conf" {
        It "Should return true when both enabled=true and appendWindowsPath=true are set" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled=true`nappendWindowsPath=true`n[boot]`nsystemd=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true with spaces around equals" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled = true`nappendWindowsPath = true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true with extra whitespace" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[interop]`n  enabled  =  true  `n  appendWindowsPath  =  true  "
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $true
        }
    }

    Context "When Windows interop is not configured in wsl.conf" {
        It "Should return false when [interop] section does not exist" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when only enabled=true is set" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when only appendWindowsPath=true is set" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[interop]`nappendWindowsPath=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when enabled=false" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled=false`nappendWindowsPath=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when appendWindowsPath=false" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled=true`nappendWindowsPath=false"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when wsl.conf is empty" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When interop settings are in different sections" {
        It "Should only check [interop] section, not [other] sections" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[other]`nenabled=true`nappendWindowsPath=true`n[interop]`nenabled=false"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslInteropConfigured -DistroName "" } | Should -Throw
        }
    }
}

Describe "Test-WslAutomountConfigured" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Test-WslAutomountConfigured -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should return false when wsl.conf is not found" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When automount metadata is configured in wsl.conf" {
        It "Should return true when options contains metadata with umask" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[automount]`noptions = `"metadata,umask=022`""
            }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true when options contains metadata without umask" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[automount]`noptions = metadata"
            }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true with user-customized umask value" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[automount]`noptions = `"metadata,umask=077`""
            }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true when options has spaces around equals" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[automount]`noptions  =  `"metadata,umask=022`""
            }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $true
        }
    }

    Context "When automount metadata is not configured in wsl.conf" {
        It "Should return false when [automount] section does not exist" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=true`n[user]`ndefault=developer"
            }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when options key is missing from [automount] section" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[automount]`nenabled=true"
            }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when options does not contain metadata" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[automount]`noptions = `"umask=022`""
            }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when wsl.conf is empty" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When automount options is in different sections" {
        It "Should only check [automount] section, not [other] sections" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[other]`noptions = `"metadata,umask=022`"`n[automount]`nenabled=true"
            }

            $result = Test-WslAutomountConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Test-WslAutomountConfigured -DistroName "" } | Should -Throw
        }
    }
}

Describe "Set-WslConf" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should create new wsl.conf with specified sections" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*sudo tee /etc/wsl.conf*" -and
                $Command -like "*[boot]*" -and
                $Command -like "*systemd=true*"
            }
        }
    }

    Context "When wsl.conf exists with existing sections" {
        It "Should preserve existing [user] section when adding [boot]" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[user]`ndefault=myuser"
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*[user]*" -and
                $Command -like "*default=myuser*" -and
                $Command -like "*[boot]*" -and
                $Command -like "*systemd=true*"
            }
        }

        It "Should update existing [boot] section when systemd value changes" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=false"
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*[boot]*" -and
                $Command -like "*systemd=true*" -and
                $Command -notlike "*systemd=false*"
            }
        }

        It "Should preserve unrelated [network] section when modifying [boot]" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                @"
[boot]
systemd=false

[network]
generateHosts=false
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*[network]*" -and
                $Command -like "*generateHosts=false*"
            }
        }

        It "Should merge multiple sections in one call" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[user]`ndefault=myuser"
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{
                boot    = @{systemd = "true" }
                interop = @{enabled = "true"; appendWindowsPath = "true" }
            } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*[boot]*" -and
                $Command -like "*systemd=true*" -and
                $Command -like "*[interop]*" -and
                $Command -like "*enabled=true*" -and
                $Command -like "*appendWindowsPath=true*"
            }
        }

        It "Should preserve comments in existing wsl.conf" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                @"
# WSL Configuration
[user]
# Default user
default=myuser
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*# WSL Configuration*" -and
                $Command -like "*# Default user*"
            }
        }
    }

    Context "When backing up existing wsl.conf" {
        It "Should create backup when wsl.conf exists" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[user]`ndefault=myuser"
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*sudo cp /etc/wsl.conf /etc/wsl.conf.backup.*"
            }
        }

        It "Should not create backup when wsl.conf does not exist" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*sudo cp /etc/wsl.conf*"
            } -Times 0
        }
    }

    Context "ShouldProcess support" {
        It "Should skip modification when WhatIf is used" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } -WhatIf

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*sudo tee /etc/wsl.conf*"
            } -Times 0
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Set-WslConf -DistroName "" -Sections @{boot = @{systemd = "true" } } } | Should -Throw
        }

        It "Should throw when Sections is empty" {

            Mock Assert-WslDistroExists { }

            { Set-WslConf -DistroName "Debian" -Sections @{} -Confirm:$false } | Should -Throw "*null*"
        }
    }
}
