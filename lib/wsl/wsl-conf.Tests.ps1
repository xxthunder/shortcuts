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
        It "Should create new wsl.conf when cat throws (file not found)" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*sudo tee /etc/wsl.conf*" -and
                $Command -like "*[boot]*" -and
                $Command -like "*systemd=true*"
            }
            # Should not create backup when file didn't exist
            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*sudo cp /etc/wsl.conf*"
            } -Times 0
        }

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

        It "Should write _comment key as comment above section" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{
                automount = @{_comment = 'wsl-manager: sensible DrvFs permissions'; options = 'metadata,umask=022' }
            } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*# wsl-manager: sensible DrvFs permissions*" -and
                $Command -like "*options=metadata,umask=022*" -and
                $Command -notlike "*_comment*"
            }
        }

        It "Should not overwrite existing comments with _comment key" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "# User-written comment`n[automount]`noptions=metadata"
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{
                automount = @{_comment = 'This should not appear'; options = 'metadata,umask=022' }
            } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -notlike "*This should not appear*"
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

        It "Should preserve comments between sections" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                @"
[boot]
systemd=true

# Network settings below
[network]
generateHosts=false
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }
            Mock Invoke-WslDistroCommand { "" }

            Set-WslConf -DistroName "Debian" -Sections @{user = @{default = "dev" } } -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*# Network settings below*" -and
                $Command -like "*[network]*" -and
                $Command -like "*generateHosts=false*"
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

