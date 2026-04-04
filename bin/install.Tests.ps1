#Requires -Version 7.4

<#
.SYNOPSIS
    Tests for bin/install.ps1 — self-contained installer (FEAT-004).
#>

BeforeAll {
    . "$PSScriptRoot\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    $script:installScript = Join-Path $PSScriptRoot 'install.ps1'
}

AfterAll {
    Stop-SutIsolation
}

Describe 'Install-Scoop' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    Context 'when Scoop is already installed' {
        BeforeAll {
            Mock Get-Command { return @{ Name = 'scoop' } } -ParameterFilter { $Name -eq 'scoop' }
            Mock Invoke-CommandLine {}
            Mock Invoke-Expression {}
            Mock Invoke-RestMethod {}
        }

        It 'skips installation' {
            Install-Scoop
            Should -Not -Invoke Invoke-RestMethod
            Should -Not -Invoke Invoke-Expression
        }
    }

    Context 'when Scoop is not installed' {
        BeforeAll {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'scoop' }
            Mock Invoke-RestMethod { 'echo "scoop installer"' }
            Mock Invoke-Expression {}
            Mock Initialize-EnvPath {}
        }

        It 'downloads and runs Scoop installer' {
            Install-Scoop
            Should -Invoke Invoke-RestMethod -Times 1
            Should -Invoke Invoke-Expression -Times 1
        }

        It 'refreshes PATH after installation' {
            Install-Scoop
            Should -Invoke Initialize-EnvPath -Times 1
        }
    }
}

Describe 'Install-ScoopDependency' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    BeforeEach {
        Mock Invoke-CommandLine {}
    }

    It 'installs dependencies in the correct order: lessmsi, 7zip, innounp, dark' {
        $script:order = @()
        Mock Invoke-CommandLine {
            $script:order += $CommandLine
        }

        Install-ScoopDependency

        $script:order.Count | Should -Be 4
        $script:order[0] | Should -Match 'lessmsi'
        $script:order[1] | Should -Match '7zip'
        $script:order[2] | Should -Match 'innounp'
        $script:order[3] | Should -Match 'dark'
    }

    It 'uses StopAtError false so missing deps do not abort' {
        Mock Invoke-CommandLine {} -ParameterFilter { $StopAtError -eq $false }

        Install-ScoopDependency

        Should -Invoke Invoke-CommandLine -Times 4 -ParameterFilter { $StopAtError -eq $false }
    }
}

Describe 'Install-Git' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    Context 'when git is already in PATH' {
        BeforeAll {
            Mock Get-Command { return @{ Name = 'git' } } -ParameterFilter { $Name -eq 'git' }
            Mock Invoke-CommandLine {}
        }

        It 'skips installation' {
            Install-Git
            Should -Not -Invoke Invoke-CommandLine
        }
    }

    Context 'when git is not in PATH' {
        BeforeAll {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'git' }
            Mock Invoke-CommandLine {}
            Mock Initialize-EnvPath {}
        }

        It 'installs git via scoop' {
            Install-Git
            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like '*scoop install git*'
            }
        }

        It 'refreshes PATH after installation' {
            Install-Git
            Should -Invoke Initialize-EnvPath -Times 1
        }
    }
}

Describe 'Install-MandatoryToolset' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    BeforeEach {
        Mock Invoke-CommandLine {}
    }

    It 'imports scoop_mandatory.json' {
        Install-MandatoryToolset
        Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
            $CommandLine -like '*scoop import*scoop_mandatory.json*'
        }
    }
}

Describe 'Install-OptionalToolset' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    BeforeEach {
        Mock Invoke-CommandLine {}
    }

    Context 'in CI environment' {
        BeforeAll {
            Mock Test-RunningInCIorTestEnvironment { return $true }
        }

        It 'skips optional tools without prompting' {
            Install-OptionalToolset
            Should -Not -Invoke Invoke-CommandLine
        }
    }

    Context 'in interactive environment without -Force' {
        BeforeAll {
            Mock Test-RunningInCIorTestEnvironment { return $false }
            Mock Get-UserConfirmation { return $true }
        }

        It 'prompts user and installs when confirmed' {
            Install-OptionalToolset
            Should -Invoke Get-UserConfirmation -Times 1
            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like '*scoop import*scoop_optional.json*'
            }
        }
    }

    Context 'in interactive environment when user declines' {
        BeforeAll {
            Mock Test-RunningInCIorTestEnvironment { return $false }
            Mock Get-UserConfirmation { return $false }
        }

        It 'does not install optional tools' {
            Install-OptionalToolset
            Should -Not -Invoke Invoke-CommandLine
        }
    }

    Context 'with -Force switch' {
        BeforeAll {
            Mock Test-RunningInCIorTestEnvironment { return $false }
            Mock Get-UserConfirmation {}
        }

        It 'installs without prompting' {
            Install-OptionalToolset -Force
            Should -Not -Invoke Get-UserConfirmation
            Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
                $CommandLine -like '*scoop import*scoop_optional.json*'
            }
        }
    }
}

