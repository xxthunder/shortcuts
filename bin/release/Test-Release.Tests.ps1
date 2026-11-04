#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.2.0'}

<#
.SYNOPSIS
    Unit tests for Test-Release.ps1

.DESCRIPTION
    Checks the reference scanner and the load check on fixture trees in TestDrive.
#>

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    # Prevent auto-execution of main when dot-sourcing
    $env:TESTRELEASE_LIBRARY_MODE = '1'

    Start-SutIsolation
    . "$PSScriptRoot\Test-Release.ps1"

    function Write-FixtureFile {
        param([string]$Root, [string]$RelativePath, [string]$Content = 'x')
        $path = Join-Path $Root $RelativePath
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllText($path, $Content)
    }
}

AfterAll {
    Remove-Item Env:\TESTRELEASE_LIBRARY_MODE -ErrorAction SilentlyContinue
    Stop-SutIsolation
}

Describe 'Get-MissingScriptReference' {
    BeforeEach {
        $script:Tree = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Tree | Out-Null
    }

    It 'finds no problem when every reference exists' {
        Write-FixtureFile $script:Tree 'lib\u.ps1'
        Write-FixtureFile $script:Tree 'tools\t.ps1' '. "$PSScriptRoot\..\lib\u.ps1"'

        @(Get-MissingScriptReference -Root $script:Tree) | Should -BeNullOrEmpty
    }

    It 'names a missing dot-sourced file' {
        Write-FixtureFile $script:Tree 'tools\t.ps1' '. "$PSScriptRoot\..\lib\u.ps1"'

        Get-MissingScriptReference -Root $script:Tree | Should -Be @('tools\t.ps1: ..\lib\u.ps1')
    }

    It 'names a missing Join-Path target' {
        Write-FixtureFile $script:Tree 'tools\t.ps1' '$s = Join-Path $PSScriptRoot "scripts\s.sh"'

        Get-MissingScriptReference -Root $script:Tree | Should -Be @('tools\t.ps1: scripts\s.sh')
    }

    It 'names a missing file referenced from a .bat' {
        Write-FixtureFile $script:Tree 'tools\t.bat' 'pwsh -File %~dp0t.ps1 %*'

        Get-MissingScriptReference -Root $script:Tree | Should -Be @('tools\t.bat: t.ps1')
    }

    It 'skips references built from other variables' {
        Write-FixtureFile $script:Tree 'tools\t.ps1' '. "$PSScriptRoot\$name.ps1"'
        Write-FixtureFile $script:Tree 'tools\t.bat' 'call %~dp0%name%.ps1'

        @(Get-MissingScriptReference -Root $script:Tree) | Should -BeNullOrEmpty
    }
}

Describe 'Test-ReleaseLoad' {
    BeforeEach {
        $script:Tree = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Write-FixtureFile $script:Tree 'lib\utils\utils.ps1' 'function Write-Status {}'
        Write-FixtureFile $script:Tree 'lib\scoop\scoop.ps1' 'function Invoke-ScoopUpdate {}'
        Write-FixtureFile $script:Tree 'lib\wsl\manager.ps1' 'function Invoke-WslCommand {}; function Set-WslConf {}; function Copy-WslDistro {}'
    }

    It 'passes when every function is defined' {
        { Test-ReleaseLoad -Root $script:Tree } | Should -Not -Throw
    }

    It 'fails and names a function the tree does not define' {
        Write-FixtureFile $script:Tree 'lib\utils\utils.ps1' '# no functions'

        { Test-ReleaseLoad -Root $script:Tree } | Should -Throw '*Missing function after loading: Write-Status*'
    }

    It 'fails when a library throws while loading' {
        Write-FixtureFile $script:Tree 'lib\utils\utils.ps1' 'throw ''utils broke'''

        { Test-ReleaseLoad -Root $script:Tree } | Should -Throw '*does not load*utils broke*'
    }
}

Describe 'Invoke-TestReleaseMain' {
    BeforeEach {
        Mock Write-Success { }
        Mock Write-ErrorMsg { }
        Mock Get-MissingScriptReference { }
        Mock Test-ReleaseLoad { }
    }

    It 'returns 0 and reports success when the tree is complete and loads' {
        Invoke-TestReleaseMain -Path 'C:\tree' | Should -Be 0

        Should -Invoke Get-MissingScriptReference -Times 1 -ParameterFilter { $Root -eq 'C:\tree' }
        Should -Invoke Test-ReleaseLoad -Times 1 -ParameterFilter { $Root -eq 'C:\tree' }
        Should -Invoke Write-Success -Times 1 -ParameterFilter { $Message -eq 'Release tree is complete and loads: C:\tree' }
        Should -Invoke Write-ErrorMsg -Times 0
    }

    It 'returns 1 and names the parameter when -Path is missing' {
        Invoke-TestReleaseMain | Should -Be 1

        Should -Invoke Write-ErrorMsg -Times 1 -ParameterFilter { $Message -eq 'Parameter -Path is required.' }
        Should -Invoke Get-MissingScriptReference -Times 0
        Should -Invoke Test-ReleaseLoad -Times 0
    }

    It 'returns 1 and reports each missing file and the load failure' {
        Mock Get-MissingScriptReference { 'a.ps1: x.ps1', 'b.bat: y.ps1' }
        Mock Test-ReleaseLoad { throw 'The release tree does not load: z' }

        Invoke-TestReleaseMain -Path 'C:\tree' | Should -Be 1

        Should -Invoke Write-ErrorMsg -Times 1 -ParameterFilter { $Message -eq 'Missing file: a.ps1: x.ps1' }
        Should -Invoke Write-ErrorMsg -Times 1 -ParameterFilter { $Message -eq 'Missing file: b.bat: y.ps1' }
        Should -Invoke Write-ErrorMsg -Times 1 -ParameterFilter { $Message -eq 'The release tree does not load: z' }
        Should -Invoke Write-Success -Times 0
    }
}

Describe 'Script entry point' {
    # Runs the script as a program (library mode off) so the line
    # 'exit (Invoke-TestReleaseMain ...)' runs. Invoked with '&', so exit
    # returns here and sets $LASTEXITCODE instead of ending the test host.
    BeforeAll {
        $script:Tree = Join-Path $TestDrive 'entry-tree'
        Write-FixtureFile $script:Tree 'lib\utils\utils.ps1' 'function Write-Status {}'
        Write-FixtureFile $script:Tree 'lib\scoop\scoop.ps1' 'function Invoke-ScoopUpdate {}'
        Write-FixtureFile $script:Tree 'lib\wsl\manager.ps1' 'function Invoke-WslCommand {}; function Set-WslConf {}; function Copy-WslDistro {}'
    }

    AfterEach {
        $env:TESTRELEASE_LIBRARY_MODE = '1'
    }

    It 'checks the tree and exits 0' {
        Remove-Item Env:\TESTRELEASE_LIBRARY_MODE -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = -1

        $out = & "$PSScriptRoot\Test-Release.ps1" -Path $script:Tree 6>&1 | Out-String

        $LASTEXITCODE | Should -Be 0
        $out | Should -Match ([regex]::Escape("Release tree is complete and loads: $script:Tree"))
    }

    It 'exits 1 when -Path is missing' {
        Remove-Item Env:\TESTRELEASE_LIBRARY_MODE -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = -1

        $out = & "$PSScriptRoot\Test-Release.ps1" 6>&1 | Out-String

        $LASTEXITCODE | Should -Be 1
        $out | Should -Match ([regex]::Escape('Parameter -Path is required.'))
    }
}
