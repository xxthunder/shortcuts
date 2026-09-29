#Requires -Version 7.4
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.DESCRIPTION
    Pester tests for tools/structurizr/structurizr-local.ps1 (SC-062). wsl.exe, the browser
    and the web requests are mocked.
#>

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    $env:STRUCTURIZR_LOCAL_LIBRARY_MODE = '1'
    Start-SutIsolation
    . "$PSScriptRoot\structurizr-local.ps1"
}

AfterAll {
    Remove-Item Env:\STRUCTURIZR_LOCAL_LIBRARY_MODE -ErrorAction SilentlyContinue
    Stop-SutIsolation
}

Describe "Get-StructurizrLocalCommandLine" {
    It "Should run the Bash script in the default distribution when none is given" {
        Get-StructurizrLocalCommandLine -RepoRoot 'C:\Users\dev\shortcuts' -Port 8080 |
            Should -Be 'wsl.exe --cd "C:\Users\dev\shortcuts" --exec bash -l tools/structurizr/structurizr-local.sh --port=8080'
    }

    It "Should run it in the given distribution on the given port" {
        Get-StructurizrLocalCommandLine -RepoRoot 'C:\Users\dev\shortcuts' -Distro 'Ubuntu-24.04' -Port 8081 |
            Should -Be 'wsl.exe --distribution Ubuntu-24.04 --cd "C:\Users\dev\shortcuts" --exec bash -l tools/structurizr/structurizr-local.sh --port=8081'
    }

    It "Should quote a repository path with spaces" {
        Get-StructurizrLocalCommandLine -RepoRoot 'C:\Users\Jane Doe\shortcuts' -Port 8080 |
            Should -BeLike '*--cd "C:\Users\Jane Doe\shortcuts" --exec*'
    }
}

Describe "Wait-StructurizrReady" {
    BeforeEach {
        Mock Start-Sleep {}
    }

    It "Should return true as soon as the URL answers" {
        Mock Invoke-WebRequest {}

        Wait-StructurizrReady -Url 'http://localhost:8080' -Attempts 3 | Should -BeTrue
        Should -Invoke Invoke-WebRequest -Times 1
    }

    It "Should return false after the last attempt when the URL never answers" {
        Mock Invoke-WebRequest { throw 'connection refused' }

        Wait-StructurizrReady -Url 'http://localhost:8080' -Attempts 3 | Should -BeFalse
        Should -Invoke Invoke-WebRequest -Times 3
    }
}

Describe "StructurizrOpenWhenReady" {
    BeforeEach {
        Mock Start-Sleep {}
        Mock Start-Process {}
    }

    It "Should open the browser once the viewer answers" {
        Mock Invoke-WebRequest {}

        & $script:StructurizrOpenWhenReady ${function:Wait-StructurizrReady}.ToString() 'http://localhost:8080' 3

        Should -Invoke Start-Process -Times 1 -ParameterFilter { $FilePath -eq 'http://localhost:8080' }
    }

    It "Should not open the browser when the viewer never answers" {
        Mock Invoke-WebRequest { throw 'connection refused' }

        & $script:StructurizrOpenWhenReady ${function:Wait-StructurizrReady}.ToString() 'http://localhost:8080' 3

        Should -Invoke Start-Process -Times 0
    }
}

Describe "Start-StructurizrBrowserJob" {
    BeforeEach {
        Mock Start-Sleep {}
        Mock Start-Process {}
        # Runs the job's script block in place, so the mocks above apply inside it
        Mock Start-ThreadJob { & $ScriptBlock @ArgumentList }
    }

    It "Should start a job that opens the given URL once it answers" {
        Mock Invoke-WebRequest {}

        Start-StructurizrBrowserJob -Url 'http://localhost:8081' -Attempts 3

        Should -Invoke Start-ThreadJob -Times 1
        Should -Invoke Start-Process -Times 1 -ParameterFilter { $FilePath -eq 'http://localhost:8081' }
    }

    It "Should let the job give up after the given attempts" {
        Mock Invoke-WebRequest { throw 'connection refused' }

        Start-StructurizrBrowserJob -Url 'http://localhost:8080' -Attempts 2

        Should -Invoke Invoke-WebRequest -Times 2 -Exactly
        Should -Invoke Start-Process -Times 0
    }

    It "Should start no job with -WhatIf" {
        Start-StructurizrBrowserJob -Url 'http://localhost:8080' -WhatIf | Should -BeNullOrEmpty

        Should -Invoke Start-ThreadJob -Times 0
    }
}

Describe "Invoke-StructurizrLocalMain" {
    BeforeEach {
        Mock Start-StructurizrBrowserJob { $null }
        Mock Invoke-CommandLine { $global:LASTEXITCODE = 0 }
    }

    It "Should start the viewer through wsl.exe and return its exit code" {
        Invoke-StructurizrLocalMain -Port 8080 | Should -Be 0

        Should -Invoke Invoke-CommandLine -Times 1 -ParameterFilter {
            $CommandLine -like 'wsl.exe --cd "*" --exec bash -l tools/structurizr/structurizr-local.sh --port=8080' -and $StopAtError -eq $false
        }
    }

    It "Should return only the exit code while the viewer output goes to the console" {
        Mock Invoke-CommandLine { "Structurizr local started"; "log line"; $global:LASTEXITCODE = 0 }
        Mock Out-Host {}

        $result = Invoke-StructurizrLocalMain -Port 8080

        $result | Should -BeExactly 0
        Should -Invoke Out-Host -Times 1
    }

    It "Should return the exit code of a failed start" {
        Mock Invoke-CommandLine { $global:LASTEXITCODE = 1 }

        Invoke-StructurizrLocalMain -Port 8080 | Should -Be 1
    }

    It "Should open the browser for the chosen port" {
        Invoke-StructurizrLocalMain -Port 8081 | Out-Null

        Should -Invoke Start-StructurizrBrowserJob -Times 1 -ParameterFilter { $Url -eq 'http://localhost:8081' }
    }

    It "Should stop the browser job when the viewer ends" {
        Mock Start-StructurizrBrowserJob { Start-ThreadJob -ScriptBlock { } }
        Mock Stop-Job {}
        Mock Remove-Job {}

        Invoke-StructurizrLocalMain -Port 8080 | Out-Null

        Should -Invoke Stop-Job -Times 1
        Should -Invoke Remove-Job -Times 1

        # Clean up the real job past the mocks
        Microsoft.PowerShell.Core\Get-Job | Microsoft.PowerShell.Core\Remove-Job -Force
    }
}