Describe "Get-WslConf" {
    # Contract: the result equals what the parser of Set-WslConf produces for the same content
    # (lib/wsl/wsl-conf.ps1): section names lower-cased, keys as written, keys and values trimmed,
    # comments and blank lines dropped, keys before the first section dropped.

    Context "When distribution does not exist" {
        It "Should throw when the distribution does not exist" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Get-WslConf -DistroName "NonExistent" } | Should -Throw "*does not exist*"
        }

        It "Should call Assert-WslDistroExists with the distribution name" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            Get-WslConf -DistroName "Debian" | Out-Null

            Should -Invoke Assert-WslDistroExists -Times 1 -Exactly -ParameterFilter { $DistroName -eq "Debian" }
        }
    }

    Context "When wsl.conf is missing or empty" {
        It "Should return an empty hashtable when cat fails" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" }

            $result = Get-WslConf -DistroName "Debian"

            $null -ne $result | Should -BeTrue -Because "an empty hashtable is not `$null"
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }

        It "Should return an empty hashtable when the output is empty" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            $result = Get-WslConf -DistroName "Debian"

            $null -ne $result | Should -BeTrue
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }

        It "Should return an empty hashtable when the output is whitespace only" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "  `n`n   " }

            $result = Get-WslConf -DistroName "Debian"

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }

        It "Should return an empty hashtable when the output is `$null" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { $null }

            $result = Get-WslConf -DistroName "Debian"

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }
    }

    Context "When wsl.conf has content" {
        It "Should read the file with cat /etc/wsl.conf" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            Get-WslConf -DistroName "Debian" | Out-Null

            Should -Invoke Invoke-WslDistroCommand -Times 1 -Exactly -ParameterFilter {
                $DistroName -eq "Debian" -and $Command -eq "cat /etc/wsl.conf"
            }
        }

        It "Should return nested hashtables for boot and user sections" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=true`ncommand=mount --make-rshared /`n`n[user]`ndefault=dev`n"
            }

            $result = Get-WslConf -DistroName "Debian"

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 2
            $result['boot'] | Should -BeOfType [hashtable]
            $result['boot'].Count | Should -Be 2
            $result['boot']['systemd'] | Should -Be 'true'
            $result['boot']['command'] | Should -Be 'mount --make-rshared /'
            $result['user'].Count | Should -Be 1
            $result['user']['default'] | Should -Be 'dev'
        }

        It "Should trim whitespace around keys, equals signs and values" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "  [boot]  `n  systemd   =   true   `n`tcommand`t=`tmount --make-rshared /  `n"
            }

            $result = Get-WslConf -DistroName "Debian"

            $result['boot']['systemd'] | Should -Be 'true'
            $result['boot']['command'] | Should -Be 'mount --make-rshared /'
            $result['boot'].ContainsKey('systemd   ') | Should -BeFalse
        }

        It "Should keep everything after the first equals sign in the value" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "[boot]`ncommand=echo a=b" }

            $result = Get-WslConf -DistroName "Debian"

            $result['boot']['command'] | Should -Be 'echo a=b'
        }

        It "Should keep an empty value as an empty string" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "[boot]`ncommand=`nsystemd=true" }

            $result = Get-WslConf -DistroName "Debian"

            $result['boot'].ContainsKey('command') | Should -BeTrue
            $result['boot']['command'] | Should -Be ''
            $result['boot']['systemd'] | Should -Be 'true'
        }

        It "Should lower-case section names and keep the case of keys" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "[Network]`ngenerateHosts=false" }

            $result = Get-WslConf -DistroName "Debian"

            $result.ContainsKey('network') | Should -BeTrue
            $result['network']['generateHosts'] | Should -Be 'false'
        }

        It "Should return a section without keys as an empty hashtable" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "[boot]`n[user]`ndefault=dev" }

            $result = Get-WslConf -DistroName "Debian"

            $result.ContainsKey('boot') | Should -BeTrue
            $result['boot'] | Should -BeOfType [hashtable]
            $result['boot'].Count | Should -Be 0
            $result['user']['default'] | Should -Be 'dev'
        }

        It "Should merge a repeated section and let the later key win" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=false`n[user]`ndefault=dev`n[boot]`nsystemd=true`ncommand=true"
            }

            $result = Get-WslConf -DistroName "Debian"

            $result.Count | Should -Be 2
            $result['boot']['systemd'] | Should -Be 'true'
            $result['boot']['command'] | Should -Be 'true'
        }
    }

    Context "Comments and blank lines" {
        It "Should drop comment lines and blank lines" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "# file comment`n`n# about boot`n[boot]`n# about systemd`nsystemd=true`n`n  # indented comment`ncommand=true`n"
            }

            $result = Get-WslConf -DistroName "Debian"

            $result.Count | Should -Be 1
            $result['boot'].Count | Should -Be 2
            $result['boot']['systemd'] | Should -Be 'true'
            $result['boot']['command'] | Should -Be 'true'
            $result['boot'].ContainsKey('_comment') | Should -BeFalse
            $result.ContainsKey('_comment') | Should -BeFalse
        }

        It "Should not turn a commented-out key into a key" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "[boot]`n#systemd=false`nsystemd=true" }

            $result = Get-WslConf -DistroName "Debian"

            $result['boot'].Count | Should -Be 1
            $result['boot']['systemd'] | Should -Be 'true'
        }
    }

    Context "Keys before any section" {
        It "Should ignore a key that comes before the first section" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "orphan=1`n[boot]`nsystemd=true" }

            $result = Get-WslConf -DistroName "Debian"

            $result.Count | Should -Be 1
            $result.ContainsKey('boot') | Should -BeTrue
            $result['boot'].Count | Should -Be 1
            $result['boot']['systemd'] | Should -Be 'true'
            $result.ContainsKey('orphan') | Should -BeFalse
        }

        It "Should return an empty hashtable when the file has only a key without a section" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "orphan=1" }

            $result = Get-WslConf -DistroName "Debian"

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }
    }

    Context "Line endings" {
        It "Should parse CRLF line endings without carriage returns in keys or values" {
            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand {
                "[boot]`r`nsystemd=true`r`ncommand=mount --make-rshared /`r`n`r`n[user]`r`ndefault=dev`r`n"
            }

            $result = Get-WslConf -DistroName "Debian"

            $result.Count | Should -Be 2
            $result.ContainsKey('boot') | Should -BeTrue
            $result.ContainsKey('user') | Should -BeTrue
            $result['boot']['systemd'] | Should -Be 'true'
            $result['boot']['command'] | Should -Be 'mount --make-rshared /'
            $result['user']['default'] | Should -Be 'dev'
        }
    }
}
