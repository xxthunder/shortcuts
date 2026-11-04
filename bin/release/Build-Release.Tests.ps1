#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.2.0'}

<#
.SYNOPSIS
    Unit tests for Build-Release.ps1

.DESCRIPTION
    Builds the release tree from an allow-list. Every test works on a fixture
    tree in TestDrive.
#>

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    # Prevent auto-execution of main when dot-sourcing
    $env:BUILDRELEASE_LIBRARY_MODE = '1'

    Start-SutIsolation
    . "$PSScriptRoot\Build-Release.ps1"

    function Write-FixtureFile {
        param([string]$Root, [string]$RelativePath, [string]$Content = 'x')
        $path = Join-Path $Root $RelativePath
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        Set-Content -LiteralPath $path -Value $Content -NoNewline
    }

    function Write-FixtureList {
        param([string]$Root, [string]$Text)
        $path = Join-Path $Root 'paths.txt'
        [System.IO.File]::WriteAllText($path, $Text)
        $path
    }
}

AfterAll {
    Remove-Item Env:\BUILDRELEASE_LIBRARY_MODE -ErrorAction SilentlyContinue
    Stop-SutIsolation
}

Describe 'Get-ReleasePath' {
    BeforeEach {
        $script:Src = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Src | Out-Null
    }

    It 'takes a listed file' {
        Write-FixtureFile $script:Src 'LICENSE'
        Write-FixtureFile $script:Src 'other.txt'
        $list = Write-FixtureList $script:Src "LICENSE`n"

        Get-ReleasePath -ListPath $list -SourceRoot $script:Src | Should -Be @('LICENSE')
    }

    It 'takes a listed folder recursively' {
        Write-FixtureFile $script:Src 'lib/a.ps1'
        Write-FixtureFile $script:Src 'lib/wsl/scripts/b.sh'
        $list = Write-FixtureList $script:Src "lib/`n"

        Get-ReleasePath -ListPath $list -SourceRoot $script:Src |
            Should -Be @('lib\a.ps1', 'lib\wsl\scripts\b.sh')
    }

    It 'leaves out files matching an exclusion by name' {
        Write-FixtureFile $script:Src 'lib/a.ps1'
        Write-FixtureFile $script:Src 'lib/a.Tests.ps1'
        Write-FixtureFile $script:Src 'lib/a.Integration.Tests.ps1'
        $list = Write-FixtureList $script:Src "lib/`n!*.Tests.ps1`n"

        Get-ReleasePath -ListPath $list -SourceRoot $script:Src | Should -Be @('lib\a.ps1')
    }

    It 'leaves out a file matching an exclusion by path' {
        Write-FixtureFile $script:Src 'lib/AGENTS.md'
        Write-FixtureFile $script:Src 'lib/wsl/AGENTS.md'
        $list = Write-FixtureList $script:Src "lib/`n!lib/AGENTS.md`n"

        Get-ReleasePath -ListPath $list -SourceRoot $script:Src | Should -Be @('lib\wsl\AGENTS.md')
    }

    It 'ignores comments, blank lines and CRLF' {
        Write-FixtureFile $script:Src 'LICENSE'
        Write-FixtureFile $script:Src 'lib/a.ps1'
        $list = Write-FixtureList $script:Src "# x`r`n`r`nLICENSE`r`n`r`n# y`r`nlib/`r`n"

        Get-ReleasePath -ListPath $list -SourceRoot $script:Src | Should -Be @('LICENSE', 'lib\a.ps1')
    }

    It 'fails and names a listed folder that does not exist' {
        $list = Write-FixtureList $script:Src "missing/`n"

        { Get-ReleasePath -ListPath $list -SourceRoot $script:Src } |
            Should -Throw 'Listed path does not exist: missing/'
    }

    It 'fails and names a listed file that does not exist' {
        $list = Write-FixtureList $script:Src "MISSING.txt`n"

        { Get-ReleasePath -ListPath $list -SourceRoot $script:Src } |
            Should -Throw 'Listed path does not exist: MISSING.txt'
    }
}

