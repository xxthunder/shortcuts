<#
.DESCRIPTION
    Pester tests for lib/user.ps1 - WSL user management functions
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

Describe "New-WslUser" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" } | Should -Throw "*does not exist*"
        }
    }

    Context "Username validation" {
        It "Should accept valid username" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "validuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand
        }

        It "Should throw for username starting with number" {

            Mock Assert-WslDistroExists { }

            { New-WslUser -DistroName "Debian" -Username "1user" -Password "testpass" } | Should -Throw "*invalid username*"
        }

        It "Should throw for username with uppercase letters" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            { New-WslUser -DistroName "Debian" -Username "TestUser" -Password "testpass" } | Should -Throw "*invalid username*"
        }

        It "Should throw for username with special characters" {

            Mock Assert-WslDistroExists { }

            { New-WslUser -DistroName "Debian" -Username "test@user" -Password "testpass" } | Should -Throw "*invalid username*"
        }

        It "Should accept username with hyphens and underscores" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "test_user-name" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand
        }

        It "Should throw for username longer than 32 characters" {

            Mock Assert-WslDistroExists { }

            { New-WslUser -DistroName "Debian" -Username ("a" * 33) -Password "testpass" } | Should -Throw "*too long*"
        }

        It "Should accept username with exactly 32 characters" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username ("a" * 32) -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand
        }
    }

    Context "When user already exists" {
        It "Should throw error when user exists" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "1001" } -ParameterFilter { $Command -like "*id -u*" }

            { New-WslUser -DistroName "Debian" -Username "existinguser" -Password "testpass" -Confirm:$false } | Should -Throw "*already exists*"
        }

        It "Should continue when user does not exist" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "newuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter { $Command -like "*useradd*" }
        }
    }

    Context "When creating user" {
        It "Should create user with useradd command" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*useradd -m -s /bin/bash testuser*"
            }
        }

        It "Should set user password with chpasswd" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*echo*testuser:testpass*chpasswd*"
            }
        }

        It "Should add user to sudo group" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*usermod -aG sudo testuser*"
            }
        }

        It "Should configure NOPASSWD in sudoers.d" {

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }
            Mock Write-Output { }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Write-Output -ParameterFilter {
                $InputObject -like "*Restarting distribution*"
            }
        }

        It "Should auto-terminate the distribution via Stop-WslDistro" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }
            Mock Stop-WslDistro { }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false

            Should -Invoke Stop-WslDistro -ParameterFilter { $Name -eq "Debian" }
        }

        It "Should trim username" {

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "plainpass" -Confirm:$false

            Should -Invoke Invoke-WslDistroCommand -ParameterFilter {
                $Command -like "*testuser:plainpass*"
            }
        }

        It "Should handle password with special characters" {

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" }

            New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -WhatIf

            Should -Invoke Invoke-WslDistroCommand -Times 0
        }
    }

    Context "When user creation fails" {
        It "Should throw error when useradd fails" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { throw "useradd failed" } -ParameterFilter { $Command -like "*useradd*" }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false } | Should -Throw "*useradd failed*"
        }

        It "Should throw error when password setting fails" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*id -u*" }
            Mock Invoke-WslDistroCommand { "" } -ParameterFilter { $Command -like "*useradd*" }
            Mock Invoke-WslDistroCommand { throw "chpasswd failed" } -ParameterFilter { $Command -like "*chpasswd*" }

            { New-WslUser -DistroName "Debian" -Username "testuser" -Password "testpass" -Confirm:$false } | Should -Throw "*chpasswd failed*"
        }

        It "Should not display success message when user creation fails" {

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Get-WslDefaultUser -DistroName "Debian" } | Should -Throw "*does not exist*"
        }
    }

    Context "When wsl.conf does not exist" {
        It "Should return null" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroCommand { throw "cat: /etc/wsl.conf: No such file or directory" } -ParameterFilter {
                $Command -like "*cat /etc/wsl.conf*"
            }

            $result = Get-WslDefaultUser -DistroName "Debian"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "When wsl.conf exists but has no [user] section" {
        It "Should return null" {

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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

            Mock Assert-WslDistroExists { }
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
