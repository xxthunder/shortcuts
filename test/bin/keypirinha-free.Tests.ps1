#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.DESCRIPTION
    Pester tests: no code, config, skill or agent file names Keypirinha any more (SC-086).
    Keypirinha is gone; Command Palette on Alt+Space replaced it. Docs may still say how to
    remove it, so docs are judged by review, not here. Test files are excluded, they may
    assert the absence.
#>

BeforeDiscovery {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $dirs = @('bin', 'lib', 'tools', 'config', '.claude\skills')
    $found = foreach ($dir in $dirs) {
        $full = Join-Path $repoRoot $dir
        if (Test-Path -Path $full -PathType Container) {
            Get-ChildItem -Path $full -Recurse -File |
                Where-Object { $_.Name -notlike '*.Tests.ps1' } |
                ForEach-Object FullName
        }
    }
    $single = foreach ($file in @('AGENTS.md', '.vscode\settings.json')) {
        $full = Join-Path $repoRoot $file
        if (Test-Path -Path $full -PathType Leaf) { $full }
    }
    $script:files = @(@($found) + @($single) | Where-Object { $_ } | ForEach-Object {
            [System.IO.Path]::GetRelativePath($repoRoot, $_).Replace('\', '/')
        } | Sort-Object -Unique)
    $script:repoRoot = $repoRoot
}

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

Describe 'Keypirinha-free repository' {
    It 'Should not name Keypirinha in <_>' -ForEach $script:files {
        $content = Get-Content -Raw -Path (Join-Path $script:repoRoot $_)
        $content | Should -Not -Match '(?i)keypirinha'
    }
}
