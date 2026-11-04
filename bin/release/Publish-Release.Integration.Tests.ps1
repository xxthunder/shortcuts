#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.2.0'}

<#
.SYNOPSIS
    Integration tests for Publish-Release.ps1

.DESCRIPTION
    Runs real git against a bare repository ('origin') and a clone in TestDrive.
#>

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    # Prevent auto-execution of main when dot-sourcing
    $env:PUBLISHRELEASE_LIBRARY_MODE = '1'

    Start-SutIsolation
    . "$PSScriptRoot\Publish-Release.ps1"

    function Invoke-TestGit {
        param([string]$Path, [string[]]$GitArgument)
        $output = & git -C $Path @GitArgument 2>&1
        if ($LASTEXITCODE -ne 0) { throw "git $GitArgument failed: $output" }
        return $output
    }

    function Initialize-TestClone {
        param([string]$Origin, [string]$Path, [string[]]$CloneArgument = @())
        & git clone @CloneArgument $Origin $Path *>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git clone $Origin failed" }
        Invoke-TestGit $Path @('config', 'user.name', 'Test') | Out-Null
        Invoke-TestGit $Path @('config', 'user.email', 'test@example.com') | Out-Null
    }

    function Add-DevelopCommit {
        param([string]$Path, [string]$Name)
        Write-TreeFile $Path "$Name.txt" $Name
        Invoke-TestGit $Path @('add', '-A') | Out-Null
        Invoke-TestGit $Path @('commit', '-m', $Name) | Out-Null
        return "$(Invoke-TestGit $Path @('rev-parse', 'HEAD') | Select-Object -First 1)".Trim()
    }

    function Write-TreeFile {
        param([string]$Root, [string]$RelativePath, [string]$Content = 'x')
        $path = Join-Path $Root $RelativePath
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllText($path, $Content)
    }
}

AfterAll {
    Remove-Item Env:\PUBLISHRELEASE_LIBRARY_MODE -ErrorAction SilentlyContinue
    Stop-SutIsolation
}

