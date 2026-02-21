#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.SYNOPSIS
    Tests for testrunner.ps1 helper functions.
.DESCRIPTION
    Unit tests for ConvertTo-RelativeJUnitXml and other testrunner helpers.
#>

BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\testrunner.ps1"
}

Describe 'ConvertTo-RelativeJUnitXml' {
    BeforeEach {
        $script:tempFile = Join-Path $TestDrive "junit.xml"
    }

    It 'Strips repo root from testsuite name and package attributes' {
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1" package="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1">
  </testsuite>
</testsuites>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJUnitXml -Path $script:tempFile -RepoRoot 'C:\Users\karst\shortcuts'

        [xml]$result = Get-Content $script:tempFile -Raw
        $suite = $result.testsuites.testsuite
        $suite.name | Should -Be 'test/bin/linter.Tests.ps1'
        $suite.package | Should -Be 'test/bin/linter.Tests.ps1'
    }

    It 'Strips repo root from testcase classname attribute' {
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="suite">
    <testcase classname="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1" name="some test" />
  </testsuite>
</testsuites>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJUnitXml -Path $script:tempFile -RepoRoot 'C:\Users\karst\shortcuts'

        [xml]$result = Get-Content $script:tempFile -Raw
        $result.testsuites.testsuite.testcase.classname | Should -Be 'test/bin/linter.Tests.ps1'
    }

    It 'Strips repo root from testcase name attribute with embedded paths' {
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="suite">
    <testcase classname="cls" name="Analysis of file C:\Users\karst\shortcuts\tools\proxy\setProxy.ps1 against Script Analyzer Rules.Shall not have deviations" />
  </testsuite>
</testsuites>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJUnitXml -Path $script:tempFile -RepoRoot 'C:\Users\karst\shortcuts'

        [xml]$result = Get-Content $script:tempFile -Raw
        $result.testsuites.testsuite.testcase.name | Should -Be 'Analysis of file tools/proxy/setProxy.ps1 against Script Analyzer Rules.Shall not have deviations'
    }

    It 'Converts backslashes to forward slashes in all normalized attributes' {
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="C:\Users\karst\shortcuts\tools\pslib\wsl\lib\core.Tests.ps1" package="C:\Users\karst\shortcuts\tools\pslib\wsl\lib\core.Tests.ps1">
    <testcase classname="C:\Users\karst\shortcuts\tools\pslib\wsl\lib\core.Tests.ps1" name="some test" />
  </testsuite>
</testsuites>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJUnitXml -Path $script:tempFile -RepoRoot 'C:\Users\karst\shortcuts'

        [xml]$result = Get-Content $script:tempFile -Raw
        $suite = $result.testsuites.testsuite
        $suite.name | Should -Be 'tools/pslib/wsl/lib/core.Tests.ps1'
        $suite.package | Should -Be 'tools/pslib/wsl/lib/core.Tests.ps1'
        $suite.testcase.classname | Should -Be 'tools/pslib/wsl/lib/core.Tests.ps1'
    }

    It 'Preserves non-path content in name attributes' {
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="suite">
    <testcase classname="cls" name="Some test without paths.Shall work fine" />
  </testsuite>
</testsuites>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJUnitXml -Path $script:tempFile -RepoRoot 'C:\Users\karst\shortcuts'

        [xml]$result = Get-Content $script:tempFile -Raw
        $result.testsuites.testsuite.testcase.name | Should -Be 'Some test without paths.Shall work fine'
    }

    It 'Handles trailing backslash on repo root' {
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1" package="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1">
  </testsuite>
</testsuites>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJUnitXml -Path $script:tempFile -RepoRoot 'C:\Users\karst\shortcuts\'

        [xml]$result = Get-Content $script:tempFile -Raw
        $suite = $result.testsuites.testsuite
        $suite.name | Should -Be 'test/bin/linter.Tests.ps1'
        $suite.package | Should -Be 'test/bin/linter.Tests.ps1'
    }

    It 'Saves valid XML' {
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1" package="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1">
    <testcase classname="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1" name="test" />
  </testsuite>
</testsuites>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJUnitXml -Path $script:tempFile -RepoRoot 'C:\Users\karst\shortcuts'

        # Should not throw when parsing as XML
        { [xml](Get-Content $script:tempFile -Raw) } | Should -Not -Throw
    }

    It 'Handles multiple testsuites and testcases' {
        $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<testsuites>
  <testsuite name="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1" package="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1">
    <testcase classname="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1" name="test1" />
    <testcase classname="C:\Users\karst\shortcuts\test\bin\linter.Tests.ps1" name="test2" />
  </testsuite>
  <testsuite name="C:\Users\karst\shortcuts\tools\pslib\utils\utils.Tests.ps1" package="C:\Users\karst\shortcuts\tools\pslib\utils\utils.Tests.ps1">
    <testcase classname="C:\Users\karst\shortcuts\tools\pslib\utils\utils.Tests.ps1" name="test3" />
  </testsuite>
</testsuites>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJUnitXml -Path $script:tempFile -RepoRoot 'C:\Users\karst\shortcuts'

        [xml]$result = Get-Content $script:tempFile -Raw
        $suites = @($result.testsuites.testsuite)
        $suites[0].name | Should -Be 'test/bin/linter.Tests.ps1'
        $suites[0].package | Should -Be 'test/bin/linter.Tests.ps1'
        $suites[1].name | Should -Be 'tools/pslib/utils/utils.Tests.ps1'
        $suites[1].package | Should -Be 'tools/pslib/utils/utils.Tests.ps1'
        @($suites[0].testcase)[0].classname | Should -Be 'test/bin/linter.Tests.ps1'
        $suites[1].testcase.classname | Should -Be 'tools/pslib/utils/utils.Tests.ps1'
    }
}
