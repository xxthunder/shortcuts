<#
.DESCRIPTION
    Pester tests for lib/exec.ps1 - WSL command and script execution functions
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'File is UTF-8 without BOM, which is standard for cross-platform compatibility.')]
param()

BeforeAll {
    . "$PSScriptRoot\wsl.ps1"
}

Describe "Invoke-WslDistroCommand" {
    Context "When distribution does not exist" {
        It "Should throw an error" {
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu, Alpine" }

            { Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" } | Should -Throw "*does not exist*"
        }
    }

    Context "When executing valid command" {
        It "Should execute command with correct wsl parameters" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { "command output" }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test"

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*wsl.exe --distribution Debian --exec bash -c "echo test"*'
            }
        }

        It "Should pass StopAtError parameter to Invoke-CommandLine" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" -StopAtError $false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $StopAtError -eq $false
            }
        }

        It "Should pass PrintCommand parameter to Invoke-CommandLine" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" -PrintCommand $false

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $PrintCommand -eq $false
            }
        }

        It "Should print commands by default when PrintCommand is not specified" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test"

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $PrintCommand -eq $true
            }
        }
    }

    Context "When using -PassThru switch" {
        It "Should capture and return output when -PassThru is specified" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { "command output" }

            $result = Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" -PassThru

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*wsl.exe --distribution Debian --exec bash -c "echo test"*'
            }
            $result | Should -Be "command output"
        }

        It "Should return output when -PassThru is not specified" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { "command output" }

            $result = Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test"

            $result | Should -Be "command output"
        }

        It "Should join multiple output lines with newline when -PassThru is used" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { @("line1", "line2", "line3") }

            $result = Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test" -PassThru

            $result | Should -Be "line1`nline2`nline3"
        }

        It "Should not join multiple output lines when -PassThru is not used" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { @("line1", "line2", "line3") }

            $result = Invoke-WslDistroCommand -DistroName "Debian" -Command "echo test"

            $result | Should -HaveCount 3
            $result[0] | Should -Be "line1"
            $result[1] | Should -Be "line2"
            $result[2] | Should -Be "line3"
        }
    }

    Context "When command contains special characters" {
        It "Should handle double quotes in command (escaping with backslash)" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command 'echo "hello world"'

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*bash -c "echo*hello world*"*'
            }
        }

        It "Should handle commands with pipes" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Ubuntu" -Command "cat file.txt | grep pattern"

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*bash -c "cat file.txt | grep pattern"*'
            }
        }

        It "Should handle commands with && operator" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { }

            Invoke-WslDistroCommand -DistroName "Debian" -Command "apt update && apt upgrade"

            Should -Invoke Invoke-CommandLine -ParameterFilter {
                $CommandLine -like '*bash -c "apt update && apt upgrade"*'
            }
        }
    }

    Context "When command fails" {
        It "Should throw when StopAtError is true and command fails" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { throw "Command failed with exit code 1" }

            { Invoke-WslDistroCommand -DistroName "Debian" -Command "false" -StopAtError $true } | Should -Throw "*Command failed*"
        }

        It "Should not throw when StopAtError is false and command fails" {

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { }

            { Invoke-WslDistroCommand -DistroName "Debian" -Command "false" -StopAtError $false } | Should -Not -Throw
        }
    }

    Context "Parameter validation" {
        It "Should throw when DistroName is empty" {
            { Invoke-WslDistroCommand -DistroName "" -Command "echo test" } | Should -Throw
        }

        It "Should throw when Command is empty" {
            { Invoke-WslDistroCommand -DistroName "Debian" -Command "" } | Should -Throw
        }
    }
}

