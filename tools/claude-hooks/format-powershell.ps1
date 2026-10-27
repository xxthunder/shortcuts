#Requires -Version 7.4

<#
.SYNOPSIS
    Claude Code PostToolUse hook: formats and lints a PowerShell file after Claude edits it.

.DESCRIPTION
    Reads the hook input as JSON on stdin and takes the file from tool_input.file_path.
    A .ps1, .psm1 or .psd1 file is formatted with Invoke-Formatter and written back as
    UTF-8 with BOM and CRLF line endings. It is then linted with Invoke-ScriptAnalyzer.
    Both read PSScriptAnalyzerSettings.psd1 at the repository root.

    Exit codes follow the Claude Code hook contract:
    - 0: not a PowerShell file, or formatted and lint-clean; no output
    - 2: lint findings remain, or the file is not valid UTF-8 and is left as it is; the
         message goes to stderr, and Claude Code hands it to Claude
    - 1: the hook itself failed; the error goes to stderr and is shown to the user

    Under WSL, the Windows directories on PATH (/mnt/...) are dropped first. PSScriptAnalyzer
    resolves commands, and scanning those directories takes about 50 seconds per run.

    Dot-sourcing the script defines Invoke-FormatPowerShellHook and runs nothing, so the
    tests can call it in-process. Piping the hook input into the script runs it as
    Claude Code does, also in-process.

.NOTES
    Wired up in .claude/settings.json (SC-083).
#>

function Invoke-FormatPowerShellHook {
    <#
    .SYNOPSIS
        Formats and lints the file named in the hook input; returns the exit code and the message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$HookInput,

        [string]$SettingsPath = (Join-Path $PSScriptRoot '..\..\PSScriptAnalyzerSettings.psd1')
    )

    $ErrorActionPreference = 'Stop'
    $powerShellExtensions = @('.ps1', '.psm1', '.psd1')

    try {
        $hookData = if ($HookInput.Trim()) { $HookInput | ConvertFrom-Json -AsHashtable }
        $toolInput = if ($hookData) { $hookData['tool_input'] }
        $filePath = if ($toolInput) { $toolInput['file_path'] }

        if (-not $filePath -or
            [System.IO.Path]::GetExtension($filePath) -notin $powerShellExtensions -or
            -not (Test-Path -Path $filePath -PathType Leaf)) {
            return [PSCustomObject]@{ ExitCode = 0; Message = '' }
        }

        Import-Module PSScriptAnalyzer -MinimumVersion 1.24.0

        $encoding = [System.Text.UTF8Encoding]::new($true)
        $bom = $encoding.GetPreamble()
        $oldBytes = [System.IO.File]::ReadAllBytes($filePath)
        $hasBom = $oldBytes.Length -ge 3 -and $oldBytes[0] -eq 0xEF -and $oldBytes[1] -eq 0xBB -and $oldBytes[2] -eq 0xBF
        $offset = if ($hasBom) { $bom.Length } else { 0 }
        try {
            # Decoding throws on invalid bytes, so a file in another encoding is never rewritten
            $original = [System.Text.UTF8Encoding]::new($false, $true).GetString($oldBytes, $offset, $oldBytes.Length - $offset)
        }
        catch [System.Text.DecoderFallbackException] {
            return [PSCustomObject]@{
                ExitCode = 2
                Message  = "${filePath} is not valid UTF-8, so it was not formatted. Save it as UTF-8 with BOM."
            }
        }

        $formatted = Invoke-Formatter -ScriptDefinition ($original -replace "`r`n?", "`n") -Settings $SettingsPath
        $formatted = $formatted -replace "`r?`n", "`r`n"
        $newBytes = $bom + $encoding.GetBytes($formatted)
        if ([Convert]::ToBase64String($newBytes) -ne [Convert]::ToBase64String($oldBytes)) {
            [System.IO.File]::WriteAllBytes($filePath, $newBytes)
        }

        $findings = @(Invoke-ScriptAnalyzer -Path $filePath -Settings $SettingsPath)
        if ($findings.Count -gt 0) {
            $lines = @("PSScriptAnalyzer findings in ${filePath}:")
            foreach ($finding in $findings) {
                $lines += "  line $($finding.Line): $($finding.RuleName): $($finding.Message)"
            }
            return [PSCustomObject]@{ ExitCode = 2; Message = $lines -join [Environment]::NewLine }
        }
        return [PSCustomObject]@{ ExitCode = 0; Message = '' }
    }
    catch {
        return [PSCustomObject]@{ ExitCode = 1; Message = "format-powershell hook failed: $_" }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Set-StrictMode -Version Latest
    # On Windows, no PATH entry starts with /mnt/, so this changes nothing there
    $separator = [System.IO.Path]::PathSeparator
    $env:PATH = ($env:PATH -split $separator | Where-Object { $_ -notlike '/mnt/*' }) -join $separator
    # pwsh -File passes redirected stdin to $input, as does a pipe into the script
    $result = Invoke-FormatPowerShellHook -HookInput (@($input) -join "`n")
    if ($result.Message) {
        [Console]::Error.WriteLine($result.Message)
    }
    exit $result.ExitCode
}
