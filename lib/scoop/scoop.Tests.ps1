#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\scoop.ps1"
}

AfterAll {
    Stop-SutIsolation
}

Describe 'Get-ScoopUpdatableApp' {
    BeforeEach {
        Mock Invoke-CommandLine {}
        Mock Write-Status {}
    }

    It 'returns empty array when scoop status returns null' {
        Mock Invoke-CommandLine { return $null }

        $result = @(Get-ScoopUpdatableApp)

        $result.Count | Should -Be 0
    }

    It 'parses scoop status output with updatable apps' {
        Mock Invoke-CommandLine { return @(
            "Name      Installed Version  Latest Version  Missing Dependencies  Info"
            "----      -----------------  --------------  --------------------  ----"
            "7zip      24.08              24.09"
            "git       2.46.0             2.47.0"
        ) }

        $result = @(Get-ScoopUpdatableApp)

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be '7zip'
        $result[0].InstalledVersion | Should -Be '24.08'
        $result[0].LatestVersion | Should -Be '24.09'
        $result[1].Name | Should -Be 'git'
        $result[1].InstalledVersion | Should -Be '2.46.0'
        $result[1].LatestVersion | Should -Be '2.47.0'
    }

    It 'returns empty array when no apps need updating' {
        Mock Invoke-CommandLine { return @(
            "Name      Installed Version  Latest Version  Missing Dependencies  Info"
            "----      -----------------  --------------  --------------------  ----"
        ) }

        $result = @(Get-ScoopUpdatableApp)

        $result.Count | Should -Be 0
    }

    It 'parses structured PSCustomObject output from modern scoop' {
        Mock Invoke-CommandLine { return @(
            [PSCustomObject]@{ Name = 'gimp'; 'Installed Version' = '3.0.8-2'; 'Latest Version' = '3.2.0'; 'Missing Dependencies' = ''; Info = '' }
            [PSCustomObject]@{ Name = 'pwsh'; 'Installed Version' = '7.5.4'; 'Latest Version' = '7.5.5'; 'Missing Dependencies' = ''; Info = '' }
        ) }

        $result = @(Get-ScoopUpdatableApp)

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'gimp'
        $result[0].InstalledVersion | Should -Be '3.0.8-2'
        $result[0].LatestVersion | Should -Be '3.2.0'
        $result[1].Name | Should -Be 'pwsh'
    }

    It 'skips blank lines and malformed rows in legacy output' {
        Mock Invoke-CommandLine { return @(
            "Name      Installed Version  Latest Version  Missing Dependencies  Info"
            "----      -----------------  --------------  --------------------  ----"
            ""
            "7zip      24.08              24.09"
            "   "
            "malformed-line"
            "git       2.46.0             2.47.0"
        ) }

        $result = @(Get-ScoopUpdatableApp)

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be '7zip'
        $result[1].Name | Should -Be 'git'
    }

    It 'handles single updatable app' {
        Mock Invoke-CommandLine { return @(
            "Name      Installed Version  Latest Version  Missing Dependencies  Info"
            "----      -----------------  --------------  --------------------  ----"
            "nodejs    20.11.0            22.0.0"
        ) }

        $result = @(Get-ScoopUpdatableApp)

        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'nodejs'
    }
}

Describe 'Show-ScoopUpdatableApp' {
    BeforeEach {
        Mock Write-Host {}
    }

    It 'displays header and app entries' {
        $apps = @(
            [PSCustomObject]@{ Name = '7zip'; InstalledVersion = '24.08'; LatestVersion = '24.09' }
            [PSCustomObject]@{ Name = 'git'; InstalledVersion = '2.46.0'; LatestVersion = '2.47.0' }
        )

        Show-ScoopUpdatableApp -Apps $apps

        Should -Invoke Write-Host -ParameterFilter { $Object -eq "Updatable Apps:" } -Times 1
    }
}

