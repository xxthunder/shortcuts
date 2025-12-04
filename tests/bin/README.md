# Test Execution Scripts

This directory contains scripts for running Pester tests in CI and local environments.

## Scripts

### `init.ps1`

Installs required test dependencies:

- **Pester** (5.2+): PowerShell testing framework
- **PSScriptAnalyzer** (1.17+): PowerShell linting tool

```powershell
pwsh -File tests/bin/init.ps1
```

### `test.ps1`

Generic test runner that executes Pester tests with configurable options.

**Parameters:**

- `-TestPath`: **(Required)** Path(s) to test file(s) or directory. Accepts single path or array of paths.
- `-ReportPath`: Path for JUnit XML report (default: `tests/out/TestResults.xml`)
- `-Verbosity`: Output verbosity - None, Normal, Detailed, Diagnostic (default: Detailed)
- `-Filter`: Tag filter for selective test execution

**Examples:**

```powershell
# Run specific test file
pwsh -File tests/bin/test.ps1 -TestPath tools/pslib/utils.Tests.ps1

# Run with normal verbosity
pwsh -File tests/bin/test.ps1 -TestPath tools/pslib/utils.Tests.ps1 -Verbosity Normal

# Run tests from multiple paths
pwsh -File tests/bin/test.ps1 -TestPath @("tools/pslib/utils.Tests.ps1", "tools/pslib")

# Run all tests in a directory
pwsh -File tests/bin/test.ps1 -TestPath tools
```

### `test-all.ps1`

Convenience script that runs all tests in the `tools` directory with detailed output. This is a wrapper around `test.ps1` with pre-configured settings.

**Examples:**

```powershell
# Run all tests in the tools directory
pwsh -File tests/bin/test-all.ps1
```

### `test-pslib.ps1`

Convenience script specifically for running PowerShell library tests (`tools\pslib\utils.Tests.ps1`).

**Parameters:**

- `-Verbosity`: Output verbosity - None, Normal, Detailed, Diagnostic (default: Detailed)
- `-CI`: Run in CI mode with minimal output

**Examples:**

```powershell
# Run pslib tests with detailed output
pwsh -File tests/bin/test-pslib.ps1

# Run with normal verbosity
pwsh -File tests/bin/test-pslib.ps1 -Verbosity Normal

# Run in CI mode
pwsh -File tests/bin/test-pslib.ps1 -CI
```

## CI Integration

### GitHub Actions Example

```yaml
- name: Install test dependencies
  run: pwsh -File tests/bin/init.ps1

- name: Run all tests
  run: pwsh -File tests/bin/test-all.ps1

# Or run specific tests
- name: Run pslib tests
  run: pwsh -File tests/bin/test-pslib.ps1 -CI

- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: tests/out/TestResults.xml
```

### Azure Pipelines Example

```yaml
- task: PowerShell@2
  displayName: 'Install dependencies'
  inputs:
    filePath: 'tests/bin/init.ps1'
    pwsh: true

- task: PowerShell@2
  displayName: 'Run all tests'
  inputs:
    filePath: 'tests/bin/test-all.ps1'
    pwsh: true

# Or run specific tests
- task: PowerShell@2
  displayName: 'Run pslib tests'
  inputs:
    filePath: 'tests/bin/test-pslib.ps1'
    arguments: '-CI'
    pwsh: true

- task: PublishTestResults@2
  condition: always()
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: 'tests/out/TestResults.xml'
```

## Test Output

Tests generate a JUnit XML report at `tests/out/TestResults.xml` which can be:

- Published to CI/CD systems (GitHub Actions, Azure Pipelines, Jenkins, etc.)
- Viewed in test result viewers
- Parsed by test reporting tools

## Exit Codes

All test scripts exit with the number of failed tests:

- `0`: All tests passed
- `> 0`: Number of failed tests

This makes them suitable for CI/CD pipelines that check exit codes.

## Requirements

- PowerShell 5.1 or later
- Internet connection (for initial dependency installation)
- Pester 5.2+ (installed automatically by `init.ps1`)
