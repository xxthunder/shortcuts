#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.DESCRIPTION
    Pester tests for docs/architecture/workspace.dsl: the architecture model names every
    WSL Manager module and distribution script and defines the agreed views (SC-062).
    A new module in lib/wsl fails this test until it is modelled. The test lives here, not
    next to the model, because the test runner searches tools, test, bin and lib.
#>

BeforeDiscovery {
    $wslDir = Join-Path $PSScriptRoot '..\..\lib\wsl'
    $script:modules = @(Get-ChildItem -Path $wslDir -Filter '*.ps1' | Where-Object { $_.Name -notlike '*.Tests.ps1' } | ForEach-Object Name)
    $script:scripts = @(Get-ChildItem -Path (Join-Path $wslDir 'scripts') -Filter '*.sh' | ForEach-Object Name)
    $script:views = @('SystemContext', 'Containers', 'WslManager-Overview', 'WslManager-ManageDistributions',
        'WslManager-PrepareDistribution', 'WslManager-ConfigureWsl', 'DistributionScripts')
}

BeforeAll {
    $script:dsl = Get-Content -Raw -Path (Join-Path $PSScriptRoot '..\..\docs\architecture\workspace.dsl')
    # A file name counts only on its own and in its own case: bin/install.ps1 does not name
    # install.ps1, px-proxy.ps1 and setProxy.ps1 do not name proxy.ps1
    $script:fileNamePattern = '(?<![\w/.-]){0}\b'
}

Describe 'Architecture model' {
    It 'Should name the WSL Manager module <_>' -ForEach $script:modules {
        $script:dsl | Should -MatchExactly ($script:fileNamePattern -f [regex]::Escape($_))
    }

    It 'Should name the distribution script <_>' -ForEach $script:scripts {
        $script:dsl | Should -MatchExactly ($script:fileNamePattern -f [regex]::Escape($_))
    }

    It 'Should name the shared utilities utils.ps1' {
        $script:dsl | Should -Match 'utils\.ps1'
    }

    It 'Should define the view <_>' -ForEach $script:views {
        $script:dsl | Should -Match ('"' + [regex]::Escape($_) + '"')
    }
}
