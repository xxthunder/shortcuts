#Requires -Version 5.1

BeforeAll {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # Get the script path
    $script:scriptPath = Join-Path $PSScriptRoot "install-flow-launcher.ps1"
}

Describe "install-flow-launcher.ps1" {
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
            $scriptContent | Should -Match '\.\s+"\$PSScriptRoot\\\.\.\\\.\.\\lib\\utils\\utils\.ps1"'
        }

        It "Should check for CI environment" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Test-RunningInCIorTestEnvironment'
        }

        It "Should exit with error code on failure" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'exit 1'
        }
    }

    Context "Scoop Prerequisites" {
        It "Should check for scoop availability" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Get-Command\s+scoop'
        }

        It "Should add extras bucket" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'scoop bucket add extras'
        }

        It "Should add extras bucket with StopAtError false (idempotent, bucket may already exist)" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'scoop bucket add extras.*-StopAtError \$false'
        }

        It "Should install flow-launcher via scoop" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'scoop install flow-launcher'
        }
    }

    Context "Invoke-CommandLine Usage" {
        It "Should use -CommandLine parameter name (not -Command)" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Not -Match 'Invoke-CommandLine\s+-Command\s'
            $scriptContent | Should -Match 'Invoke-CommandLine\s+-CommandLine\s'
        }

        It "Should pass StopAtError as bool not switch" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            # -StopAtError without $true/$false is wrong (it's [bool], not [switch])
            $scriptContent | Should -Not -Match '-StopAtError[^$\s]'
            $scriptContent | Should -Not -Match '-StopAtError\s*[^$\s\r\n]'
        }
    }

    Context "Idempotency" {
        It "Should check if flow-launcher is already installed with StopAtError false" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'scoop list flow-launcher.*-StopAtError \$false'
        }
    }

    Context "Process Lifecycle" {
        It "Should stop running Flow Launcher instances before configuring" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Stop-Process.*Flow\.Launcher'
        }

        It "Should stop Flow Launcher before plugin configuration" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            # Stop-Process must appear before Update-ProgramPluginConfig
            $stopIndex = $scriptContent.IndexOf('Stop-Process')
            $configIndex = $scriptContent.IndexOf('Update-ProgramPluginConfig')
            $stopIndex | Should -BeLessThan $configIndex
        }
    }

    Context "Plugin Configuration" {
        It "Should source configure-program-plugin.ps1" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'configure-program-plugin\.ps1'
        }

        It "Should call Update-ProgramPluginConfig" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Update-ProgramPluginConfig'
        }
    }

    Context "Flow Launcher Launch" {
        It "Should start Flow.Launcher.exe using full Scoop path" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'scoop\\apps\\flow-launcher\\current\\Flow\.Launcher\.exe'
        }
    }

    Context "Help Documentation" {
        It "Should have comprehensive help comments" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match '\.SYNOPSIS'
            $scriptContent | Should -Match '\.DESCRIPTION'
            $scriptContent | Should -Match '\.EXAMPLE'
        }

        It "Should mention standalone usage in documentation" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'standalone'
        }

        It "Should mention optional nature in documentation" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'optional'
        }
    }

    Context "User Experience" {
        It "Should display status messages during installation" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Write-Status'
        }

        It "Should display success message" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Installation complete'
        }

        It "Should display Alt+Space usage hint" {
            $scriptContent = Get-Content $script:scriptPath -Raw
            $scriptContent | Should -Match 'Alt\+Space'
        }
    }
}
