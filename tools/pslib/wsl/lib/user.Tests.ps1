<#
.DESCRIPTION
    Pester tests for lib/user.ps1 - WSL user management and systemd configuration
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\..\..\utils\utils.ps1"
    . "$PSScriptRoot\..\wsl.ps1"
}

Describe "New-WslUser" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Get-WslDistroList { @("Ubuntu") }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" } | Should -Throw "*does not exist*"
        }
    }

    Context "Username validation" {
        It "Should accept valid username" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "validuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand
        }

        It "Should throw for username starting with number" {

            Mock Get-WslDistroList { @("Debian") }

            { New-WslUser -DistroName "Debian" -Username "1user" -Password "testpass" } | Should -Throw "*invalid username*"
        }

        It "Should throw for username with uppercase letters" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            { New-WslUser -DistroName "Debian" -Username "TestUser" -Password "testpass" } | Should -Throw "*invalid username*"
        }

        It "Should throw for username with special characters" {

            Mock Get-WslDistroList { @("Debian") }

            { New-WslUser -DistroName "Debian" -Username "test@user" -Password "testpass" } | Should -Throw "*invalid username*"
        }

        It "Should accept username with hyphens and underscores" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "test_user-name" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand
        }

        It "Should throw for username longer than 32 characters" {

            Mock Get-WslDistroList { @("Debian") }

            { New-WslUser -DistroName "Debian" -Username ("a" * 33) -Password "testpass" } | Should -Throw "*too long*"
        }

        It "Should accept username with exactly 32 characters" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username ("a" * 32) -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand
        }
    }

    Context "When user already exists" {
        It "Should throw error when user exists" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "1001" } -ParameterFilter { $Command -like "*id -u*" }

            { New-WslUser -DistroName "Debian" -Username "existinguser" -Password "testpass" -Confirm:$false } | Should -Throw "*already exists*"
        }

        It "Should continue when user does not exist" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "newuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter { $Command -like "*useradd*" }
        }
    }

    Context "When creating user" {
        It "Should create user with useradd command" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*useradd -m -s /bin/bash testuser*"
            }
        }

        It "Should set user password with chpasswd" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*echo*testuser:testpass*chpasswd*"
            }
        }

        It "Should add user to sudo group" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*usermod -aG sudo testuser*"
            }
        }

        It "Should configure NOPASSWD in sudoers.d" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*testuser ALL=(ALL) NOPASSWD:ALL*" -and
                $Command -like "*sudo tee /etc/sudoers.d/testuser*" -and
                $Command -like "*chmod 0440*"
            }
        }

        It "Should set default user in wsl.conf" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*[user]*" -and
                $Command -like "*default=testuser*" -and
                $Command -like "*sudo tee /etc/wsl.conf*"
            }
        }

        It "Should display restart message" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }
            Mock Write-Output { }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Restarting distribution*"
            }
        }

        It "Should trim username" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "  testuser  " -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*useradd*testuser*" -and $Command -notlike "*  testuser  *"
            }
        }
    }

    Context "When handling passwords" {
        It "Should accept password string" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "plainpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*testuser:plainpass*"
            }
        }

        It "Should handle password with special characters" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password 'p@$$w0rd!&*' -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*testuser:p@*"
            }
        }
    }

    Context "When ShouldProcess is used" {
        It "Should skip user creation when user cancels confirmation" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -WhatIf

            Should -Invoke Invoke-WslDistroCommand -Times 0
        }
    }

    Context "When user creation fails" {
        It "Should throw error when useradd fails" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { throw "useradd failed" } -ParameterFilter { $Command -like "*useradd*" }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false } | Should -Throw "*useradd failed*"
        }

        It "Should throw error when password setting fails" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*useradd*" }
            Mock Invoke-WslDistroCommand { throw "chpasswd failed" } -ParameterFilter { $Command -like "*chpasswd*" }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false } | Should -Throw "*chpasswd failed*"
        }

        It "Should not display success message when user creation fails" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { throw "useradd failed" } -ParameterFilter { $Command -like "*useradd*" }
            Mock Write-Output { }

            try {
                New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false
            }
            catch {
                # Expected to throw - suppressing error for test verification
                $null = $_
            }

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Successfully created*"
            } -Times 0
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { New-WslUser -DistroName "" -Username "testuser" -Password "testpass" } | Should -Throw
        }

        It "Should throw when Username is empty" {
            { New-WslUser -DistroName "Debian" -Username "" -Password "testpass" } | Should -Throw
        }

        It "Should throw when Password is empty" {
            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "" } | Should -Throw
        }
    }

    Context "NOPASSWD warning display" {
        It "Should display warning about NOPASSWD sudo security implications" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }
            Mock Write-Warning { }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Write-Warning -ParameterFilter {
                $Message -like "*NOPASSWD sudo has been configured*" -and
                $Message -like "*allows running commands as root without password prompt*" -and
                $Message -like "*development environments*"
            }
        }
    }
}

