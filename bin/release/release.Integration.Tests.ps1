#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.2.0'}

<#
.SYNOPSIS
    Integration tests for the release build

.DESCRIPTION
    Builds the release tree from this repository and checks that it loads.
#>

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
}

AfterAll {
    Stop-SutIsolation
}

Describe 'Release tree' {
    It 'builds a tree from this repository that loads' {
        $pwsh = (Get-Process -Id $PID).Path
        $tree = Join-Path $TestDrive 'tree'

        & $pwsh -NoProfile -File "$PSScriptRoot\Build-Release.ps1" -Destination $tree
        $LASTEXITCODE | Should -Be 0

        & $pwsh -NoProfile -File "$PSScriptRoot\Test-Release.ps1" -Path $tree
        $LASTEXITCODE | Should -Be 0

        Join-Path $tree 'lib\wsl\scripts\setup-ca.sh' | Should -Exist
        Join-Path $tree 'tools\proxy\px-proxy.bat' | Should -Exist
        Join-Path $tree 'README.md' | Should -Exist
        @(Get-ChildItem -LiteralPath $tree -Recurse -File -Filter '*.Tests.ps1') | Should -BeNullOrEmpty
        Join-Path $tree 'lib\AGENTS.md' | Should -Not -Exist
    }
}
