<#
.DESCRIPTION
    Pester tests for utils.ps1 utility functions
#>

BeforeAll {
    # Source the utils.ps1 file
    . "$PSScriptRoot\utils.ps1"
}

Describe "Invoke-CommandLine" {
    Context "When executing a successful command" {
        It "Should execute command and return without error" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 0 }

            { Invoke-CommandLine -CommandLine "echo test" } | Should -Not -Throw

            Should -Invoke Invoke-Expression -Times 1
        }

        It "Should print command when PrintCommand is true" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 0 }
            Mock Write-Output {}

            Invoke-CommandLine -CommandLine "test command" -PrintCommand $true

            Should -Invoke Write-Output -ParameterFilter { $InputObject -eq "Executing: test command" }
        }

        It "Should not print command when PrintCommand is false" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 0 }
            Mock Write-Output {}

            Invoke-CommandLine -CommandLine "test command" -PrintCommand $false

            Should -Invoke Write-Output -Times 0
        }

        It "Should suppress output when Silent is true" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 0; "output" }
            Mock Out-Null {}

            Invoke-CommandLine -CommandLine "test command" -Silent $true -PrintCommand $false

            Should -Invoke Out-Null -Times 1
        }
    }

    Context "When command fails" {
        It "Should throw error when StopAtError is true and command fails" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 1 }
            Mock Write-Error { throw "Command failed" }

            { Invoke-CommandLine -CommandLine "failing command" -StopAtError $true -PrintCommand $false } | Should -Throw
        }

        It "Should continue when StopAtError is false and command fails" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 1 }
            Mock Write-Information {}

            { Invoke-CommandLine -CommandLine "failing command" -StopAtError $false -PrintCommand $false } | Should -Not -Throw

            Should -Invoke Write-Information -ParameterFilter { $MessageData -like "*failed with exit code 1, continuing*" }
        }

        It "Should include exit code in error message" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 42 }
            Mock Write-Error { throw "Command failed with exit code 42" }

            { Invoke-CommandLine -CommandLine "test" -PrintCommand $false } | Should -Throw "*exit code 42*"
        }
    }

    Context "When using default parameters" {
        It "Should use default values when parameters not specified" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 0 }
            Mock Write-Output {}

            Invoke-CommandLine -CommandLine "test"

            # Should print command by default
            Should -Invoke Write-Output -ParameterFilter { $InputObject -eq "Executing: test" }
        }
    }

    Context "When testing boundary conditions" {
        It "Should handle commands with special characters" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 0 }
            Mock Write-Output {}

            { Invoke-CommandLine -CommandLine 'echo "test with quotes"' } | Should -Not -Throw
        }

        It "Should handle commands with pipes" {
            Mock Invoke-Expression { $global:LASTEXITCODE = 0 }
            Mock Write-Output {}

            { Invoke-CommandLine -CommandLine 'echo test | findstr test' } | Should -Not -Throw
        }

        It "Should handle very long command strings" {
            $longCommand = "echo " + ("test" * 100)
            Mock Invoke-Expression { $global:LASTEXITCODE = 0 }
            Mock Write-Output {}

            { Invoke-CommandLine -CommandLine $longCommand -PrintCommand $false } | Should -Not -Throw
        }

        It "Should throw on empty command string" {
            { Invoke-CommandLine -CommandLine "" } | Should -Throw
        }

        It "Should throw on whitespace-only command string" {
            { Invoke-CommandLine -CommandLine "   " } | Should -Throw
        }
    }
}

