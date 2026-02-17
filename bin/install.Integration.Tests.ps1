#Requires -Version 5.1

<#
.SYNOPSIS
    Integration tests for bin/install.ps1 — validates post-install conditions.

.DESCRIPTION
    Smoke test assertions that run after install.ps1 completes in CI.
    Validates that Scoop, git, mandatory tools, and configuration are present.
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'UTF-8 without BOM is standard for cross-platform')]
param()

BeforeDiscovery {
    # Skip unless running in CI (these tests require a real install to have completed)
    $script:skipTests = -not (Test-Path env:CI)
}

Describe 'Post-Install: Scoop' -Tag 'Integration' -Skip:$script:skipTests {

    It 'scoop is available in PATH' {
        Get-Command scoop -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'scoop version is retrievable' {
        $version = & scoop --version 2>&1
        $LASTEXITCODE | Should -Be 0
        $version | Should -Not -BeNullOrEmpty
    }

    It 'lessmsi is installed' {
        $output = & scoop list lessmsi 2>&1 | Out-String
        $output | Should -Match 'lessmsi'
    }

    It '7zip is installed' {
        $output = & scoop list 7zip 2>&1 | Out-String
        $output | Should -Match '7zip'
    }
}

Describe 'Post-Install: Git' -Tag 'Integration' -Skip:$script:skipTests {

    It 'git is available in PATH' {
        Get-Command git -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'git version is retrievable' {
        $version = & git --version 2>&1
        $LASTEXITCODE | Should -Be 0
        $version | Should -Match 'git version'
    }
}

Describe 'Post-Install: Scoop Buckets' -Tag 'Integration' -Skip:$script:skipTests {

    It 'extras bucket is registered' {
        $buckets = & scoop bucket list 2>&1 | Out-String
        $buckets | Should -Match 'extras'
    }
}

Describe 'Post-Install: Keypirinha' -Tag 'Integration' -Skip:$script:skipTests {

    It 'keypirinha binary exists' {
        $kpPath = Join-Path $env:USERPROFILE 'scoop\apps\keypirinha\current\keypirinha.exe'
        Test-Path $kpPath | Should -BeTrue
    }

    It 'keypirinha user profile directory exists' {
        $profilePath = Join-Path $env:USERPROFILE 'scoop\apps\keypirinha\current\portable\Profile\User'
        Test-Path $profilePath | Should -BeTrue
    }
}

Describe 'Post-Install: Private Shortcuts Directory' -Tag 'Integration' -Skip:$script:skipTests {

    It 'shortcuts_private directory exists' {
        $privatePath = Join-Path $env:USERPROFILE 'shortcuts_private'
        Test-Path $privatePath | Should -BeTrue
    }
}

Describe 'Post-Install: Optional Tools Skipped in CI' -Tag 'Integration' -Skip:$script:skipTests {

    It 'vscode is NOT installed (CI auto-skips optional tools)' {
        $output = & scoop list vscode 2>&1 | Out-String
        # scoop list for a missing app will not show a matching entry
        $output | Should -Not -Match 'vscode\s+\d'
    }
}
