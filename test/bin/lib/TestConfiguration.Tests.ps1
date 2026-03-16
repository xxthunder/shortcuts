#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

Describe "Test Configuration Logic" {
    BeforeAll {
        . "$PSScriptRoot\TestIsolation.ps1"
        $libPath = Join-Path $PSScriptRoot "TestConfiguration.ps1"
        if (-not (Test-Path $libPath)) {
            Throw "Script not found at $libPath"
        }
        Start-SutIsolation
        . $libPath

        # Setup temporary test directory structure
        $TestDrive = Join-Path $PSScriptRoot "temp_test_structure"
        Write-Output "Setting up TestDrive at $TestDrive"

        if (Test-Path $TestDrive) { Remove-Item $TestDrive -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $TestDrive -Force | Out-Null

        # Create dummy test files
        New-Item -ItemType Directory -Path "$TestDrive\tools" -Force | Out-Null
        New-Item -ItemType File -Path "$TestDrive\tools\unit.Tests.ps1" -Force | Out-Null
        New-Item -ItemType File -Path "$TestDrive\tools\integration.Integration.Tests.ps1" -Force | Out-Null

        # Create subfolder
        New-Item -ItemType Directory -Path "$TestDrive\tools\subdir" -Force | Out-Null
        New-Item -ItemType File -Path "$TestDrive\tools\subdir\sub.Tests.ps1" -Force | Out-Null

        $script:TestRepoRoot = $TestDrive
    }

    AfterAll {
        if ($script:TestRepoRoot -and (Test-Path $script:TestRepoRoot)) {
            Remove-Item $script:TestRepoRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        Stop-SutIsolation
    }

    Context "Get-TestConfiguration Path Resolution" {

        It "Should use default paths 'tools', 'test', 'bin', and 'lib' when TestPath is empty" {
            Write-Output "RepoRoot: $script:TestRepoRoot"
            # We need to ensure tools/test/bin/lib exist in our dummy root for this to pass validation
            New-Item -ItemType Directory -Path "$script:TestRepoRoot\test" -Force | Out-Null
            New-Item -ItemType Directory -Path "$script:TestRepoRoot\bin" -Force | Out-Null
            New-Item -ItemType Directory -Path "$script:TestRepoRoot\lib" -Force | Out-Null

            $config = Get-TestConfiguration -TestPath @() -RepoRoot $script:TestRepoRoot

            $config.OriginalPaths | Should -Contain "$script:TestRepoRoot\tools"
            $config.OriginalPaths | Should -Contain "$script:TestRepoRoot\test"
            $config.OriginalPaths | Should -Contain "$script:TestRepoRoot\bin"
            $config.OriginalPaths | Should -Contain "$script:TestRepoRoot\lib"
        }

        It "Should resolve relative paths against RepoRoot" {
            $config = Get-TestConfiguration -TestPath @('tools\subdir') -RepoRoot $script:TestRepoRoot

            $config.OriginalPaths | Should -Contain "$script:TestRepoRoot\tools\subdir"
        }

        It "Should resolve specific file path correctly" {
            $filePath = 'tools\unit.Tests.ps1'
            $config = Get-TestConfiguration -TestPath @($filePath) -RepoRoot $script:TestRepoRoot

            $config.OriginalPaths | Should -Contain "$script:TestRepoRoot\$filePath"
        }

        It "Should throw error if path does not exist" {
            { Get-TestConfiguration -TestPath @('fake/path') -RepoRoot $script:TestRepoRoot } | Should -Throw
        }
    }

    Context "Unit vs Integration Filtering" {

        It "Should include all valid paths/files when no switch is provided" {
            $config = Get-TestConfiguration -TestPath @('tools') -RepoRoot $script:TestRepoRoot

            # Without -Unit/-Integration, it just returns path provided if it's a folder
            $config.TestPaths | Should -Contain "$script:TestRepoRoot\tools"
        }

        It "Should expand files and exclude Integration tests when -Unit is specified" {
            $params = @{
                TestPath = @('tools')
                RepoRoot = "$($script:TestRepoRoot)"
                RunUnit = $true
            }
            $config = Get-TestConfiguration @params

            $paths = $config.TestPaths
            $expectedUnit = "$script:TestRepoRoot\tools\unit.Tests.ps1"
            $expectedSub = "$script:TestRepoRoot\tools\subdir\sub.Tests.ps1"
            $unexpectedInt = "$script:TestRepoRoot\tools\integration.Integration.Tests.ps1"

            $paths -contains $expectedUnit | Should -BeTrue
            $paths -contains $expectedSub | Should -BeTrue
            $paths -contains $unexpectedInt | Should -BeFalse
        }

        It "Should expand files and include ONLY Integration tests when -Integration is specified" {
            $params = @{
                TestPath = @('tools')
                RepoRoot = "$($script:TestRepoRoot)"
                RunIntegration = $true
            }
            $config = Get-TestConfiguration @params

            $paths = $config.TestPaths
            $expectedInt = "$script:TestRepoRoot\tools\integration.Integration.Tests.ps1"
            $unexpectedUnit = "$script:TestRepoRoot\tools\unit.Tests.ps1"

            $paths -contains $expectedInt | Should -BeTrue
            $paths -contains $unexpectedUnit | Should -BeFalse
        }
    }
}
