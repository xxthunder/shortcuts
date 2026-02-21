#Requires -Version 5.1
#Requires -Modules @{ModuleName = 'Pester'; ModuleVersion = '5.7.1'}

<#
.SYNOPSIS
    Tests for testrunner.ps1 helper functions.
.DESCRIPTION
    Unit tests for ConvertTo-RelativeJUnitXml, ConvertTo-RelativeJaCoCoXml,
    and other testrunner helpers.
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

Describe 'ConvertTo-RelativeJaCoCoXml' {
    BeforeEach {
        $script:tempFile = Join-Path $TestDrive "coverage.xml"
    }

    It 'Strips common-parent-leaf prefix from package name' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd"[]>
<report name="Pester">
  <package name="shortcuts/bin">
    <sourcefile name="bin/install.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </sourcefile>
  </package>
</report>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJaCoCoXml -Path $script:tempFile

        $result = Import-XmlWithoutDtd -Path $script:tempFile
        $result.report.package.name | Should -Be 'bin'
    }

    It 'Strips common-parent-leaf prefix from class name' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd"[]>
<report name="Pester">
  <package name="shortcuts/tools/proxy">
    <class name="shortcuts/tools/proxy/setProxy" sourcefilename="tools/proxy/setProxy.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </class>
  </package>
</report>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJaCoCoXml -Path $script:tempFile

        $result = Import-XmlWithoutDtd -Path $script:tempFile
        $result.report.package.class.name | Should -Be 'tools/proxy/setProxy'
    }

    It 'Reduces sourcefile name to bare filename' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd"[]>
<report name="Pester">
  <package name="shortcuts/tools/pslib/utils">
    <sourcefile name="tools/pslib/utils/utils.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </sourcefile>
  </package>
</report>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJaCoCoXml -Path $script:tempFile

        $result = Import-XmlWithoutDtd -Path $script:tempFile
        $result.report.package.sourcefile.name | Should -Be 'utils.ps1'
    }

    It 'Reduces class sourcefilename to bare filename' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd"[]>
<report name="Pester">
  <package name="shortcuts/bin">
    <class name="shortcuts/bin/install" sourcefilename="bin/install.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </class>
  </package>
</report>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJaCoCoXml -Path $script:tempFile

        $result = Import-XmlWithoutDtd -Path $script:tempFile
        $result.report.package.class.sourcefilename | Should -Be 'install.ps1'
    }

    It 'Handles multiple packages with classes and sourcefiles' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd"[]>
<report name="Pester">
  <package name="shortcuts/bin">
    <class name="shortcuts/bin/install" sourcefilename="bin/install.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </class>
    <sourcefile name="bin/install.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </sourcefile>
  </package>
  <package name="shortcuts/tools/pslib/wsl/lib">
    <class name="shortcuts/tools/pslib/wsl/lib/core" sourcefilename="tools/pslib/wsl/lib/core.ps1">
      <counter type="LINE" missed="20" covered="10" />
    </class>
    <class name="shortcuts/tools/pslib/wsl/lib/docker" sourcefilename="tools/pslib/wsl/lib/docker.ps1">
      <counter type="LINE" missed="30" covered="15" />
    </class>
    <sourcefile name="tools/pslib/wsl/lib/core.ps1">
      <counter type="LINE" missed="20" covered="10" />
    </sourcefile>
    <sourcefile name="tools/pslib/wsl/lib/docker.ps1">
      <counter type="LINE" missed="30" covered="15" />
    </sourcefile>
  </package>
</report>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJaCoCoXml -Path $script:tempFile

        [xml]$result = Get-Content $script:tempFile -Raw
        $pkgs = @($result.report.package)
        $pkgs[0].name | Should -Be 'bin'
        $pkgs[0].class.name | Should -Be 'bin/install'
        $pkgs[0].class.sourcefilename | Should -Be 'install.ps1'
        $pkgs[0].sourcefile.name | Should -Be 'install.ps1'
        $pkgs[1].name | Should -Be 'tools/pslib/wsl/lib'
        $classes = @($pkgs[1].class)
        $classes[0].name | Should -Be 'tools/pslib/wsl/lib/core'
        $classes[0].sourcefilename | Should -Be 'core.ps1'
        $classes[1].name | Should -Be 'tools/pslib/wsl/lib/docker'
        $classes[1].sourcefilename | Should -Be 'docker.ps1'
        $srcs = @($pkgs[1].sourcefile)
        $srcs[0].name | Should -Be 'core.ps1'
        $srcs[1].name | Should -Be 'docker.ps1'
    }

    It 'Saves valid XML' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd"[]>
<report name="Pester">
  <package name="shortcuts/bin">
    <class name="shortcuts/bin/install" sourcefilename="bin/install.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </class>
    <sourcefile name="bin/install.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </sourcefile>
  </package>
</report>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJaCoCoXml -Path $script:tempFile

        { Import-XmlWithoutDtd -Path $script:tempFile } | Should -Not -Throw
    }

    It 'Is idempotent when run twice' {
        $xml = @'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd"[]>
<report name="Pester">
  <package name="shortcuts/bin">
    <class name="shortcuts/bin/install" sourcefilename="bin/install.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </class>
    <sourcefile name="bin/install.ps1">
      <counter type="LINE" missed="10" covered="5" />
    </sourcefile>
  </package>
</report>
'@
        $xml | Out-File -FilePath $script:tempFile -Encoding UTF8

        ConvertTo-RelativeJaCoCoXml -Path $script:tempFile
        ConvertTo-RelativeJaCoCoXml -Path $script:tempFile

        $result = Import-XmlWithoutDtd -Path $script:tempFile
        $result.report.package.name | Should -Be 'bin'
        $result.report.package.class.name | Should -Be 'bin/install'
        $result.report.package.sourcefile.name | Should -Be 'install.ps1'
    }
}
