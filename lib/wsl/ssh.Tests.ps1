<#
.DESCRIPTION
    Pester tests for lib/ssh.ps1 - WSL SSH configuration sync
#>

param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\wsl.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Invoke-WslSyncSshConfig" {
    Context "Prerequisite validation - Distribution existence" {
        It "Should throw when distribution does not exist" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu" }

            { Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false } | Should -Throw "*does not exist*"
        }
    }

    Context "SupportsShouldProcess" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
        }

        It "Should support -WhatIf parameter" {
            Invoke-WslSyncSshConfig -DistroName "Debian" -WhatIf

            Should -Invoke Invoke-WslDistroScript -Times 0
        }

        It "Should execute script when -Confirm:false is specified" {
            Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*sync-ssh-config.sh*"
            }
        }
    }

    Context "Script invocation" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }
        }

        It "Should call Invoke-WslDistroScript with sync-ssh-config.sh" {
            Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $ScriptPath -like "*sync-ssh-config.sh*"
            }
        }

        It "Should pass --ssh-target-dir argument with Windows .ssh path" {
            Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -like "*--ssh-target-dir=*"
            }
        }

        It "Should pass --distro-name argument" {
            Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $Arguments -contains "--distro-name=Debian"
            }
        }

        It "Should pass StopAtError false and PrintCommand false" {
            Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false

            Should -Invoke Invoke-WslDistroScript -Times 1 -ParameterFilter {
                $StopAtError -eq $false -and $PrintCommand -eq $false
            }
        }
    }

    Context "Exit code handling" {
        BeforeEach {

            Mock Assert-WslDistroExists { }
        }

        It "Should return true on success (exit code 0)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 0; return 0 }

            $result = Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false

            $result | Should -Be $true
        }

        It "Should return false and write error on exit code 1 (no SSH keys)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 1; return 1 }

            $result = Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*No SSH keys*"
        }

        It "Should return false and write error on exit code 2 (config sync failed)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 2; return 2 }

            $result = Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Config sync failed*"
        }

        It "Should return false and write error on exit code 4 (argument error)" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 4; return 4 }

            $result = Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*Argument error*"
        }

        It "Should return false and write error on unknown exit code" {
            Mock Invoke-WslDistroScript { $global:LASTEXITCODE = 99; return 99 }

            $result = Invoke-WslSyncSshConfig -DistroName "Debian" -Confirm:$false -ErrorVariable err -ErrorAction SilentlyContinue
            $result | Should -Be $false
            $err[0].Exception.Message | Should -BeLike "*exit code: 99*"
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Invoke-WslSyncSshConfig -DistroName "" -Confirm:$false } | Should -Throw
        }
    }
}
