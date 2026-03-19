<#
.DESCRIPTION
    Test isolation helpers for Pester tests.
    Prevents cross-file function leakage when dot-sourcing libraries.
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

function Start-SutIsolation {
    <#
    .SYNOPSIS
        Snapshots current functions before dot-sourcing scripts under test.

    .DESCRIPTION
        Call this BEFORE dot-sourcing any library scripts. It records which
        functions exist so that Stop-SutIsolation can clean up the ones that were added.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Snapshots in-process state only, no system changes')]
    [CmdletBinding()]
    param()

    $script:_existingFunctions = @(Get-ChildItem Function:).Name
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

    if ($null -ne $script:_existingFunctions) {
        $addedFunctions = @(Get-ChildItem Function:).Name |
            Where-Object { $_ -notin $script:_existingFunctions }
        $addedFunctions | ForEach-Object {
            Remove-Item "Function:\$_" -ErrorAction SilentlyContinue
        }
    }
}