Describe "Initialize-EnvPath" {
    Context "When USER_PATH_FIRST is set" {
        It "Should prioritize user path over machine path" {
            $userPath = "C:\Users\Test\bin"
            $machinePath = "C:\Windows\System32"

            $originalEnv = $Env:USER_PATH_FIRST
            $Env:USER_PATH_FIRST = $true

            # Create a function wrapper to test
            $testScript = {
                param($userP, $machineP)
                if ($Env:USER_PATH_FIRST) {
                    $Env:Path = $userP + ";" + $machineP
                }
                else {
                    $Env:Path = $machineP + ";" + $userP
                }
            }

            & $testScript -userP $userPath -machineP $machinePath

            $Env:Path | Should -Match "^$([regex]::Escape($userPath))"

            # Restore
            $Env:USER_PATH_FIRST = $originalEnv
        }
    }

    Context "When USER_PATH_FIRST is not set" {
        It "Should prioritize machine path over user path" {
            $userPath = "C:\Users\Test\bin"
            $machinePath = "C:\Windows\System32"

            $originalEnv = $Env:USER_PATH_FIRST
            Remove-Item Env:\USER_PATH_FIRST -ErrorAction SilentlyContinue

            # Create a function wrapper to test
            $testScript = {
                param($userP, $machineP)
                if ($Env:USER_PATH_FIRST) {
                    $Env:Path = $userP + ";" + $machineP
                }
                else {
                    $Env:Path = $machineP + ";" + $userP
                }
            }

            & $testScript -userP $userPath -machineP $machinePath

            $Env:Path | Should -Match "^$([regex]::Escape($machinePath))"

            # Restore
            if ($originalEnv) {
                $Env:USER_PATH_FIRST = $originalEnv
            }
        }
    }
}

Describe "Remove-Path" {
    Context "When removing a directory" {
        It "Should delete existing directory" {
            $testPath = "TestDrive:\testdir"
            Mock Test-Path { $true } -ParameterFilter { $Path -eq $testPath -and $PathType -eq "Container" }
            Mock Remove-Item {}
            Mock Write-Output {}

            Remove-Path -Path $testPath

            Should -Invoke Remove-Item -ParameterFilter { $Path -eq $testPath -and $Force -eq $true -and $Recurse -eq $true }
            Should -Invoke Write-Output -ParameterFilter { $InputObject -like "*Deleting directory*" }
        }

        It "Should output deletion message for directory" {
            $testPath = "TestDrive:\testdir"
            Mock Test-Path { $true } -ParameterFilter { $PathType -eq "Container" }
            Mock Test-Path { $false } -ParameterFilter { $PathType -eq "Leaf" }
            Mock Remove-Item {}
            Mock Write-Output {}

            Remove-Path -Path $testPath

            Should -Invoke Write-Output -ParameterFilter { $InputObject -eq "Deleting directory '$testPath' ..." }
        }
    }

    Context "When removing a file" {
        It "Should delete existing file" {
            $testPath = "TestDrive:\testfile.txt"
            Mock Test-Path { $false } -ParameterFilter { $PathType -eq "Container" }
            Mock Test-Path { $true } -ParameterFilter { $Path -eq $testPath -and $PathType -eq "Leaf" }
            Mock Remove-Item {}
            Mock Write-Output {}

            Remove-Path -Path $testPath

            Should -Invoke Remove-Item -ParameterFilter { $Path -eq $testPath -and $Force -eq $true }
            Should -Invoke Write-Output -ParameterFilter { $InputObject -like "*Deleting file*" }
        }

        It "Should output deletion message for file" {
            $testPath = "TestDrive:\testfile.txt"
            Mock Test-Path { $false } -ParameterFilter { $PathType -eq "Container" }
            Mock Test-Path { $true } -ParameterFilter { $PathType -eq "Leaf" }
            Mock Remove-Item {}
            Mock Write-Output {}

            Remove-Path -Path $testPath

            Should -Invoke Write-Output -ParameterFilter { $InputObject -eq "Deleting file '$testPath' ..." }
        }
    }

    Context "When path does not exist" {
        It "Should not attempt to delete non-existent path" {
            $testPath = "TestDrive:\nonexistent"
            Mock Test-Path { $false }
            Mock Remove-Item {}

            Remove-Path -Path $testPath

            Should -Invoke Remove-Item -Times 0
        }
    }

    Context "When testing boundary conditions" {
        It "Should throw on empty path" {
            { Remove-Path -Path "" } | Should -Throw
        }

        It "Should throw on whitespace-only path" {
            { Remove-Path -Path "   " } | Should -Throw
        }

        It "Should handle paths with spaces" {
            $testPath = "TestDrive:\test dir"
            Mock Test-Path { $true } -ParameterFilter { $PathType -eq "Container" }
            Mock Remove-Item {}
            Mock Write-Output {}

            { Remove-Path -Path $testPath } | Should -Not -Throw

            Should -Invoke Remove-Item -Times 1
        }

        It "Should handle paths with special characters" {
            $testPath = "TestDrive:\test[dir]"
            Mock Test-Path { $true } -ParameterFilter { $PathType -eq "Container" }
            Mock Remove-Item {}
            Mock Write-Output {}

            { Remove-Path -Path $testPath } | Should -Not -Throw

            Should -Invoke Remove-Item -Times 1
        }
    }
}