Describe 'Install-PwshSpectreDependency' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    Context 'when PwshSpectreConsole is already installed' {
        BeforeAll {
            Mock Get-InstalledModule { return @{ Name = 'PwshSpectreConsole'; Version = '2.1.0' } } -ParameterFilter { $Name -eq 'PwshSpectreConsole' }
            Mock Install-Module {}
            Mock Write-Host {}
        }

        It 'skips installation' {
            Install-PwshSpectreDependency
            Should -Not -Invoke Install-Module
        }
    }

    Context 'when PwshSpectreConsole is not installed' {
        BeforeAll {
            Mock Get-InstalledModule { $null } -ParameterFilter { $Name -eq 'PwshSpectreConsole' }
            Mock Get-PackageProvider { return @{ Name = 'NuGet' } } -ParameterFilter { $Name -eq 'NuGet' }
            Mock Install-Module {}
            Mock Write-Host {}
        }

        It 'installs PwshSpectreConsole from PSGallery' {
            Install-PwshSpectreDependency
            Should -Invoke Install-Module -Times 1 -ParameterFilter {
                $Name -eq 'PwshSpectreConsole' -and
                $Repository -eq 'PSGallery' -and
                $Scope -eq 'CurrentUser'
            }
        }
    }

    Context 'when NuGet provider is missing' {
        BeforeAll {
            Mock Get-InstalledModule { $null } -ParameterFilter { $Name -eq 'PwshSpectreConsole' }
            Mock Get-PackageProvider { $null } -ParameterFilter { $Name -eq 'NuGet' }
            Mock Install-PackageProvider {}
            Mock Install-Module {}
            Mock Write-Host {}
        }

        It 'installs NuGet provider before the module' {
            Install-PwshSpectreDependency
            Should -Invoke Install-PackageProvider -Times 1 -ParameterFilter {
                $Name -eq 'NuGet' -and
                $Scope -eq 'CurrentUser'
            }
            Should -Invoke Install-Module -Times 1
        }
    }
}

Describe 'Copy-Config' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    It 'calls robocopy with source then destination in correct order' {
        $script:robocopyArgs = $null
        Mock robocopy { $script:robocopyArgs = $args; $global:LASTEXITCODE = 0 }

        Copy-Config -source 'C:\from' -destination 'C:\to'

        $script:robocopyArgs[0] | Should -Be 'C:\from'
        $script:robocopyArgs[1] | Should -Be 'C:\to'
    }

    It 'passes /E /IS /IT flags to robocopy' {
        $script:robocopyArgs = $null
        Mock robocopy { $script:robocopyArgs = $args; $global:LASTEXITCODE = 0 }

        Copy-Config -source 'C:\from' -destination 'C:\to'

        $script:robocopyArgs | Should -Contain '/E'
        $script:robocopyArgs | Should -Contain '/IS'
        $script:robocopyArgs | Should -Contain '/IT'
    }

    It 'does not throw when robocopy exit code is less than 8' {
        Mock robocopy { $global:LASTEXITCODE = 3 }

        { Copy-Config -source 'C:\from' -destination 'C:\to' } | Should -Not -Throw
    }

    It 'throws when robocopy exit code is 8 or higher' {
        Mock robocopy { $global:LASTEXITCODE = 8 }

        { Copy-Config -source 'C:\from' -destination 'C:\to' } | Should -Throw "*failed*"
    }

    It 'supports -WhatIf and does not call robocopy' {
        Mock robocopy {}

        Copy-Config -source 'C:\from' -destination 'C:\to' -WhatIf

        Should -Not -Invoke robocopy
    }
}

Describe 'New-Shortcut' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    It 'creates a .lnk shortcut with the correct target path' {
        $script:savedPath = $null
        $mockShortcut = [PSCustomObject]@{ TargetPath = '' }
        $mockShortcut | Add-Member -MemberType ScriptMethod -Name Save -Value { $script:savedPath = $this.TargetPath }
        $mockShell = [PSCustomObject]@{}
        $mockShell | Add-Member -MemberType ScriptMethod -Name CreateShortcut -Value { param([string]$lnkPath) $script:createdLnk = $lnkPath; $mockShortcut } -Force
        Mock New-Object { $mockShell } -ParameterFilter { $ComObject -eq 'WScript.Shell' }

        New-Shortcut -target 'C:\test.lnk' -path 'C:\target.exe'

        $mockShortcut.TargetPath | Should -Be 'C:\target.exe'
    }

    It 'supports -WhatIf and does not create shortcut' {
        Mock New-Object {}

        New-Shortcut -target 'C:\test.lnk' -path 'C:\target.exe' -WhatIf

        Should -Not -Invoke New-Object
    }
}

Describe 'New-StartupShortcut' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    It 'delegates to New-Shortcut with the startup folder path' {
        Mock New-Shortcut {}

        New-StartupShortcut -name 'myapp' -path 'C:\myapp.exe'

        $expectedDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
        $expectedLnk = Join-Path $expectedDir 'myapp.lnk'
        Should -Invoke New-Shortcut -Times 1 -ParameterFilter {
            $target -eq $expectedLnk -and $path -eq 'C:\myapp.exe'
        }
    }

    It 'supports -WhatIf and does not delegate' {
        Mock New-Shortcut {}

        New-StartupShortcut -name 'myapp' -path 'C:\myapp.exe' -WhatIf

        Should -Not -Invoke New-Shortcut
    }
}