Describe "Get-WslDefaultUser" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Get-WslDistroList { @("Ubuntu") }

            { Get-WslDefaultUser -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should return null" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" } -ParameterFilter {
                $Command -like "*cat /etc/wsl.conf*"
            }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When wsl.conf exists but has no [user] section" {
        It "Should return null" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[boot]
systemd=true
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When [user] section exists but has no default= line" {
        It "Should return null" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user]
# No default user configured
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When default user is configured" {
        It "Should return username from 'default=username' format" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user]
default=developer
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -Be "developer"
        }

        It "Should return username from 'default = username' format (with spaces)" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user]
default = johndoe
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -Be "johndoe"
        }

        It "Should return username when [user] section is not first" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[boot]
systemd=true

[user]
default=testuser
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -Be "testuser"
        }

        It "Should return username when there are comments in the file" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
# WSL Configuration
[user]
# Set the default user
default=admin
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -Be "admin"
        }
    }

    Context "Defensive parsing with malformed content" {
        It "Should return null when wsl.conf has missing closing bracket" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user
default=testuser
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -BeNullOrEmpty
        }

        It "Should return null when wsl.conf has invalid characters in value" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user]
default=user@#$%
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            # The function doesn't validate username format, just extracts the value
            # This test verifies it doesn't throw on unusual characters
            $result = Get-WslDefaultUser -DistroName "Debian"

            # Should extract the value even with special chars (validation happens elsewhere)
            $result | Should -Be "user@#$%"
        }

        It "Should return null when wsl.conf has empty [user] section" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user]

[boot]
systemd=true
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -BeNullOrEmpty
        }

        It "Should return first value when wsl.conf has duplicate default keys" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                @"
[user]
default=user1
default=user2
"@
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            $result = Get-WslDefaultUser -DistroName "Debian"

            # Should return first match due to early return in parsing logic
            $result | Should -Be "user1"
        }

        It "Should not throw exception on any malformed content" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "completely invalid content with no structure @#$%^&*()"
            } -ParameterFilter { $Command -like "*cat /etc/wsl.conf*" }

            # Should gracefully return null without throwing
            { Get-WslDefaultUser -DistroName "Debian" } | Should -Not -Throw
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Get-WslDefaultUser -DistroName "" } | Should -Throw
        }
    }
}

Describe "Test-WslSystemdConfigured" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Get-WslDistroList { @("Ubuntu") }

            { Test-WslSystemdConfigured -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should return false when wsl.conf is not found" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When systemd is configured in wsl.conf" {
        It "Should return true when systemd=true is set in [boot] section" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=true`n[user]`ndefault=developer"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true when systemd=true with spaces around equals" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd = true"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true when systemd=true with extra whitespace" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`n  systemd  =  true  "
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $true
        }
    }

    Context "When systemd is not configured in wsl.conf" {
        It "Should return false when [boot] section does not exist" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[user]`ndefault=developer"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when systemd is not set in [boot] section" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`n# systemd=true"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when systemd=false" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=false"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when wsl.conf is empty" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When systemd setting is in different sections" {
        It "Should only check [boot] section, not [other] sections" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[other]`nsystemd=true`n[boot]`nsystemd=false"
            }

            $result = Test-WslSystemdConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "Defensive parsing with malformed content" {
        It "Should return false when wsl.conf has missing closing bracket" {

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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
            Mock Get-WslDistroList { @("Ubuntu") }

            { Test-WslInteropConfigured -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should return false when wsl.conf is not found" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When Windows interop is fully configured in wsl.conf" {
        It "Should return true when both enabled=true and appendWindowsPath=true are set" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled=true`nappendWindowsPath=true`n[boot]`nsystemd=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true with spaces around equals" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled = true`nappendWindowsPath = true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $true
        }

        It "Should return true with extra whitespace" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[interop]`n  enabled  =  true  `n  appendWindowsPath  =  true  "
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $true
        }
    }

    Context "When Windows interop is not configured in wsl.conf" {
        It "Should return false when [interop] section does not exist" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[boot]`nsystemd=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when only enabled=true is set" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when only appendWindowsPath=true is set" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[interop]`nappendWindowsPath=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when enabled=false" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled=false`nappendWindowsPath=true"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when appendWindowsPath=false" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand {
                "[interop]`nenabled=true`nappendWindowsPath=false"
            }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }

        It "Should return false when wsl.conf is empty" {

            Mock Get-WslDistroList { @("Debian") }
            Mock Invoke-WslDistroCommand { "" }

            $result = Test-WslInteropConfigured -DistroName "Debian"

            $result | Should -Be $false
        }
    }

    Context "When interop settings are in different sections" {
        It "Should only check [interop] section, not [other] sections" {

            Mock Get-WslDistroList { @("Debian") }
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

Describe "Set-WslConf" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Get-WslDistroList { @("Ubuntu") }

            { Set-WslConf -DistroName "Debian" -Sections @{boot = @{systemd = "true" } } } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should create new wsl.conf with specified sections" {

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }
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

            Mock Get-WslDistroList { @("Debian") }

            { Set-WslConf -DistroName "Debian" -Sections @{} -Confirm:$false } | Should -Throw "*null*"
        }
    }
}

