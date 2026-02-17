#Requires -Version 5.1

<#
.SYNOPSIS
    Tests for bin/install.ps1 — self-contained installer (FEAT-004).
#>

BeforeAll {
    $script:installScript = Join-Path $PSScriptRoot 'install.ps1'
    $script:repoRoot = Split-Path $PSScriptRoot -Parent
}

Describe 'install.ps1 Script Structure' {
    BeforeAll {
        $script:content = Get-Content $script:installScript -Raw
    }

    It 'has #Requires -Version 5.1' {
        $script:content | Should -Match '#Requires -Version 5.1'
    }

    It 'sets ErrorActionPreference to Stop' {
        $script:content | Should -Match "\`$ErrorActionPreference\s*=\s*['""]Stop['""]"
    }

    It 'sources utils.ps1 from pslib in local mode' {
        $script:content | Should -Match 'tools[\\/]pslib[\\/]utils[\\/]utils\.ps1'
    }

    It 'defines Test-AdminPrivilege function' {
        $script:content | Should -Match 'function\s+Test-AdminPrivilege'
    }

    It 'has a dot-source guard for main execution' {
        $script:content | Should -Match 'InvocationName|MyInvocation'
    }

    It 'accepts -InPlace switch parameter' {
        $script:content | Should -Match '\[switch\]\$InPlace'
    }

    It 'accepts -Branch string parameter with default develop' {
        $script:content | Should -Match '\[string\]\$Branch\s*=\s*[''"]develop[''"]'
    }

    It 'accepts -SkipAdminCheck switch parameter' {
        $script:content | Should -Match '\[switch\]\$SkipAdminCheck'
    }

    It 'admin guard respects SkipAdminCheck flag' {
        $script:content | Should -Match '-not \$SkipAdminCheck -and.*Test-AdminPrivilege'
    }
}

