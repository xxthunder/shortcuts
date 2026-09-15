<#
.DESCRIPTION
    Test isolation helpers for Pester tests.
    Prevents cross-file function leakage when dot-sourcing libraries, and keeps unit
    tests hermetic by shimming wsl.exe so an unmocked call fails loudly instead of
    depending on which distributions the machine happens to have (SC-054).
    This file is meant to be dot-sourced in BeforeAll blocks.

    Usage:
        BeforeAll {
            . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
            Start-SutIsolation
            . "$PSScriptRoot\module.ps1"
        }

        AfterAll {
            Stop-SutIsolation
        }
#>

function Test-IntegrationTestCaller {
    <#
    .SYNOPSIS
        Returns $true when the nearest test file on the call stack is an integration test.

    .DESCRIPTION
        Unit and integration files run in the same process (CI runs both in one
        testrunner call), so the wsl.exe shim has to be decided per file: the nearest
        *.Tests.ps1 frame on the call stack is the file that called Start-SutIsolation.
    #>
    [CmdletBinding()]
    param()

    $callerFile = (Get-PSCallStack | Where-Object { $_.ScriptName -like '*.Tests.ps1' } | Select-Object -First 1).ScriptName
    return $callerFile -like '*.Integration.Tests.ps1'
}

function Enable-WslShim {
    <#
    .SYNOPSIS
        Shadows wsl.exe (and wsl) with a function that throws.

    .DESCRIPTION
        A global function named wsl.exe takes precedence over the application for
        "wsl.exe ..." calls; the wsl alias covers "wsl ..." calls. Pester's Mock wsl
        resolves the alias to the function, so existing mocks keep working and the
        shim only fires for calls nobody mocked.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Changes in-process command resolution only, no system changes')]
    [CmdletBinding()]
    param()

    function global:wsl.exe {
        throw "Unit test reached the real wsl.exe ($($args -join ' ')). Mock the function that calls it (see SC-054)."
    }
    Set-Alias -Name wsl -Value wsl.exe -Scope Global
    $script:_wslShimInstalled = $true
}

function Disable-WslShim {
    <#
    .SYNOPSIS
        Removes the wsl.exe shim installed by Enable-WslShim, if any.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Restores in-process command resolution only, no system changes')]
    [CmdletBinding()]
    param()

    if ($script:_wslShimInstalled) {
        Remove-Item 'Function:\wsl.exe' -ErrorAction SilentlyContinue
        Remove-Item 'Alias:\wsl' -ErrorAction SilentlyContinue
        $script:_wslShimInstalled = $false
    }
}

function Start-SutIsolation {
    <#
    .SYNOPSIS
        Snapshots current functions before dot-sourcing scripts under test and shims
        wsl.exe for unit test files.

    .DESCRIPTION
        Call this BEFORE dot-sourcing any library scripts. It records which
        functions exist so that Stop-SutIsolation can clean up the ones that were added.
        When called from a unit test file (anything but *.Integration.Tests.ps1) it also
        installs the wsl.exe shim, so a test that reaches the real wsl.exe fails with a
        message naming the call instead of depending on the machine's distributions.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Snapshots in-process state only, no system changes')]
    [CmdletBinding()]
    param()

    $script:_existingFunctions = @(Get-ChildItem Function:).Name
    $script:_wslShimInstalled = $false

    if (-not (Test-IntegrationTestCaller)) {
        Enable-WslShim
    }
}

function Stop-SutIsolation {
    <#
    .SYNOPSIS
        Removes functions added after Start-SutIsolation to prevent cross-file test leakage.

    .DESCRIPTION
        Compares current functions against the snapshot taken by Start-SutIsolation
        and removes any that were added by dot-sourcing.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Cleans up in-process test state only, no system changes')]
    [CmdletBinding()]
    param()

    Disable-WslShim

    if ($null -ne $script:_existingFunctions) {
        $addedFunctions = @(Get-ChildItem Function:).Name |
            Where-Object { $_ -notin $script:_existingFunctions }
        $addedFunctions | ForEach-Object {
            Remove-Item "Function:\$_" -ErrorAction SilentlyContinue
        }
    }
}