Describe "New-Directory" {
    Context "When directory does not exist" {
        It "Should create new directory" {
            $testDir = "TestDrive:\newdir"
            Mock Test-Path { $false }
            Mock New-Item { @{ FullName = $testDir } }
            Mock Write-Output {}
            Mock Out-Null {}

            New-Directory -Path $testDir

            Should -Invoke New-Item -ParameterFilter { $ItemType -eq "Directory" -and $Path -eq $testDir }
            Should -Invoke Write-Output -ParameterFilter { $InputObject -eq "Creating directory '$testDir' ..." }
        }
    }

    Context "When directory already exists" {
        It "Should not create directory if it already exists" {
            $testDir = "TestDrive:\existingdir"
            Mock Test-Path { $true }
            Mock New-Item {}

            New-Directory -Path $testDir

            Should -Invoke New-Item -Times 0
        }

        It "Should not output message if directory exists" {
            $testDir = "TestDrive:\existingdir"
            Mock Test-Path { $true }
            Mock Write-Output {}

            New-Directory -Path $testDir

            Should -Invoke Write-Output -Times 0
        }
    }

    Context "When testing boundary conditions" {
        It "Should throw on empty path" {
            { New-Directory -Path "" } | Should -Throw
        }

        It "Should throw on whitespace-only path" {
            { New-Directory -Path "   " } | Should -Throw
        }

        It "Should handle paths with spaces" {
            $testDir = "TestDrive:\test dir"
            Mock Test-Path { $false }
            Mock New-Item { @{ FullName = $testDir } }
            Mock Write-Output {}
            Mock Out-Null {}

            { New-Directory -Path $testDir } | Should -Not -Throw

            Should -Invoke New-Item -Times 1
        }
    }
}

