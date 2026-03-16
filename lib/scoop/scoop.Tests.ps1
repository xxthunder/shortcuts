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
        $statusOutput = @(
            "Name      Installed Version  Latest Version  Missing Dependencies  Info"
            "----      -----------------  --------------  --------------------  ----"
            "7zip      24.08              24.09"
            "git       2.46.0             2.47.0"
        )
        Mock Invoke-CommandLine { return $statusOutput }

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
        $statusOutput = @(
            "Name      Installed Version  Latest Version  Missing Dependencies  Info"
            "----      -----------------  --------------  --------------------  ----"
        )
        Mock Invoke-CommandLine { return $statusOutput }

        $result = @(Get-ScoopUpdatableApp)

        $result.Count | Should -Be 0
    }

    It 'parses structured PSCustomObject output from modern scoop' {
        $statusOutput = @(
            [PSCustomObject]@{ Name = 'gimp'; 'Installed Version' = '3.0.8-2'; 'Latest Version' = '3.2.0'; 'Missing Dependencies' = ''; Info = '' }
            [PSCustomObject]@{ Name = 'pwsh'; 'Installed Version' = '7.5.4'; 'Latest Version' = '7.5.5'; 'Missing Dependencies' = ''; Info = '' }
        )
        Mock Invoke-CommandLine { return $statusOutput }

        $result = @(Get-ScoopUpdatableApp)

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be 'gimp'
        $result[0].InstalledVersion | Should -Be '3.0.8-2'
        $result[0].LatestVersion | Should -Be '3.2.0'
        $result[1].Name | Should -Be 'pwsh'
    }

    It 'skips blank lines and malformed rows in legacy output' {
        $statusOutput = @(
            "Name      Installed Version  Latest Version  Missing Dependencies  Info"
            "----      -----------------  --------------  --------------------  ----"
            ""
            "7zip      24.08              24.09"
            "   "
            "malformed-line"
            "git       2.46.0             2.47.0"
        )
        Mock Invoke-CommandLine { return $statusOutput }

        $result = @(Get-ScoopUpdatableApp)

        $result.Count | Should -Be 2
        $result[0].Name | Should -Be '7zip'
        $result[1].Name | Should -Be 'git'
    }

    It 'handles single updatable app' {
        $statusOutput = @(
            "Name      Installed Version  Latest Version  Missing Dependencies  Info"
            "----      -----------------  --------------  --------------------  ----"
            "nodejs    20.11.0            22.0.0"
        )
        Mock Invoke-CommandLine { return $statusOutput }

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

Describe 'Select-ScoopApp' {
    BeforeEach {
        $script:testApps = @(
            [PSCustomObject]@{ Name = '7zip'; InstalledVersion = '24.08'; LatestVersion = '24.09' }
            [PSCustomObject]@{ Name = 'git'; InstalledVersion = '2.46.0'; LatestVersion = '2.47.0' }
            [PSCustomObject]@{ Name = 'pwsh'; InstalledVersion = '7.5.4'; LatestVersion = '7.5.5' }
        )
    }

    Context 'In CI environment' {
        It 'returns all app names' {
            Mock Test-RunningInCIorTestEnvironment { return $true }

            $result = @(Select-ScoopApp -Apps $script:testApps)

            $result.Count | Should -Be 3
            $result | Should -Contain '7zip'
            $result | Should -Contain 'git'
            $result | Should -Contain 'pwsh'
        }
    }

    Context 'In interactive environment' {
        BeforeEach {
            Mock Test-RunningInCIorTestEnvironment { return $false }
            Mock Write-WarningMsg {}
        }

        It 'returns all apps when user enters A' {
            Mock Read-Host { return 'A' }

            $result = @(Select-ScoopApp -Apps $script:testApps)

            $result.Count | Should -Be 3
        }

        It 'returns all apps when user enters lowercase a' {
            Mock Read-Host { return 'a' }

            $result = @(Select-ScoopApp -Apps $script:testApps)

            $result.Count | Should -Be 3
        }

        It 'returns selected apps by comma-separated numbers' {
            Mock Read-Host { return '1,3' }

            $result = @(Select-ScoopApp -Apps $script:testApps)

            $result.Count | Should -Be 2
            $result | Should -Contain '7zip'
            $result | Should -Contain 'pwsh'
        }

        It 'warns on out-of-range number' {
            Mock Read-Host { return '5' }

            $result = @(Select-ScoopApp -Apps $script:testApps)

            $result.Count | Should -Be 0
            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like '*Invalid number*' }
        }

        It 'warns on non-numeric input' {
            Mock Read-Host { return 'xyz' }

            $result = @(Select-ScoopApp -Apps $script:testApps)

            $result.Count | Should -Be 0
            Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like '*Invalid input*' }
        }

        It 'handles mixed valid and invalid input' {
            Mock Read-Host { return '1,abc,99' }

            $result = @(Select-ScoopApp -Apps $script:testApps)

            $result.Count | Should -Be 1
            $result | Should -Contain '7zip'
            Should -Invoke Write-WarningMsg -Times 2
        }

        It 'returns empty array on empty input' {
            Mock Read-Host { return '' }

            $result = @(Select-ScoopApp -Apps $script:testApps)

            $result.Count | Should -Be 0
        }
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
        $global:LASTEXITCODE = 0
        Mock Invoke-CommandLine { $global:LASTEXITCODE = 0 }

        Update-ScoopApp -AppNames @('7zip')

        Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq 'scoop update 7zip' } -Times 1
        Should -Invoke Write-Success -Times 1
    }

    It 'updates multiple apps' {
        $global:LASTEXITCODE = 0
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
    }

    It 'shows error when scoop is not installed' {
        Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'scoop' }

        Invoke-ScoopUpdate

        Should -Invoke Write-ErrorMsg -ParameterFilter { $Message -like '*Scoop is not installed*' } -Times 1
    }

    It 'refreshes scoop before checking for updates' {
        Mock Get-ScoopUpdatableApp { return @() }

        Invoke-ScoopUpdate

        Should -Invoke Invoke-CommandLine -ParameterFilter { $CommandLine -eq 'scoop update' } -Times 1
    }

    It 'shows up-to-date message when no updates available' {
        Mock Get-ScoopUpdatableApp { return @() }

        Invoke-ScoopUpdate

        Should -Invoke Write-Success -ParameterFilter { $Message -like '*up to date*' } -Times 1
    }

    It 'runs full update flow when apps are updatable' {
        $apps = @(
            [PSCustomObject]@{ Name = '7zip'; InstalledVersion = '24.08'; LatestVersion = '24.09' }
        )
        Mock Get-ScoopUpdatableApp { return $apps }
        Mock Show-ScoopUpdatableApp {}
        Mock Select-ScoopApp { return @('7zip') }
        Mock Update-ScoopApp {}

        Invoke-ScoopUpdate

        Should -Invoke Show-ScoopUpdatableApp -Times 1
        Should -Invoke Select-ScoopApp -Times 1
        Should -Invoke Update-ScoopApp -Times 1
    }

    It 'shows warning when no apps selected' {
        $apps = @(
            [PSCustomObject]@{ Name = '7zip'; InstalledVersion = '24.08'; LatestVersion = '24.09' }
        )
        Mock Get-ScoopUpdatableApp { return $apps }
        Mock Show-ScoopUpdatableApp {}
        Mock Select-ScoopApp { return @() }

        Invoke-ScoopUpdate

        Should -Invoke Write-WarningMsg -ParameterFilter { $Message -like '*No apps selected*' } -Times 1
    }
}
