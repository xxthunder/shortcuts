#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    . "$PSScriptRoot\scoop.ps1"
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
    It 'returns all app names in CI environment' {
        $apps = @(
            [PSCustomObject]@{ Name = '7zip'; InstalledVersion = '24.08'; LatestVersion = '24.09' }
            [PSCustomObject]@{ Name = 'git'; InstalledVersion = '2.46.0'; LatestVersion = '2.47.0' }
        )

        # Running in CI (GitHub Actions), so should return all
        $result = @(Select-ScoopApp -Apps $apps)

        $result.Count | Should -Be 2
        $result | Should -Contain '7zip'
        $result | Should -Contain 'git'
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