Describe "Invoke-WslDistroScript" {
    Context "Path Validation" {
        It "Should throw if script doesn't exist" {
            Mock Test-Path { $false }

            { Invoke-WslDistroScript -ScriptPath "C:\missing.sh" -DistroName "Debian" } |
                Should -Throw "*Script not found*"
        }

        It "Should accept valid Windows script path" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" }

            { Invoke-WslDistroScript -ScriptPath "C:\Users\test.sh" -DistroName "Debian" } |
                Should -Not -Throw

            Should -Invoke Test-Path -Times 1
            Should -Invoke Invoke-CommandLine -Times 1
        }
    }

    Context "Path Conversion" {
        It "Should convert C: drive path to /mnt/c/" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" } -ParameterFilter {
                $CommandLine -like "*wsl.exe*" -and $CommandLine -like "*/mnt/c/*"
            }

            Invoke-WslDistroScript -ScriptPath "C:\Users\test.sh" -DistroName "Debian"

            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like "*/mnt/c/Users/test.sh*"
            }
        }

        It "Should convert D: drive path to /mnt/d/" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" } -ParameterFilter {
                $CommandLine -like "*/mnt/d/*"
            }

            Invoke-WslDistroScript -ScriptPath "D:\scripts\test.sh" -DistroName "Debian"

            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like "*/mnt/d/scripts/test.sh*"
            }
        }

        It "Should convert backslashes to forward slashes" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" }

            Invoke-WslDistroScript -ScriptPath "C:\path\to\script.sh" -DistroName "Debian"

            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like "*/mnt/c/path/to/script.sh*"
            }
        }
    }

    Context "Argument Passing" {
        It "Should pass multiple arguments correctly" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" } -ParameterFilter {
                $CommandLine -like "*--arg1=value1*" -and $CommandLine -like "*--arg2=value2*"
            }

            Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian" `
                -Arguments @("--arg1=value1", "--arg2=value2")

            Should -Invoke Invoke-CommandLine -Times 1
        }

        It "Should execute without arguments if none provided" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" }

            Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian"

            Should -Invoke Invoke-CommandLine -Times 1
        }

        It "Should handle empty Arguments array" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" }

            Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian" -Arguments @()

            Should -Invoke Invoke-CommandLine -Times 1
        }
    }

    Context "Exit Code Handling" {
        It "Should return exit code 0 from successful script" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine {
                $global:LASTEXITCODE = 0
                return ""
            }

            $exitCode = Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian"

            $exitCode | Should -Be 0
        }

        It "Should return exit code 2 from failed script" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine {
                $global:LASTEXITCODE = 2
                return ""
            }

            $exitCode = Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian" -StopAtError $false

            $exitCode | Should -Be 2
        }
    }

    Context "WSL Validation" {
        It "Should throw when distribution does not exist" {
            Mock Test-Path { $true }
            Mock Assert-WslDistroExists { throw "Distribution '$DistroName' does not exist. Installed distributions: Ubuntu, Alpine" }

            { Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian" } |
                Should -Throw "*does not exist*"
        }
    }

    Context "Parameter Passing" {
        It "Should pass StopAtError parameter to Invoke-CommandLine" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" } -ParameterFilter {
                $StopAtError -eq $false
            }

            Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian" -StopAtError $false

            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $StopAtError -eq $false
            }
        }

        It "Should pass PrintCommand parameter to Invoke-CommandLine" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" } -ParameterFilter {
                $PrintCommand -eq $false
            }

            Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian" -PrintCommand $false

            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $PrintCommand -eq $false
            }
        }

        It "Should execute with sudo when AsRoot is true" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" } -ParameterFilter {
                $CommandLine -like "*sudo bash*"
            }

            Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian" -AsRoot $true

            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like "*--exec sudo bash*"
            }
        }

        It "Should execute without sudo when AsRoot is false" {
            Mock Test-Path { $true }

            Mock Assert-WslDistroExists { }
            Mock Invoke-CommandLine { $global:LASTEXITCODE = 0; "" } -ParameterFilter {
                $CommandLine -like "*--exec bash*" -and $CommandLine -notlike "*sudo*"
            }

            Invoke-WslDistroScript -ScriptPath "C:\test.sh" -DistroName "Debian" -AsRoot $false

            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like "*--exec bash*" -and $CommandLine -notlike "*sudo*"
            }
        }
    }
}
