#Requires -Version 5.1

<#
.SYNOPSIS
    Integration tests for bin/install.ps1 — validates post-install conditions.

.DESCRIPTION
    Smoke test assertions that run after install.ps1 completes.
    Validates that Scoop, git, mandatory tools, and configuration are present.
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'UTF-8 without BOM is standard for cross-platform')]
param()

Describe 'Post-Install: Scoop' -Tag 'Integration' {

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

Describe 'Post-Install: Git' -Tag 'Integration' {

    It 'git is available in PATH' {
        Get-Command git -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'git version is retrievable' {
        $version = & git --version 2>&1
        $LASTEXITCODE | Should -Be 0
        $version | Should -Match 'git version'
    }
}

Describe 'Post-Install: Scoop Buckets' -Tag 'Integration' {

    It 'extras bucket is registered' {
        $buckets = & scoop bucket list 2>&1 | Out-String
        $buckets | Should -Match 'extras'
    }
}

Describe 'Post-Install: Keypirinha' -Tag 'Integration' {

    It 'keypirinha binary exists' {
        $kpPath = Join-Path $env:USERPROFILE 'scoop\apps\keypirinha\current\keypirinha.exe'
        Test-Path $kpPath | Should -BeTrue
    }

    It 'keypirinha user profile directory exists' {
        $profilePath = Join-Path $env:USERPROFILE 'scoop\apps\keypirinha\current\portable\Profile\User'
        Test-Path $profilePath | Should -BeTrue
    }
}

Describe 'Post-Install: Private Shortcuts Directory' -Tag 'Integration' {

    It 'shortcuts_private directory exists' {
        $privatePath = Join-Path $env:USERPROFILE 'shortcuts_private'
        Test-Path $privatePath | Should -BeTrue
    }
}