Describe 'Read-ScoopMenuChoice' {
    BeforeEach {
        Mock Write-WarningMsg {}
        $script:testApps = @(
            [PSCustomObject]@{ Name = '7zip'; InstalledVersion = '24.08'; LatestVersion = '24.09' }
            [PSCustomObject]@{ Name = 'git'; InstalledVersion = '2.46.0'; LatestVersion = '2.47.0' }
            [PSCustomObject]@{ Name = 'pwsh'; InstalledVersion = '7.5.4'; LatestVersion = '7.5.5' }
        )
    }

    It 'returns update-all when user enters A' {
        Mock Read-Host { return 'A' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'update'
        @($result.Apps).Count | Should -Be 3
    }

    It 'returns update-all when user enters lowercase a' {
        Mock Read-Host { return 'a' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'update'
        @($result.Apps).Count | Should -Be 3
    }

    It 'returns selected apps by comma-separated numbers' {
        Mock Read-Host { return '1,3' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'update'
        @($result.Apps).Count | Should -Be 2
        $result.Apps | Should -Contain '7zip'
        $result.Apps | Should -Contain 'pwsh'
    }

    It 'returns refresh when user enters R' {
        Mock Read-Host { return 'R' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'refresh'
    }

    It 'returns refresh when user enters lowercase r' {
        Mock Read-Host { return 'r' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'refresh'
    }

    It 'returns quit when user enters Q' {
        Mock Read-Host { return 'Q' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'quit'
    }

    It 'returns quit when user enters lowercase q' {
        Mock Read-Host { return 'q' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'quit'
    }

    It 'returns refresh even when no apps are updatable' {
        Mock Read-Host { return 'R' }

        $result = Read-ScoopMenuChoice -Apps @()

        $result.Action | Should -Be 'refresh'
    }

    It 'warns on out-of-range number and returns update with no apps' {
        Mock Read-Host { return '5' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'update'
        @($result.Apps).Count | Should -Be 0
        Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like '*Invalid number*' }
    }

    It 'warns on non-numeric input and returns update with no apps' {
        Mock Read-Host { return 'xyz' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'update'
        @($result.Apps).Count | Should -Be 0
        Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like '*Invalid input*' }
    }

    It 'handles mixed valid and invalid input' {
        Mock Read-Host { return '1,abc,99' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'update'
        @($result.Apps).Count | Should -Be 1
        $result.Apps | Should -Contain '7zip'
        Should -Invoke Write-WarningMsg -Times 2
    }

    It 'returns update with no apps on empty input' {
        Mock Read-Host { return '' }

        $result = Read-ScoopMenuChoice -Apps $script:testApps

        $result.Action | Should -Be 'update'
        @($result.Apps).Count | Should -Be 0
    }
}

Describe 'Get-ScoopHostRawUi' {
    It 'returns the raw UI of the current host' {
        Get-ScoopHostRawUi | Should -Be $Host.UI.RawUI
    }
}

Describe 'Wait-ScoopKeyPress' {
    BeforeAll {
        # Stub raw UI: records the ReadKey call on itself ($this), so no real
        # console read happens and the test never blocks.
        function Get-StubRawUi {
            param([switch]$FailOnRead)

            $stub = [PSCustomObject]@{
                ReadKeyCalls   = 0
                ReadKeyOptions = $null
                FailOnRead     = [bool]$FailOnRead
            }
            $stub | Add-Member -MemberType ScriptMethod -Name ReadKey -Value {
                param($Options)
                $this.ReadKeyCalls++
                $this.ReadKeyOptions = $Options
                if ($this.FailOnRead) { throw 'The method or operation is not implemented.' }
                return $null
            }
            return $stub
        }
    }

    BeforeEach {
        Mock Write-Host {}
        # Default: interactive (not CI). CI-specific test overrides this.
        Mock Test-RunningInCIorTestEnvironment { return $false }
        $script:stubRawUi = Get-StubRawUi
        Mock Get-ScoopHostRawUi { return $script:stubRawUi }
    }

    It 'prompts and reads a single key without echo when interactive' {
        Wait-ScoopKeyPress

        Should -Invoke Get-ScoopHostRawUi -Times 1
        $script:stubRawUi.ReadKeyCalls | Should -Be 1
        $script:stubRawUi.ReadKeyOptions | Should -Be 'NoEcho,IncludeKeyDown'
        Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Press any key to continue...' } -Times 1
    }

    It 'skips the key read in CI/test environments' {
        Mock Test-RunningInCIorTestEnvironment { return $true }

        Wait-ScoopKeyPress

        Should -Invoke Get-ScoopHostRawUi -Times 0
        Should -Invoke Write-Host -Times 0
        $script:stubRawUi.ReadKeyCalls | Should -Be 0
    }

    It 'does not throw when the host has no interactive console' {
        $script:stubRawUi = Get-StubRawUi -FailOnRead

        { Wait-ScoopKeyPress } | Should -Not -Throw
        $script:stubRawUi.ReadKeyCalls | Should -Be 1
    }
}

Describe 'Update-ScoopApp' {
    BeforeEach {
        Mock Invoke-CommandLine {}
        Mock Write-Status {}
        Mock Write-Success {}
        Mock Write-ErrorMsg {}
    }

    It 'updates a single app successfully' {
        Mock Invoke-CommandLine { $global:LASTEXITCODE = 0 }

        Update-ScoopApp -AppNames @('7zip')

        Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq 'scoop update 7zip' } -Times 1
        Should -Invoke Write-Success -Times 1
    }

    It 'updates multiple apps' {
        Mock Invoke-CommandLine { $global:LASTEXITCODE = 0 }

        Update-ScoopApp -AppNames @('7zip', 'git')

        Should -Invoke Invoke-CommandLine -Times 2
    }

    It 'skips update when -WhatIf is used' {
        Update-ScoopApp -AppNames @('7zip', 'git') -WhatIf

        Should -Invoke Invoke-CommandLine -Times 0
    }

    It 'reports error when update fails' {
        Mock Invoke-CommandLine { $global:LASTEXITCODE = 1 }

        Update-ScoopApp -AppNames @('broken-app')

        Should -Invoke Write-ErrorMsg -Times 1
    }
}

Describe 'Invoke-ScoopUpdate' {
    BeforeEach {
        Mock Write-Host {}
        Mock Write-Status {}
        Mock Write-Success {}
        Mock Write-WarningMsg {}
        Mock Write-ErrorMsg {}
        Mock Invoke-CommandLine {}
        Mock Get-Command { return $true }
        Mock Show-ScoopUpdatableApp {}
        Mock Update-ScoopApp {}
        Mock Wait-ScoopKeyPress {}
        # Default: interactive (not CI). CI-specific test overrides this.
        Mock Test-RunningInCIorTestEnvironment { return $false }
        $script:oneApp = @(
            [PSCustomObject]@{ Name = '7zip'; InstalledVersion = '24.08'; LatestVersion = '24.09' }
        )
    }

    It 'shows error when scoop is not installed' {
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'scoop' }

        Invoke-ScoopUpdate

        Should -Invoke Write-ErrorMsg -ParameterFilter { $Message -like '*Scoop is not installed*' } -Times 1
    }

    It 'refreshes scoop exactly once at startup before the loop' {
        Mock Get-ScoopUpdatableApp { return @() }
        Mock Read-ScoopMenuChoice { return @{ Action = 'quit'; Apps = @() } }

        Invoke-ScoopUpdate

        Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq 'scoop update' } -Times 1
    }

    It 'shows up-to-date message when no updates available then quits' {
        Mock Get-ScoopUpdatableApp { return @() }
        Mock Read-ScoopMenuChoice { return @{ Action = 'quit'; Apps = @() } }

        Invoke-ScoopUpdate

        Should -Invoke Write-Success -ParameterFilter { $Message -like '*up to date*' } -Times 1
    }

    It 'updates selected apps, pauses for a keypress, then loops until quit' {
        Mock Get-ScoopUpdatableApp { return $script:oneApp }
        $script:menuCalls = 0
        Mock Read-ScoopMenuChoice {
            $script:menuCalls++
            if ($script:menuCalls -eq 1) { return @{ Action = 'update'; Apps = @('7zip') } }
            return @{ Action = 'quit'; Apps = @() }
        }

        Invoke-ScoopUpdate

        Should -Invoke Show-ScoopUpdatableApp -Times 2   # once per loop iteration (update, then quit)
        Should -Invoke Update-ScoopApp -ParameterFilter { $AppNames -contains '7zip' } -Times 1
        Should -Invoke Wait-ScoopKeyPress -Times 1
    }

    It 'refresh action re-runs the bucket refresh' {
        Mock Get-ScoopUpdatableApp { return @() }
        $script:menuCalls = 0
        Mock Read-ScoopMenuChoice {
            $script:menuCalls++
            if ($script:menuCalls -eq 1) { return @{ Action = 'refresh'; Apps = @() } }
            return @{ Action = 'quit'; Apps = @() }
        }

        Invoke-ScoopUpdate

        # startup refresh + one explicit refresh
        Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq 'scoop update' } -Times 2
    }

    It 'warns when update chosen with no apps selected' {
        Mock Get-ScoopUpdatableApp { return $script:oneApp }
        $script:menuCalls = 0
        Mock Read-ScoopMenuChoice {
            $script:menuCalls++
            if ($script:menuCalls -eq 1) { return @{ Action = 'update'; Apps = @() } }
            return @{ Action = 'quit'; Apps = @() }
        }

        Invoke-ScoopUpdate

        Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like '*No apps selected*' } -Times 1
        Should -Invoke Update-ScoopApp -Times 0
    }

    It 'catches an error inside an iteration and continues the loop' {
        $script:statusCalls = 0
        Mock Get-ScoopUpdatableApp {
            $script:statusCalls++
            if ($script:statusCalls -eq 1) { throw 'scoop exploded' }
            return @()
        }
        Mock Read-ScoopMenuChoice { return @{ Action = 'quit'; Apps = @() } }

        { Invoke-ScoopUpdate } | Should -Not -Throw
        Should -Invoke Write-ErrorMsg -Times 1
    }

    Context 'In CI environment' {
        It 'does exactly one update-all pass and never calls Read-Host' {
            Mock Test-RunningInCIorTestEnvironment { return $true }
            Mock Get-ScoopUpdatableApp { return $script:oneApp }
            Mock Read-Host { return 'Q' }

            Invoke-ScoopUpdate

            Should -Invoke Update-ScoopApp -ParameterFilter { $AppNames -contains '7zip' } -Times 1
            Should -Invoke Read-Host -Times 0
        }

        It 'reports everything up to date and returns without updating' {
            Mock Test-RunningInCIorTestEnvironment { return $true }
            Mock Get-ScoopUpdatableApp { return @() }
            Mock Read-Host { return 'Q' }

            Invoke-ScoopUpdate

            Should -Invoke Write-Success -ParameterFilter { $Message -like '*up to date*' } -Times 1
            Should -Invoke Show-ScoopUpdatableApp -Times 0
            Should -Invoke Update-ScoopApp -Times 0
            Should -Invoke Read-Host -Times 0
        }
    }
}
