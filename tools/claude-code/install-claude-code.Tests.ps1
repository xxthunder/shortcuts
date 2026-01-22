#Requires -Version 5.1

BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Get the script path
    $script:scriptPath = Join-Path $PSScriptRoot "install-claude-code.ps1"
}

Describe "install-claude-code.ps1" {
    Context "Script Structure" {
        It "Should have proper error handling" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Set-StrictMode'
            $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*"Stop"'
            $scriptContent | Should -Match 'try\s*\{'
            $scriptContent | Should -Match 'catch\s*\{'
            $scriptContent | Should -Match 'finally\s*\{'
        }

        It "Should source utils.ps1 from correct relative path" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match '\.\s+"\$PSScriptRoot\\\.\.\\pslib\\utils\\utils\.ps1"'
        }

        It "Should check for CI environment" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Test-RunningInCIorTestEnvironment'
        }

        It "Should display success message" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Installation complete'
        }

        It "Should display Keypirinha refresh reminder" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Remember to refresh Keypirinha catalog'
        }

        It "Should exit with error code on failure" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'exit 1'
        }
    }

    Context "Native Installation Method" {
        It "Should use Invoke-RestMethod to download installer" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Invoke-RestMethod'
        }

        It "Should download from official Anthropic URL" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'https://claude\.ai/install\.ps1'
        }

        It "Should use Invoke-Expression to execute installer" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Invoke-Expression'
        }

        It "Should validate download result is not empty" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'IsNullOrWhiteSpace'
            $scriptContent | Should -Match 'Failed to download'
        }

        It "Should use UseBasicParsing for compatibility" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'UseBasicParsing'
        }
    }

    Context "Help Documentation" {
        It "Should have comprehensive help comments" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match '\.SYNOPSIS'
            $scriptContent | Should -Match '\.DESCRIPTION'
            $scriptContent | Should -Match '\.EXAMPLE'
        }

        It "Should mention native installation method in description" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'native installation'
        }

        It "Should reference Anthropic in documentation" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Anthropic'
        }
    }

    Context "Error Messages" {
        It "Should have informative error message for download failure" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Installation failed'
        }

        It "Should use Write-ErrorMsg for error display" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Write-ErrorMsg'
        }
    }

    Context "User Experience" {
        It "Should display installation URL to user" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Downloading installer from'
        }

        It "Should inform user about execution step" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Executing installation script'
        }

        It "Should tell user the command to run after installation" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'You can now run: claude'
        }
    }
}
