#Requires -Version 5.1

BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Get the script path
    $script:scriptPath = Join-Path $PSScriptRoot "install-npm-global.ps1"

    # Determine the PowerShell executable to use for subprocess tests
    # Use pwsh if available (PS 7+), otherwise fall back to powershell.exe (PS 5.1)
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $script:psExe = 'pwsh'
    } else {
        $script:psExe = 'powershell'
    }
}

Describe "install-npm-global.ps1" {
    Context "Parameter Validation" {
        It "Should require PackageName parameter" {
            # This test verifies the script will fail without PackageName
            # Temporarily set ErrorActionPreference to Continue to capture output
            $prevErrorAction = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                $result = & $script:psExe -NoProfile -NonInteractive -Command "& '$script:scriptPath'" 2>&1
            } finally {
                $ErrorActionPreference = $prevErrorAction
            }
            # Check for mandatory parameter error message
            ($result | Out-String) | Should -Match "PackageName"
        }

        It "Should have mandatory PackageName parameter" {
            # Parse the script to check parameter definition
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match '\[Parameter\(Mandatory\s*=\s*\$true'
            $scriptContent | Should -Match '\$PackageName'
        }

        It "Should have optional CheckCommand parameter" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match '\[Parameter\(Mandatory\s*=\s*\$false'
            $scriptContent | Should -Match '\$CheckCommand'
        }

        It "Should source utils.ps1 from correct relative path" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match '\.\s+"\$PSScriptRoot\\\.\.\\pslib\\utils\\utils\.ps1"'
        }
    }

    Context "Script Structure" {
        It "Should have proper error handling" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Set-StrictMode'
            $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*"Stop"'
            $scriptContent | Should -Match 'try\s*\{'
            $scriptContent | Should -Match 'catch\s*\{'
            $scriptContent | Should -Match 'finally\s*\{'
        }

        It "Should call Install-NpmPackage" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Install-NpmPackage'
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
    }

    Context "Help Documentation" {
        It "Should have comprehensive help comments" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match '\.SYNOPSIS'
            $scriptContent | Should -Match '\.DESCRIPTION'
            $scriptContent | Should -Match '\.PARAMETER PackageName'
            $scriptContent | Should -Match '\.PARAMETER CheckCommand'
            $scriptContent | Should -Match '\.EXAMPLE'
        }

        It "Should include usage examples in help" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match '@anthropic-ai/claude-code'
            $scriptContent | Should -Match '@github/copilot'
        }
    }
}