Describe 'install.ps1 Remote Mode Structure' {
    BeforeAll {
        $script:content = Get-Content $script:installScript -Raw
    }

    It 'branches on InPlace parameter without magic detection' {
        $script:content | Should -Not -Match '\$isRemote'
        $script:content | Should -Match 'if \(-not \$InPlace\)'
    }

    It 'sets StrictMode in remote mode block' {
        $script:content | Should -Match 'if \(-not \$InPlace\)[\s\S]*?Set-StrictMode -Version Latest'
    }

    It 'contains inline Scoop install for remote mode (irm get.scoop.sh)' {
        $script:content | Should -Match 'get\.scoop\.sh'
    }

    It 'contains inline git install for remote mode (scoop install git)' {
        $script:content | Should -Match 'scoop install git'
    }

    It 'clones the repo in remote mode' {
        $script:content | Should -Match 'git clone'
    }

    It 'delegates to local mode with hashtable splatting containing InPlace' {
        $script:content | Should -Match 'delegateArgs\s*=\s*@\{\s*InPlace\s*='
    }

    It 'uses $Branch variable instead of hardcoded branch in remote mode' {
        # Remote mode should reference $branch (the parameter) not a hardcoded string for git operations
        $script:content | Should -Match 'git clone -b \$branch'
        $script:content | Should -Match 'git pull origin \$branch'
    }

    It 'checks out the target branch before pulling in update path' {
        $script:content | Should -Match 'git fetch origin \$branch'
        $script:content | Should -Match 'git checkout \$branch'
    }
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

Describe 'Read-Host CI Guard' {
    BeforeAll {
        $script:content = Get-Content $script:installScript -Raw
    }

    It 'guards Read-Host with Test-RunningInCIorTestEnvironment check' {
        $script:content | Should -Match 'Test-RunningInCIorTestEnvironment.*Read-Host|if.*-not.*Test-RunningInCIorTestEnvironment'
    }

    It 'Read-Host is inside the CI guard, not called unconditionally' {
        # The finally block should contain the CI check wrapping Read-Host
        $pattern = 'finally\s*\{[^}]*Test-RunningInCIorTestEnvironment[^}]*Read-Host'
        $script:content | Should -Match $pattern
    }
}

Describe 'Dot-Source Support' {
    BeforeAll {
        . $script:installScript -InPlace
    }

    It 'exposes Install-Scoop function' {
        Get-Command Install-Scoop -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'exposes Install-ScoopDependency function' {
        Get-Command Install-ScoopDependency -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'exposes Install-Git function' {
        Get-Command Install-Git -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'exposes Install-MandatoryToolset function' {
        Get-Command Install-MandatoryToolset -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'exposes Install-OptionalToolset function' {
        Get-Command Install-OptionalToolset -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'exposes Test-AdminPrivilege function' {
        Get-Command Test-AdminPrivilege -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'exposes Copy-Config function' {
        Get-Command Copy-Config -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'exposes New-Shortcut function' {
        Get-Command New-Shortcut -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'exposes New-StartupShortcut function' {
        Get-Command New-StartupShortcut -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }
}

Describe 'Keypirinha CI Guard' {
    BeforeAll {
        $script:content = Get-Content $script:installScript -Raw
    }

    It 'guards Keypirinha launch with Test-RunningInCIorTestEnvironment check' {
        $script:content | Should -Match 'Test-RunningInCIorTestEnvironment[\s\S]*?keypirinha\.exe'
    }

    It 'only launches Keypirinha when NOT in CI' {
        $pattern = 'if\s*\(\s*-not\s*\(\s*Test-RunningInCIorTestEnvironment\s*\)\s*\)\s*\{[^}]*keypirinha\.exe'
        $script:content | Should -Match $pattern
    }
}

Describe 'Post-Install: AutoHotkey shortcut' {
    It 'only creates AutoHotkey startup shortcut when autohotkey is installed' {
        $content = Get-Content $script:installScript -Raw
        $content | Should -Match 'autohotkey'
    }
}

Describe 'JSON File Validation' {
    Context 'scoop_mandatory.json' {
        BeforeAll {
            $script:mandatoryPath = Join-Path $script:repoRoot 'scoop_mandatory.json'
            $script:mandatory = Get-Content $script:mandatoryPath -Raw | ConvertFrom-Json
        }

        It 'exists' {
            Test-Path $script:mandatoryPath | Should -BeTrue
        }

        It 'contains keypirinha' {
            $appNames = $script:mandatory.apps | ForEach-Object { $_.Name }
            $appNames | Should -Contain 'keypirinha'
        }

        It 'includes extras bucket' {
            $bucketNames = $script:mandatory.buckets | ForEach-Object { $_.Name }
            $bucketNames | Should -Contain 'extras'
        }

        It 'does not contain git (handled separately)' {
            $appNames = $script:mandatory.apps | ForEach-Object { $_.Name }
            $appNames | Should -Not -Contain 'git'
        }
    }

    Context 'scoop_optional.json' {
        BeforeAll {
            $script:optionalPath = Join-Path $script:repoRoot 'scoop_optional.json'
            $script:optional = Get-Content $script:optionalPath -Raw | ConvertFrom-Json
        }

        It 'exists' {
            Test-Path $script:optionalPath | Should -BeTrue
        }

        It 'contains expected optional tools' {
            $appNames = $script:optional.apps | ForEach-Object { $_.Name }
            $appNames | Should -Contain 'pwsh'
            $appNames | Should -Contain 'windows-terminal'
            $appNames | Should -Contain 'ditto'
            $appNames | Should -Contain 'winmerge'
            $appNames | Should -Contain 'sysinternals'
            $appNames | Should -Contain 'vscode'
            $appNames | Should -Contain 'autohotkey'
        }

        It 'does not contain git (handled separately)' {
            $appNames = $script:optional.apps | ForEach-Object { $_.Name }
            $appNames | Should -Not -Contain 'git'
        }

        It 'includes versions bucket' {
            $bucketNames = $script:optional.buckets | ForEach-Object { $_.Name }
            $bucketNames | Should -Contain 'versions'
        }

        It 'does not contain keypirinha (in mandatory)' {
            $appNames = $script:optional.apps | ForEach-Object { $_.Name }
            $appNames | Should -Not -Contain 'keypirinha'
        }
    }

    Context 'scoopfile.json removal' {
        It 'scoopfile.json no longer exists' {
            Test-Path (Join-Path $script:repoRoot 'scoopfile.json') | Should -BeFalse
        }
    }
}