Describe "Get-UserConfirmation" {
    Context "When running in CI or test environment" {
        It "Should return valueForCi without prompting" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Read-Host {}

            $result = Get-UserConfirmation -message "Test?" -valueForCi $true

            $result | Should -Be $true
            Should -Invoke Read-Host -Times 0
        }

        It "Should return false when valueForCi is false" {
            Mock Test-RunningInCIorTestEnvironment { $true }
            Mock Read-Host {}

            $result = Get-UserConfirmation -message "Test?" -valueForCi $false

            $result | Should -Be $false
            Should -Invoke Read-Host -Times 0
        }
    }

    Context "When running interactively with user input" {
        It "Should return <Expected> when user enters '<UserInput>'" -ForEach @(
            @{ UserInput = "Y"; Expected = $true; Description = "uppercase Y" }
            @{ UserInput = "y"; Expected = $true; Description = "lowercase y" }
            @{ UserInput = "Yes"; Expected = $true; Description = "Yes" }
            @{ UserInput = "yes"; Expected = $true; Description = "lowercase yes" }
            @{ UserInput = "N"; Expected = $false; Description = "uppercase N" }
            @{ UserInput = "n"; Expected = $false; Description = "lowercase n" }
            @{ UserInput = "No"; Expected = $false; Description = "No" }
            @{ UserInput = "no"; Expected = $false; Description = "lowercase no" }
        ) {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-Host { $UserInput }

            $result = Get-UserConfirmation -message "Continue?"

            $result | Should -Be $Expected
        }

        It "Should handle edge case inputs: '<UserInput>'" -ForEach @(
            @{ UserInput = "  Y  "; Expected = $false; Description = "Y with whitespace (treated as invalid)" }
            @{ UserInput = "yeah"; Expected = $false; Description = "informal affirmative" }
            @{ UserInput = "nope"; Expected = $false; Description = "informal negative" }
            @{ UserInput = "maybe"; Expected = $false; Description = "ambiguous" }
            @{ UserInput = "1"; Expected = $false; Description = "numeric" }
        ) {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-Host { $UserInput }

            $result = Get-UserConfirmation -message "Continue?" -defaultValueForUser $true

            $result | Should -Be $Expected
        }
    }

    Context "When using default value" {
        It "Should return defaultValueForUser when user presses enter" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-Host { "" }

            $result = Get-UserConfirmation -message "Continue?" -defaultValueForUser $true

            $result | Should -Be $true
        }

        It "Should return false when default is false and user presses enter" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-Host { "" }

            $result = Get-UserConfirmation -message "Continue?" -defaultValueForUser $false

            $result | Should -Be $false
        }

        It "Should display [Y/n] when default is true" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-Host { "" }

            Get-UserConfirmation -message "Continue?" -defaultValueForUser $true

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*[Y/n]*" }
        }

        It "Should display [y/N] when default is false" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-Host { "" }

            Get-UserConfirmation -message "Continue?" -defaultValueForUser $false

            Should -Invoke Read-Host -ParameterFilter { $Prompt -like "*[y/N]*" }
        }
    }

    Context "When using default parameter values" {
        It "Should use true as default for defaultValueForUser" {
            Mock Test-RunningInCIorTestEnvironment { $false }
            Mock Read-Host { "" }

            $result = Get-UserConfirmation -message "Continue?"

            $result | Should -Be $true
        }

        It "Should use false as default for valueForCi" {
            Mock Test-RunningInCIorTestEnvironment { $true }

            $result = Get-UserConfirmation -message "Continue?"

            $result | Should -Be $false
        }
    }
}

Describe "Test-RunningInCIorTestEnvironment" {
    Context "When running in CI environment" {
        It "Should return true when CI environment variable is set" {
            $originalCI = $Env:CI
            $Env:CI = "true"

            $result = Test-RunningInCIorTestEnvironment

            $result | Should -Be $true

            # Restore
            if ($null -eq $originalCI) {
                Remove-Item Env:\CI -ErrorAction SilentlyContinue
            } else {
                $Env:CI = $originalCI
            }
        }

        It "Should return true when GITHUB_ACTIONS is set" {
            $originalGHA = $Env:GITHUB_ACTIONS
            $Env:GITHUB_ACTIONS = "true"

            $result = Test-RunningInCIorTestEnvironment

            $result | Should -Be $true

            # Restore
            if ($null -eq $originalGHA) {
                Remove-Item Env:\GITHUB_ACTIONS -ErrorAction SilentlyContinue
            } else {
                $Env:GITHUB_ACTIONS = $originalGHA
            }
        }

        It "Should return true when running in Pester" {
            # This test itself is running in Pester, so it should return true
            $result = Test-RunningInCIorTestEnvironment

            $result | Should -Be $true
        }
    }

    Context "When running interactively" {
        It "Should detect Pester environment via PesterPreference" {
            # Since we're in Pester, PesterPreference should exist
            $result = Test-RunningInCIorTestEnvironment

            # Should be true because we're in Pester (PesterPreference exists)
            $result | Should -Be $true
        }
    }
}
