#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.DESCRIPTION
    Pester tests for the Keypirinha profile that bin/install.ps1 copies over the installed one:
    Keypirinha opens with Alt+Space, and every catalog-refresh hint a script prints names the
    hotkey the profile sets (SC-069). The test lives next to the installer, not next to the
    profile, because the test runner searches tools, test, bin and lib.
#>

BeforeDiscovery {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $searchPaths = @('bin', 'lib', 'tools') | ForEach-Object { Join-Path $repoRoot $_ }
    $script:hintFiles = @(Get-ChildItem -Path $searchPaths -Filter '*.ps1' -Recurse |
            Where-Object { $_.Name -notlike '*.Tests.ps1' } |
            Where-Object { Select-String -Path $_.FullName -SimpleMatch "and type 'Refresh catalog'" -Quiet } |
            ForEach-Object { [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName) })
}

BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
    $iniPath = Join-Path $script:repoRoot 'config\keypirinha\portable\Profile\User\Keypirinha.ini'
    $script:hotkey = (Select-String -Path $iniPath -Pattern '^hotkey_run\s*=\s*(\S+)').Matches[0].Groups[1].Value
}

Describe 'Keypirinha profile' {
    It 'Should open Keypirinha with Alt+Space' {
        $script:hotkey | Should -BeExactly 'Alt+Space'
    }

    It 'Should name the profile hotkey in the catalog-refresh hint of <_>' -ForEach $script:hintFiles {
        $hint = Select-String -Path (Join-Path $script:repoRoot $_) -Pattern "Press (\S+) and type 'Refresh catalog'"
        $hint.Matches.ForEach({ $_.Groups[1].Value }) | Sort-Object -Unique -CaseSensitive |
            Should -BeExactly $script:hotkey
    }
}
