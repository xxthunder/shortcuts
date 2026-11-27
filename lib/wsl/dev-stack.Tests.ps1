<#
.DESCRIPTION
    Pester tests for lib/wsl/dev-stack.ps1 - Install-WslDevStack hands the Linux side of a
    WSL distribution to the dev-stack Ansible role (SC-066a).

    Contract the tests pin down:
    - Validation and coexistence failures throw.
    - Failures of the two scripts (non-zero exit) Write-Error and return $false.
    - The boot command is read with Get-WslConf -DistroName <name>, which returns the wsl.conf
      sections as a hashtable, for example @{ boot = @{ systemd = 'true'; command = 'mount --make-rshared /' } }.
#>

param()

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\wsl.ps1"
    . "$PSScriptRoot\dev-stack.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe "Install-WslDevStack" {
    BeforeEach {
        $script:calls = [System.Collections.Generic.List[string]]::new()
        $script:scriptArgs = @{}
        $script:devStackExit = 0
        $script:binfmtExit = 0

        Mock Assert-WslDistroExists { }
        Mock Test-Wsl2Version { $true }
        Mock Get-WslDistroType { "debian" }
        Mock Get-WslDefaultUser { "dev" }
        Mock Test-WslDockerInstalled { $false }
        Mock Test-WslPodmanInstalled { $false }
        Mock Test-WslSystemdConfigured { $true }
        Mock Get-WslConf { @{ boot = @{ systemd = "true"; command = "mount --make-rshared /" } } }
        Mock Set-WslConf { }
        Mock Stop-WslDistro { }
        Mock Invoke-WslDistroScript {
            $name = Split-Path -Leaf $ScriptPath
            $script:calls.Add($name)
            $script:scriptArgs[$name] = $Arguments
            if ($name -eq "setup-binfmt-interop.sh") { return $script:binfmtExit }
            return $script:devStackExit
        }
    }

    Context "Validation failures throw" {
        It "Should throw when the distribution does not exist" {
            Mock Assert-WslDistroExists { throw "Distribution 'Nope' does not exist." }

            { Install-WslDevStack -DistroName "Nope" -Confirm:$false } | Should -Throw "*does not exist*"
            Should -Invoke Set-WslConf -Times 0 -Exactly
            Should -Invoke Invoke-WslDistroScript -Times 0 -Exactly
        }

        It "Should throw with the set-version hint for WSL1" {
            Mock Test-Wsl2Version { $false }

            { Install-WslDevStack -DistroName "Debian" -Confirm:$false } | Should -Throw "*wsl.exe --set-version*"
            Should -Invoke Set-WslConf -Times 0 -Exactly
            Should -Invoke Invoke-WslDistroScript -Times 0 -Exactly
        }

        It "Should throw for an unsupported distribution type" {
            Mock Get-WslDistroType { "alpine" }

            { Install-WslDevStack -DistroName "Alpine" -Confirm:$false } | Should -Throw "*alpine*"
            Should -Invoke Set-WslConf -Times 0 -Exactly
            Should -Invoke Invoke-WslDistroScript -Times 0 -Exactly
        }

        It "Should throw for -Runtime docker on Ubuntu and name Ubuntu" {
            Mock Get-WslDistroType { "ubuntu" }

            { Install-WslDevStack -DistroName "Ubuntu" -Runtime docker -Confirm:$false } | Should -Throw "*Ubuntu*"
            Should -Invoke Set-WslConf -Times 0 -Exactly
            Should -Invoke Invoke-WslDistroScript -Times 0 -Exactly
        }

        It "Should throw with the setup-user hint when no default user exists" {
            Mock Get-WslDefaultUser { $null }

            { Install-WslDevStack -DistroName "Debian" -Confirm:$false } | Should -Throw "*setup-user*"
            Should -Invoke Set-WslConf -Times 0 -Exactly
            Should -Invoke Invoke-WslDistroScript -Times 0 -Exactly
        }

        It "Should name the command as 'wsl-manager setup-user' with the distribution in the hint" {
            Mock Get-WslDefaultUser { $null }

            $message = try { Install-WslDevStack -DistroName "Debian" -Confirm:$false; "" } catch { $_.Exception.Message }

            $message | Should -Match '(?m)^\s*wsl-manager setup-user Debian\s*$'
            $message | Should -Not -BeLike '*tools\wsl\*'
        }

        It "Should accept an explicit -Username when no default user exists" {
            Mock Get-WslDefaultUser { $null }

            $result = Install-WslDevStack -DistroName "Debian" -Username "alice" -Confirm:$false

            $result | Should -BeTrue
            $script:scriptArgs["setup-dev-stack.sh"] | Should -Contain "--username=alice"
        }
    }

    Context "Coexistence of Docker and Podman" {
        It "Should throw 'cannot coexist' for <Runtime> when the other runtime is installed" -ForEach @(
            @{ Runtime = "podman"; Other = "docker" }
            @{ Runtime = "docker"; Other = "podman" }
        ) {
            if ($Other -eq "docker") { Mock Test-WslDockerInstalled { $true } }
            else { Mock Test-WslPodmanInstalled { $true } }

            { Install-WslDevStack -DistroName "Debian" -Runtime $Runtime -Confirm:$false } | Should -Throw "*cannot coexist*"
            Should -Invoke Set-WslConf -Times 0 -Exactly
            Should -Invoke Invoke-WslDistroScript -Times 0 -Exactly
        }
    }

    Context "wsl.conf handling" {
        It "Should configure systemd and the Podman boot command on a fresh distribution" {
            Mock Test-WslSystemdConfigured { $false }
            Mock Get-WslConf { @{} }

            Install-WslDevStack -DistroName "Debian" -Confirm:$false | Out-Null

            Should -Invoke Set-WslConf -Times 1 -Exactly -ParameterFilter {
                $DistroName -eq "Debian" -and
                $Sections.boot.systemd -eq "true" -and
                $Sections.boot.command -eq "mount --make-rshared /" -and
                -not $Sections.ContainsKey("interop") -and
                -not $Sections.ContainsKey("automount")
            }
            Should -Invoke Stop-WslDistro -Times 1
        }

        It "Should set systemd but no boot command for Docker" {
            Mock Test-WslSystemdConfigured { $false }
            Mock Get-WslConf { @{} }

            Install-WslDevStack -DistroName "Debian" -Runtime docker -Confirm:$false | Out-Null

            Should -Invoke Set-WslConf -Times 1 -Exactly -ParameterFilter {
                $Sections.boot.systemd -eq "true" -and
                -not $Sections.boot.ContainsKey("command") -and
                -not $Sections.ContainsKey("interop") -and
                -not $Sections.ContainsKey("automount")
            }
        }

        It "Should add only the boot command for Podman when systemd is already configured" {
            Mock Test-WslSystemdConfigured { $true }
            Mock Get-WslConf { @{ boot = @{ systemd = "true" } } }

            Install-WslDevStack -DistroName "Debian" -Confirm:$false | Out-Null

            Should -Invoke Set-WslConf -Times 1 -Exactly -ParameterFilter {
                $Sections.boot.command -eq "mount --make-rshared /"
            }
        }

        It "Should not call Set-WslConf when systemd and the boot command are present" {
            Install-WslDevStack -DistroName "Debian" -Confirm:$false | Out-Null

            Should -Invoke Set-WslConf -Times 0 -Exactly
        }

        It "Should not call Set-WslConf for Docker when systemd is configured" {
            Mock Get-WslConf { @{ boot = @{ systemd = "true" } } }

            Install-WslDevStack -DistroName "Debian" -Runtime docker -Confirm:$false | Out-Null

            Should -Invoke Set-WslConf -Times 0 -Exactly
        }

        It "Should keep the existing default user under user.default" {
            Mock Test-WslSystemdConfigured { $false }
            Mock Get-WslDefaultUser { "dev" }

            Install-WslDevStack -DistroName "Debian" -Confirm:$false | Out-Null

            Should -Invoke Set-WslConf -Times 1 -Exactly -ParameterFilter {
                $Sections.user.default -eq "dev"
            }
        }
    }

    Context "Script arguments and order" {
        It "Should pass runtime, username and claude-code=<Expected> to the dev-stack script" -ForEach @(
            @{ Switch = $false; Expected = "false" }
            @{ Switch = $true; Expected = "true" }
        ) {
            if ($Switch) {
                Install-WslDevStack -DistroName "Debian" -ClaudeCode -Confirm:$false | Out-Null
            }
            else {
                Install-WslDevStack -DistroName "Debian" -Confirm:$false | Out-Null
            }

            $passed = $script:scriptArgs["setup-dev-stack.sh"]
            $passed | Should -Contain "--runtime=podman"
            $passed | Should -Contain "--username=dev"
            $passed | Should -Contain "--claude-code=$Expected"
        }

        It "Should pass --runtime=docker for -Runtime docker" {
            Install-WslDevStack -DistroName "Debian" -Runtime docker -Confirm:$false | Out-Null

            $script:scriptArgs["setup-dev-stack.sh"] | Should -Contain "--runtime=docker"
        }

        It "Should call the dev-stack script with -StopAtError `$false" {
            Install-WslDevStack -DistroName "Debian" -Confirm:$false | Out-Null

            Should -Invoke Invoke-WslDistroScript -Times 1 -Exactly -ParameterFilter {
                $ScriptPath -like "*setup-dev-stack.sh" -and $StopAtError -eq $false -and $DistroName -eq "Debian"
            }
        }

        It "Should run the binfmt script before the dev-stack script" {
            Install-WslDevStack -DistroName "Debian" -Confirm:$false | Out-Null

            $script:calls | Should -Be @("setup-binfmt-interop.sh", "setup-dev-stack.sh")
        }

        It "Should pass script paths that end in scripts\<Name>" -ForEach @(
            @{ Name = "setup-dev-stack.sh" }
            @{ Name = "setup-binfmt-interop.sh" }
        ) {
            Install-WslDevStack -DistroName "Debian" -Confirm:$false | Out-Null

            Should -Invoke Invoke-WslDistroScript -Times 1 -Exactly -ParameterFilter {
                $ScriptPath -like "*scripts\$Name"
            }
        }
    }

    Context "Script failures return false and write an error" {
        It "Should return false and name '<Keyword>' for dev-stack exit code <Code>" -ForEach @(
            @{ Code = 1; Keyword = "prerequisite" }
            @{ Code = 2; Keyword = "apt" }
            @{ Code = 3; Keyword = "role" }
            @{ Code = 4; Keyword = "argument" }
            @{ Code = 5; Keyword = "playbook" }
            @{ Code = 9; Keyword = "9" }
        ) {
            $script:devStackExit = $Code

            $result = Install-WslDevStack -DistroName "Debian" -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable err

            $result | Should -BeFalse
            ($err | Out-String) | Should -Match "(?i)$Keyword"
        }

        It "Should return false, name binfmt or interop and skip the dev-stack script when binfmt fails" {
            $script:binfmtExit = 3

            $result = Install-WslDevStack -DistroName "Debian" -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable err

            $result | Should -BeFalse
            ($err | Out-String) | Should -Match "(?i)binfmt|interop"
            $script:calls | Should -Not -Contain "setup-dev-stack.sh"
        }
    }

    Context "Success" {
        It "Should return true for exit code 0 and stop the distribution" {
            $result = Install-WslDevStack -DistroName "Debian" -Confirm:$false

            $result | Should -BeTrue
            Should -Invoke Stop-WslDistro -Times 1 -ParameterFilter { $Name -eq "Debian" }
        }
    }

    Context "-WhatIf" {
        It "Should return false and run no script" {
            $result = Install-WslDevStack -DistroName "Debian" -WhatIf

            $result | Should -BeFalse
            Should -Invoke Invoke-WslDistroScript -Times 0 -Exactly
        }
    }
}
