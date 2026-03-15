#Requires -Version 5.1

<#
.SYNOPSIS
    Integration tests for Scoop update helper functions in scoop.ps1

.DESCRIPTION
    Integration tests that verify Get-ScoopUpdatableApp and Invoke-ScoopUpdate
    work correctly with the real scoop command. The key scenario is that
    'scoop status' via Invoke-CommandLine does not crash under $ErrorActionPreference = 'Stop'.

    REQUIREMENTS:
    - Scoop must be installed
    - Internet connection required

    WARNING: These tests call real scoop commands (status, update) but do NOT update any apps.
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Integration tests use Write-Host for user feedback')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseBOMForUnicodeEncodedFile', '', Justification = 'UTF-8 without BOM is standard for cross-platform')]
param()

BeforeDiscovery {
    $script:skipTests = -not (Get-Command scoop -ErrorAction SilentlyContinue)
}

BeforeAll {
    . "$PSScriptRoot\scoop.ps1"

    # Mock console output to keep test output clean
    Mock Write-Host {}
    Mock Write-Status {}
    Mock Write-Success {}
    Mock Write-WarningMsg {}
    Mock Write-ErrorMsg {}
}

Describe 'Get-ScoopUpdatableApp - real scoop status' -Tag "Integration" -Skip:$script:skipTests {

    It 'does not throw when calling scoop status' {
        { Get-ScoopUpdatableApp } | Should -Not -Throw
    }

    It 'returns an array with correct shape' {
        $result = @(Get-ScoopUpdatableApp)

        $result.GetType().IsArray | Should -BeTrue
        foreach ($app in $result) {
            $app.Name | Should -Not -BeNullOrEmpty
            $app.InstalledVersion | Should -Not -BeNullOrEmpty
            $app.LatestVersion | Should -Not -BeNullOrEmpty
        }

        # Sanity check: if scoop status reports updates, we should find them
        $rawStatus = Invoke-CommandLine -CommandLine "scoop status" -StopAtError $false -PrintCommand $false
        if ($null -ne $rawStatus -and @($rawStatus).Count -gt 0) {
            $result.Count | Should -BeGreaterThan 0 -Because "scoop status reported updates but Get-ScoopUpdatableApp returned none"
        }
    }
}

Describe 'Invoke-ScoopUpdate - real scoop flow' -Tag "Integration" -Skip:$script:skipTests {

    BeforeAll {
        # Mock Read-Host to prevent interactive blocking (return 'A' = select all)
        Mock Read-Host { return 'A' }
        # Mock Update-ScoopApp so we don't actually update anything
        Mock Update-ScoopApp {}
    }

    It 'completes without error' {
        { Invoke-ScoopUpdate } | Should -Not -Throw
    }
}
