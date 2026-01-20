<#
.SYNOPSIS
    Installs git hooks for the repository.

.DESCRIPTION
    Copies hooks from tools/githooks to .git/hooks.
    Currently installs:
    - pre-commit
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Join-Path $PSScriptRoot "..\.."
$gitHooksDir = Join-Path $repoRoot ".git\hooks"
$sourceDir = $PSScriptRoot

if (-not (Test-Path $gitHooksDir)) {
    Write-Warning "Git hooks directory not found at $gitHooksDir"
    Write-Warning "Is this a git repository?"
    exit 1
}

$hooks = @("pre-commit")

foreach ($hook in $hooks) {
    $sourcePath = Join-Path $sourceDir $hook
    $destPath = Join-Path $gitHooksDir $hook

    if (Test-Path $sourcePath) {
        Write-Information "Installing $hook hook... " -Tags "Status"
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        Write-Information "Done." -Tags "Success"
    } else {
        Write-Error "Source hook not found: $sourcePath"
    }
}

Write-Information "Git hooks installed successfully." -Tags "Success"