Describe 'Copy-ReleaseTree' {
    BeforeEach {
        $script:Src = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:Dest = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:Src, $script:Dest | Out-Null
        Write-FixtureFile $script:Src 'lib/wsl/scripts/b.sh' 'echo hi'
        Write-FixtureFile $script:Src 'release-readme.md' '# Release'
        $script:List = Write-FixtureList $script:Src "lib/`n"
        $script:Readme = Join-Path $script:Src 'release-readme.md'
    }

    It 'copies the files to the same relative paths' {
        Copy-ReleaseTree -SourceRoot $script:Src -Destination $script:Dest -ListPath $script:List -ReadmePath $script:Readme | Out-Null

        $copy = Join-Path $script:Dest 'lib\wsl\scripts\b.sh'
        Test-Path -LiteralPath $copy | Should -BeTrue
        Get-Content -LiteralPath $copy -Raw | Should -Be 'echo hi'
    }

    It 'writes the release README at the root' {
        Copy-ReleaseTree -SourceRoot $script:Src -Destination $script:Dest -ListPath $script:List -ReadmePath $script:Readme | Out-Null

        Get-Content -LiteralPath (Join-Path $script:Dest 'README.md') -Raw |
            Should -Be (Get-Content -LiteralPath $script:Readme -Raw)
    }

    It 'fails when the destination is not empty' {
        Write-FixtureFile $script:Dest 'stale.txt'

        { Copy-ReleaseTree -SourceRoot $script:Src -Destination $script:Dest -ListPath $script:List -ReadmePath $script:Readme } |
            Should -Throw
    }
}

Describe 'Invoke-BuildReleaseMain' {
    BeforeEach {
        Mock Write-Status { }
        Mock Write-Success { }
        Mock Write-ErrorMsg { }
        $script:Dest = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
    }

    It 'builds the tree from paths.txt and the release README, and returns 0' {
        Mock Copy-ReleaseTree { 3 }

        Invoke-BuildReleaseMain -SourceRoot 'C:\src' -Destination $script:Dest | Should -Be 0

        Should -Invoke Copy-ReleaseTree -Times 1 -ParameterFilter {
            $SourceRoot -eq 'C:\src' -and $Destination -eq $script:Dest -and
            $ListPath -eq (Join-Path $PSScriptRoot 'paths.txt') -and
            $ReadmePath -eq (Join-Path $PSScriptRoot 'README.md')
        }
        Should -Invoke Write-Success -Times 1 -ParameterFilter { $Message -eq 'Release tree built: 3 files' }
    }

    It 'returns 1 and names the parameter when -Destination is missing' {
        Mock Copy-ReleaseTree { }

        Invoke-BuildReleaseMain -SourceRoot 'C:\src' | Should -Be 1

        Should -Invoke Write-ErrorMsg -Times 1 -ParameterFilter { $Message -eq 'Parameter -Destination is required.' }
        Should -Invoke Copy-ReleaseTree -Times 0
    }

    It 'returns 1 and reports the error when the build fails' {
        Mock Copy-ReleaseTree { throw 'Destination is not empty: X' }

        Invoke-BuildReleaseMain -SourceRoot 'C:\src' -Destination $script:Dest | Should -Be 1

        Should -Invoke Write-ErrorMsg -Times 1 -ParameterFilter { $Message -eq 'Destination is not empty: X' }
        Should -Invoke Write-Success -Times 0
    }
}

Describe 'Script entry point' {
    # Runs the script as a program (library mode off) so the line
    # 'exit (Invoke-BuildReleaseMain ...)' runs. Invoked with '&', so exit
    # returns here and sets $LASTEXITCODE instead of ending the test host.
    BeforeAll {
        # A source tree with one file for every entry of the real allow-list.
        $script:Src = Join-Path $TestDrive 'entry-src'
        $entries = Get-Content -LiteralPath "$PSScriptRoot\paths.txt" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#') -and -not $_.StartsWith('!') }
        foreach ($entry in $entries) {
            if ($entry.EndsWith('/')) { Write-FixtureFile $script:Src ($entry + 'file.txt') }
            else { Write-FixtureFile $script:Src $entry }
        }
    }

    AfterEach {
        $env:BUILDRELEASE_LIBRARY_MODE = '1'
    }

    It 'builds the tree and exits 0' {
        $dest = Join-Path $TestDrive 'entry-dest'
        Remove-Item Env:\BUILDRELEASE_LIBRARY_MODE -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = -1

        $out = & "$PSScriptRoot\Build-Release.ps1" -SourceRoot $script:Src -Destination $dest 6>&1 | Out-String

        $LASTEXITCODE | Should -Be 0
        $out | Should -Match 'Release tree built: \d+ files'
        Join-Path $dest 'README.md' | Should -Exist
        Join-Path $dest 'lib\file.txt' | Should -Exist
    }

    It 'exits 1 when -Destination is missing' {
        Remove-Item Env:\BUILDRELEASE_LIBRARY_MODE -ErrorAction SilentlyContinue
        $global:LASTEXITCODE = -1

        $out = & "$PSScriptRoot\Build-Release.ps1" -SourceRoot $script:Src 6>&1 | Out-String

        $LASTEXITCODE | Should -Be 1
        $out | Should -Match ([regex]::Escape('Parameter -Destination is required.'))
    }
}