Describe 'Publish-ReleaseTree' {
    BeforeEach {
        $base = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:Origin = Join-Path $base 'origin.git'
        $script:Clone = Join-Path $base 'clone'
        $script:Tree = Join-Path $base 'tree'
        New-Item -ItemType Directory -Path $base | Out-Null

        & git init --bare --initial-branch=develop $script:Origin *>&1 | Out-Null
        & git clone $script:Origin $script:Clone *>&1 | Out-Null
        Invoke-TestGit $script:Clone @('config', 'user.name', 'Test') | Out-Null
        Invoke-TestGit $script:Clone @('config', 'user.email', 'test@example.com') | Out-Null
        Write-TreeFile $script:Clone 'source.txt'
        Invoke-TestGit $script:Clone @('add', '-A') | Out-Null
        Invoke-TestGit $script:Clone @('commit', '-m', 'develop commit') | Out-Null
        Invoke-TestGit $script:Clone @('push', 'origin', 'HEAD:develop') | Out-Null

        Write-TreeFile $script:Tree 'README.md' 'readme'
        Write-TreeFile $script:Tree 'lib\old.ps1' 'old'
        Write-TreeFile $script:Tree '.gitattributes' '* text=auto'
    }

    It 'creates release as an orphan branch on the first run' {
        $result = Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123'

        $result | Should -BeTrue
        $parents = Invoke-TestGit $script:Origin @('log', 'release', '--format=%P')
        @($parents).Count | Should -Be 1
        "$($parents | Select-Object -First 1)".Trim() | Should -BeNullOrEmpty
        $developSha = (Invoke-TestGit $script:Origin @('rev-parse', 'develop')) | Select-Object -First 1
        @(Invoke-TestGit $script:Origin @('rev-list', 'release')) | Should -Not -Contain $developSha
        $files = Invoke-TestGit $script:Origin @('ls-tree', '-r', '--name-only', 'release')
        $files | Should -Contain '.gitattributes'
        $files | Should -Contain 'README.md'
        $files | Should -Not -Contain 'source.txt'
    }

    It 'names the source commit in the message' {
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' | Out-Null

        $subject = Invoke-TestGit $script:Origin @('log', '-1', '--format=%s', 'release')
        $subject | Should -Be 'release: build from abc123'
    }

    It 'makes no commit when the tree did not change' {
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' | Out-Null

        $result = Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'def456'

        $result | Should -BeFalse
        Invoke-TestGit $script:Origin @('rev-list', '--count', 'release') | Should -Be '1'
    }

    It 'removes a file that the new tree no longer has' {
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' | Out-Null
        Remove-Item -LiteralPath (Join-Path $script:Tree 'lib\old.ps1')

        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'def456' | Should -BeTrue

        $files = Invoke-TestGit $script:Origin @('ls-tree', '-r', '--name-only', 'release')
        $files | Should -Not -Contain 'lib/old.ps1'
        $files | Should -Contain 'README.md'
    }

    It 'adds the new commit on top of the existing branch' {
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' | Out-Null
        $first = (Invoke-TestGit $script:Origin @('rev-parse', 'release')) | Select-Object -First 1
        Write-TreeFile $script:Tree 'README.md' 'changed'

        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'def456' | Should -BeTrue

        Invoke-TestGit $script:Origin @('rev-list', '--count', 'release') | Should -Be '2'
        $parent = (Invoke-TestGit $script:Origin @('log', '-1', '--format=%P', 'release')) | Select-Object -First 1
        "$parent".Trim() | Should -Be "$first".Trim()
    }

    It 'does not push with -NoPush' {
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' -NoPush | Should -BeTrue

        & git -C $script:Origin rev-parse --verify --quiet release 2>&1 | Out-Null
        $LASTEXITCODE | Should -Not -Be 0
        Invoke-TestGit $script:Clone @('rev-list', '--count', 'release') | Should -Be '1'
    }

    It 'leaves no worktree behind' {
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' | Out-Null

        @(Invoke-TestGit $script:Clone @('worktree', 'list')).Count | Should -Be 1
    }

    It 'leaves no worktree behind when the push fails' {
        Invoke-TestGit $script:Clone @('remote', 'set-url', '--push', 'origin', (Join-Path $TestDrive 'does-not-exist.git')) | Out-Null

        { Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' } | Should -Throw

        @(Invoke-TestGit $script:Clone @('worktree', 'list')).Count | Should -Be 1
    }

    It 'takes the branch from a clone whose fetch config leaves it out' {
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' | Out-Null
        $narrow = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Initialize-TestClone $script:Origin $narrow @('--single-branch', '--branch', 'develop')
        Write-TreeFile $script:Tree 'README.md' 'changed'

        Publish-ReleaseTree -RepoPath $narrow -TreePath $script:Tree -SourceCommit 'def456' | Should -BeTrue

        Invoke-TestGit $script:Origin @('rev-list', '--count', 'release') | Should -Be '2'
    }

    It 'fails when the remote cannot be reached' {
        Invoke-TestGit $script:Clone @('remote', 'set-url', 'origin', (Join-Path $TestDrive 'does-not-exist.git')) | Out-Null

        { Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' } | Should -Throw '*ls-remote*'
    }

    It 'adds to release from a fresh clone that has no local release branch' {
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' | Out-Null
        $first = (Invoke-TestGit $script:Origin @('rev-parse', 'release')) | Select-Object -First 1
        $fresh = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Initialize-TestClone $script:Origin $fresh
        Write-TreeFile $script:Tree 'tools\new.txt' 'new'

        Publish-ReleaseTree -RepoPath $fresh -TreePath $script:Tree -SourceCommit 'def456' | Should -BeTrue

        Invoke-TestGit $script:Origin @('rev-list', '--count', 'release') | Should -Be '2'
        $parent = (Invoke-TestGit $script:Origin @('log', '-1', '--format=%P', 'release')) | Select-Object -First 1
        "$parent".Trim() | Should -Be "$first".Trim()
        Invoke-TestGit $script:Origin @('ls-tree', '-r', '--name-only', 'release') | Should -Contain 'tools/new.txt'
    }

    Context 'with source commits on develop' {
        BeforeEach {
            $script:Older = Add-DevelopCommit $script:Clone 'older'
            $script:Newer = Add-DevelopCommit $script:Clone 'newer'
        }

        It 'makes no commit for a source commit <Case> the one on release' -TestCases @(
            @{ Case = 'older than'; UseOlder = $true }
            @{ Case = 'equal to'; UseOlder = $false }
        ) {
            param($UseOlder)
            Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit $script:Newer | Out-Null
            Write-TreeFile $script:Tree 'README.md' 'changed'
            $source = if ($UseOlder) { $script:Older } else { $script:Newer }

            Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit $source | Should -BeFalse

            Invoke-TestGit $script:Origin @('rev-list', '--count', 'release') | Should -Be '1'
            Invoke-TestGit $script:Origin @('log', '-1', '--format=%s', 'release') | Should -Be "release: build from $script:Newer"
        }

        It 'commits a source commit newer than the one on release' {
            Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit $script:Older | Out-Null
            Write-TreeFile $script:Tree 'README.md' 'changed'

            Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit $script:Newer | Should -BeTrue

            Invoke-TestGit $script:Origin @('rev-list', '--count', 'release') | Should -Be '2'
            Invoke-TestGit $script:Origin @('log', '-1', '--format=%s', 'release') | Should -Be "release: build from $script:Newer"
        }

        It 'commits when the source commit of release is unknown here' {
            Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit ('0' * 40) | Out-Null
            Write-TreeFile $script:Tree 'README.md' 'changed'

            Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit $script:Older | Should -BeTrue
        }
    }

    It 'lets a fork take release with git subtree and pull the next update' {
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'abc123' | Out-Null
        $fork = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        & git init --initial-branch=main $fork *>&1 | Out-Null
        Invoke-TestGit $fork @('config', 'user.name', 'Test') | Out-Null
        Invoke-TestGit $fork @('config', 'user.email', 'test@example.com') | Out-Null
        Write-TreeFile $fork 'fork.txt' 'fork'
        Invoke-TestGit $fork @('add', '-A') | Out-Null
        Invoke-TestGit $fork @('commit', '-m', 'fork commit') | Out-Null
        Invoke-TestGit $fork @('subtree', 'add', '--prefix=vendor/x', '--squash', '-m', 'vendor x', $script:Origin, 'release') | Out-Null
        Test-Path -LiteralPath (Join-Path $fork 'vendor\x\README.md') | Should -BeTrue
        Write-TreeFile $script:Tree 'tools\new.txt' 'new'
        Publish-ReleaseTree -RepoPath $script:Clone -TreePath $script:Tree -SourceCommit 'def456' | Out-Null

        Invoke-TestGit $fork @('subtree', 'pull', '--prefix=vendor/x', '--squash', '-m', 'update x', $script:Origin, 'release') | Out-Null

        Test-Path -LiteralPath (Join-Path $fork 'vendor\x\tools\new.txt') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $fork 'fork.txt') | Should -BeTrue
    }
}
