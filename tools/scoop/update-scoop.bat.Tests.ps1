#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Unit tests for the update-scoop.bat wrapper.

.DESCRIPTION
    A .bat runs only on Windows, so these tests read the wrapper's command line
    and check how it launches the helper: detached, in conhost.exe, under
    Windows PowerShell 5.1, with the user profile loaded (ADR-0001).
#>

BeforeAll {
    # The wrapper's commands, without the echo switch and the REM comments.
    $script:commandLines = @(
        Get-Content -LiteralPath (Join-Path $PSScriptRoot 'update-scoop.bat') |
            Where-Object { $_ -notmatch '^\s*(@echo\s+off|REM\b|$)' }
    )
    $script:commandLine = $script:commandLines -join "`n"
}

Describe 'update-scoop.bat' {
    <#
    @need test: update-scoop.bat.runs a single command
    :id: TEST_SCOOP_CONSOLE_SINGLE_COMMAND
    :tests: REQ_SCOOP_CONSOLE
    @endneed
    #>
    It 'runs a single command' {
        $script:commandLines.Count | Should -Be 1
    }

    <#
    @need test: update-scoop.bat.starts detached in conhost.exe under powershell.exe
    :id: TEST_SCOOP_CONSOLE_DETACHED_CONHOST_POWERSHELL
    :tests: REQ_SCOOP_CONSOLE
    @endneed
    #>
    It 'starts detached in conhost.exe under powershell.exe' {
        $script:commandLine | Should -Match '^start\s+"[^"]*"\s+conhost\.exe\s+powershell\.exe\s'
    }

    <#
    @need test: update-scoop.bat.does not run pwsh
    :id: TEST_SCOOP_CONSOLE_NOT_PWSH
    :tests: REQ_SCOOP_CONSOLE
    @endneed
    #>
    It 'does not run pwsh' {
        $script:commandLine | Should -Not -Match '\bpwsh\b'
    }

    <#
    @need test: update-scoop.bat.runs update-scoop.ps1 from its own directory with -File and passes its arguments
    :id: TEST_SCOOP_CONSOLE_RUNS_SCRIPT_WITH_ARGUMENTS
    :tests: REQ_SCOOP_CONSOLE
    @endneed
    #>
    It 'runs update-scoop.ps1 from its own directory with -File and passes its arguments' {
        $script:commandLine | Should -Match '\s-File\s+"%~dp0update-scoop\.ps1"\s+%\*\s*$'
    }

    <#
    @need test: update-scoop.bat.loads the user profile
    :id: TEST_SCOOP_CONSOLE_LOADS_PROFILE
    :tests: REQ_SCOOP_CONSOLE
    @endneed
    #>
    It 'loads the user profile' {
        $script:commandLine | Should -Not -Match '-NoProfile'
    }
}
