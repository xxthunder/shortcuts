#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.2.0'}

<#
.SYNOPSIS
    Unit tests for load-check.ps1

.DESCRIPTION
    Runs the load check in-process with '&' against fixture trees in TestDrive.
    The functions the script dot-sources stay in the script's own scope.
#>

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation

    $script:LoadCheck = Join-Path $PSScriptRoot 'load-check.ps1'

    function Write-FixtureFile {
        param([string]$Root, [string]$RelativePath, [string]$Content = 'x')
        $path = Join-Path $Root $RelativePath
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllText($path, $Content)
    }
}

AfterAll {
    Stop-SutIsolation
}

Describe 'load-check.ps1' {
    BeforeEach {
        $script:Tree = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Write-FixtureFile $script:Tree 'lib\utils\utils.ps1' 'function Write-Status {}'
        Write-FixtureFile $script:Tree 'lib\scoop\scoop.ps1' 'function Invoke-ScoopUpdate {}'
        Write-FixtureFile $script:Tree 'lib\wsl\manager.ps1' 'function Invoke-WslCommand {}; function Set-WslConf {}; function Copy-WslDistro {}'
    }

    It 'passes when the tree defines every function' {
        { & $script:LoadCheck -Root $script:Tree } | Should -Not -Throw
    }

    It 'fails when an entry point is missing' {
        Remove-Item -LiteralPath (Join-Path $script:Tree 'lib\scoop\scoop.ps1')

        { & $script:LoadCheck -Root $script:Tree } | Should -Throw '*scoop.ps1*'
    }

    It 'fails and names a function the tree does not define' {
        Get-Command Copy-WslDistro -ErrorAction SilentlyContinue | Should -BeNullOrEmpty -Because 'the test host must not define it already'
        Write-FixtureFile $script:Tree 'lib\wsl\manager.ps1' 'function Invoke-WslCommand {}; function Set-WslConf {}'

        { & $script:LoadCheck -Root $script:Tree } | Should -Throw 'Missing function after loading: Copy-WslDistro'
    }
}
