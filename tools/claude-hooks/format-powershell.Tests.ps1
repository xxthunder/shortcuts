#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.DESCRIPTION
    Pester tests for the Claude Code PostToolUse hook that formats and lints a PowerShell file
    after Claude edits it (SC-083). Most tests call Invoke-FormatPowerShellHook in-process, so
    code coverage sees the hook. The last test runs the script as Claude Code runs it: a fresh
    pwsh process that reads the hook input as JSON on stdin.
#>

BeforeAll {
    $script:hookPath = Join-Path $PSScriptRoot 'format-powershell.ps1'
    . $script:hookPath
    $script:bom = [byte[]](0xEF, 0xBB, 0xBF)

    function ConvertTo-HookInput {
        param([string]$FilePath)
        @{
            hook_event_name = 'PostToolUse'
            tool_name       = 'Edit'
            tool_input      = @{ file_path = $FilePath }
        } | ConvertTo-Json -Compress
    }

    function Write-TestFile {
        param([string]$Name, [string]$Content)
        $path = Join-Path $TestDrive $Name
        [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
        $path
    }
}

Describe 'Invoke-FormatPowerShellHook' {
    Context 'When the edited file is a badly formatted PowerShell script' {
        BeforeAll {
            $script:path = Write-TestFile -Name 'messy.ps1' -Content "if (`$true) {`n  Write-Output 'x'`n} else {`n Write-Output 'y'`n}`n"
            $script:result = Invoke-FormatPowerShellHook -HookInput (ConvertTo-HookInput -FilePath $script:path)
            $script:bytes = [System.IO.File]::ReadAllBytes($script:path)
            $script:text = [System.IO.File]::ReadAllText($script:path)
        }

        It 'Should return exit code 0' {
            $script:result.ExitCode | Should -Be 0
        }

        It 'Should return no message' {
            $script:result.Message | Should -BeNullOrEmpty
        }

        It 'Should format the file' {
            $script:text | Should -BeExactly "if (`$true) {`r`n    Write-Output 'x'`r`n}`r`nelse {`r`n    Write-Output 'y'`r`n}`r`n"
        }

        It 'Should write a UTF-8 BOM' {
            $script:bytes[0..2] | Should -Be $script:bom
        }
    }

    Context 'When the edited file is already formatted' {
        BeforeAll {
            $script:path = Join-Path $TestDrive 'clean.ps1'
            [System.IO.File]::WriteAllText($script:path, "Write-Output 'x'`r`n", [System.Text.UTF8Encoding]::new($true))
            $script:lastWrite = [datetime]::new(2000, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
            (Get-Item $script:path).LastWriteTimeUtc = $script:lastWrite
            $script:result = Invoke-FormatPowerShellHook -HookInput (ConvertTo-HookInput -FilePath $script:path)
        }

        It 'Should return exit code 0' {
            $script:result.ExitCode | Should -Be 0
        }

        It 'Should not write the file' {
            (Get-Item $script:path).LastWriteTimeUtc | Should -Be $script:lastWrite
        }
    }

    Context 'When the edited file has a lint finding that formatting cannot fix' {
        BeforeAll {
            $script:path = Write-TestFile -Name 'finding.ps1' -Content "function Get-Things {`r`n    param(`$Unused)`r`n    Write-Host 'x'`r`n}`r`n"
            $script:result = Invoke-FormatPowerShellHook -HookInput (ConvertTo-HookInput -FilePath $script:path)
        }

        It 'Should return exit code 2' {
            $script:result.ExitCode | Should -Be 2
        }

        It 'Should name the rule and the file' {
            $script:result.Message | Should -Match 'PSReviewUnusedParameter'
            $script:result.Message | Should -Match 'finding\.ps1'
        }
    }

    Context 'When the edited file ends its lines with <Case>' -ForEach @(
        @{ Case = 'a lone CR'; Content = "Write-Output 'x'`rWrite-Output 'y'`r" }
        @{ Case = 'mixed CR, LF and CRLF'; Content = "Write-Output 'x'`rWrite-Output 'y'`nWrite-Output 'z'`r`n" }
    ) {
        BeforeAll {
            $script:path = Write-TestFile -Name 'line-endings.ps1' -Content $Content
            $script:result = Invoke-FormatPowerShellHook -HookInput (ConvertTo-HookInput -FilePath $script:path)
        }

        It 'Should write CRLF line endings only' {
            $script:result.ExitCode | Should -Be 0
            $text = [System.IO.File]::ReadAllText($script:path)
            $text | Should -Not -Match "`r(?!`n)|(?<!`r)`n"
            $text | Should -BeLike "Write-Output 'x'`r`nWrite-Output 'y'`r`n*"
        }
    }

    Context 'When the edited file is not valid UTF-8' {
        BeforeAll {
            $script:path = Join-Path $TestDrive 'latin1.ps1'
            # 0xE4 is a-umlaut in Windows-1252 and an invalid byte sequence in UTF-8
            $script:original = [byte[]](0x69, 0x66, 0x28, 0x24, 0x74, 0x72, 0x75, 0x65, 0x29, 0x7B, 0x27, 0xE4, 0x27, 0x7D, 0x0A)
            [System.IO.File]::WriteAllBytes($script:path, $script:original)
            $script:result = Invoke-FormatPowerShellHook -HookInput (ConvertTo-HookInput -FilePath $script:path)
        }

        It 'Should return exit code 2' {
            $script:result.ExitCode | Should -Be 2
        }

        It 'Should say that the file is not valid UTF-8' {
            $script:result.Message | Should -Match 'not valid UTF-8'
            $script:result.Message | Should -Match 'latin1\.ps1'
        }

        It 'Should leave the file unchanged' {
            [System.IO.File]::ReadAllBytes($script:path) | Should -Be $script:original
        }
    }

    Context 'When the edited file is <_>' -ForEach @('settings.psd1', 'module.psm1') {
        BeforeAll {
            $script:path = Write-TestFile -Name $_ -Content "@{`n  A = 1`n}`n"
            $script:result = Invoke-FormatPowerShellHook -HookInput (ConvertTo-HookInput -FilePath $script:path)
        }

        It 'Should format it as PowerShell' {
            $script:result.ExitCode | Should -Be 0
            [System.IO.File]::ReadAllText($script:path) | Should -BeExactly "@{`r`n    A = 1`r`n}`r`n"
        }
    }

    Context 'When the edited file is not PowerShell' {
        BeforeAll {
            $script:content = "if (`$true) {`n  x`n}`n"
            $script:path = Write-TestFile -Name 'notes.md' -Content $script:content
            $script:result = Invoke-FormatPowerShellHook -HookInput (ConvertTo-HookInput -FilePath $script:path)
        }

        It 'Should return exit code 0' {
            $script:result.ExitCode | Should -Be 0
        }

        It 'Should leave the file unchanged' {
            [System.IO.File]::ReadAllText($script:path) | Should -BeExactly $script:content
        }
    }

    Context 'When the hook input has <Case>' -ForEach @(
        @{ Case = 'a file that no longer exists'; HookInput = '{"tool_input":{"file_path":"/nonexistent/gone.ps1"}}' }
        @{ Case = 'no file path'; HookInput = '{"tool_input":{}}' }
        @{ Case = 'no tool input'; HookInput = '{}' }
        @{ Case = 'no content'; HookInput = '' }
    ) {
        It 'Should return exit code 0' {
            (Invoke-FormatPowerShellHook -HookInput $HookInput).ExitCode | Should -Be 0
        }
    }

    Context 'When the hook fails' {
        BeforeAll {
            $script:path = Write-TestFile -Name 'broken-settings.ps1' -Content "Write-Output 'x'`n"
            $hookInput = ConvertTo-HookInput -FilePath $script:path
            $script:result = Invoke-FormatPowerShellHook -HookInput $hookInput -SettingsPath (Join-Path $TestDrive 'missing.psd1')
        }

        It 'Should return exit code 1' {
            $script:result.ExitCode | Should -Be 1
        }

        It 'Should say that the hook failed' {
            $script:result.Message | Should -Match 'format-powershell hook failed'
        }
    }
}

Describe 'format-powershell.ps1 run as a script' {
    BeforeAll {
        $script:savedPath = $env:PATH
    }

    AfterAll {
        $env:PATH = $script:savedPath
    }

    It 'Should exit with code <ExitCode> for <Case>' -ForEach @(
        @{ Case = 'a lint finding'; Content = "function Get-Things {`r`n    param(`$Unused)`r`n}`r`n"; ExitCode = 2 }
        @{ Case = 'a clean file'; Content = "Write-Output 'x'`r`n"; ExitCode = 0 }
    ) {
        $path = Write-TestFile -Name 'piped.ps1' -Content $Content
        ConvertTo-HookInput -FilePath $path | & $script:hookPath 2>$null
        $LASTEXITCODE | Should -Be $ExitCode
    }

    It 'Should exit with code 0 and print nothing for empty stdin' {
        $output = '' | & $script:hookPath 2>&1
        $LASTEXITCODE | Should -Be 0
        $output | Should -BeNullOrEmpty
    }

    It 'Should drop the /mnt/ entries from PATH' {
        $separator = [System.IO.Path]::PathSeparator
        $env:PATH = "/mnt/c/Windows$separator$script:savedPath"
        '{}' | & $script:hookPath
        $env:PATH -split $separator | Should -Not -Contain '/mnt/c/Windows'
    }
}

Describe 'format-powershell.ps1 run as a Claude Code hook' {
    It 'Should read stdin, print the findings to stderr and exit with code 2' {
        $path = Write-TestFile -Name 'process.ps1' -Content "function Get-Things {`r`n    param(`$Unused)`r`n}`r`n"
        $inputFile = Join-Path $TestDrive 'stdin.json'
        $stderrFile = Join-Path $TestDrive 'stderr.txt'
        Set-Content -Path $inputFile -Value (ConvertTo-HookInput -FilePath $path) -NoNewline
        $process = Start-Process -FilePath 'pwsh' -ArgumentList '-NoProfile', '-File', $script:hookPath `
            -RedirectStandardInput $inputFile -RedirectStandardOutput (Join-Path $TestDrive 'stdout.txt') `
            -RedirectStandardError $stderrFile -NoNewWindow -Wait -PassThru

        $process.ExitCode | Should -Be 2
        Get-Content -Path $stderrFile -Raw | Should -Match 'PSReviewUnusedParameter'
    }
}
