---
name: powershell-test-exec
description: "This project's test execution skill. Execute Pester tests for PowerShell code. Use this skill when: (1) Running unit tests, (2) Running integration tests, (3) Running tests with code coverage, (4) Running tests on specific files or paths, (5) Executing pre-commit test checks, (6) Troubleshooting test failures, or any testing task. Generic workflow skills (commit-helper, tdd-workflow) delegate test execution to this skill."
---

# Test Execution (Pester)

This project's test execution skill. Runs Pester tests for PowerShell code.

## CRITICAL: Always Use testrunner.ps1

**NEVER call `Invoke-Pester` directly.** Always use `testrunner.ps1` to run tests. The testrunner includes linting (PSScriptAnalyzer), JUnit report generation, and other checks that `Invoke-Pester` alone skips. Running `Invoke-Pester` directly will miss failures.

## Quick Reference

### Standard Test Commands

```bash
# Unit tests only (fast feedback)
pwsh -File ".\test\bin\testrunner.ps1" -Unit

# Integration tests only
pwsh -File ".\test\bin\testrunner.ps1" -Integration

# All tests (unit + integration)
pwsh -File ".\test\bin\testrunner.ps1"

# With code coverage
pwsh -File ".\test\bin\testrunner.ps1" -Coverage
pwsh -File ".\test\bin\testrunner.ps1" -Unit -Coverage
pwsh -File ".\test\bin\testrunner.ps1" -Integration -Coverage

# Specific test path
pwsh -File ".\test\bin\testrunner.ps1" -TestPath "lib\utils\utils.Tests.ps1"

```

### Test Types

| Type | Pattern | Purpose |
|------|---------|---------|
| Unit | `*.Tests.ps1` | Fast, isolated tests with mocked dependencies |
| Integration | `*.Integration.Tests.ps1` | Tests interacting with real systems (WSL, file system) |

## Development Workflow

### Local Development (Recommended)

1. Run unit tests first for fast feedback
2. Run integration tests when necessary or before committing
3. Both suites must pass before pushing

### Pre-Commit Checks (Mandatory)

Before every commit:

1. Run unit tests: `pwsh -File ".\test\bin\testrunner.ps1" -Unit`
2. Run integration tests if integration points were modified
3. Linting runs automatically with tests (PSScriptAnalyzer)

**Never commit if:**

- Any unit test fails
- Any integration test fails
- Function changes lack corresponding test updates

### TDD Workflow (Red-Green-Refactor)

1. Update tests to expect new behavior (Red)
2. Run tests - confirm they fail
3. Update implementation (Green)
4. Run tests - confirm they pass
5. Commit tests and implementation together

## Output and Reports

| Output | Location | Description |
|--------|----------|-------------|
| JUnit XML | `test/out/junit.xml` | Test results for CI |
| Coverage XML | `test/out/coverage.xml` | JaCoCo format coverage |

## Test Infrastructure

### testrunner.ps1 Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-Unit` | switch | Run only unit tests |
| `-Integration` | switch | Run only integration tests |
| `-Coverage` | switch | Enable code coverage |
| `-TestPath` | string[] | Custom paths to search |
| `-Verbosity` | string | Output verbosity (Detailed, Normal, Minimal) |
| `-Filter` | string | Pester tag filter |
| `-ExcludePattern` | string | Pattern to exclude files |

### init.ps1

Installs test dependencies:

- Pester 5.7.1+
- PSScriptAnalyzer 1.24.0+

Run before first test execution: `pwsh -File ".\test\bin\init.ps1"`

## PowerShell Version Compatibility

All tests require PowerShell 7.4+ (`pwsh`). Run tests with:

```bash
pwsh -File ".\test\bin\testrunner.ps1"
```

## AI Agent Patterns

See [references/ai-agent-patterns.md](references/ai-agent-patterns.md) for:

- Path quoting rules when calling PowerShell from Bash
- PowerShell piping patterns (avoid bash-to-PowerShell pipes)
- Error prevention guidelines

## Troubleshooting Test Failures

### CRITICAL: There Are No Pre-Existing Failures

**The `develop` branch is always green. CI enforces this. Therefore, any test failure on a feature branch was caused by that branch - no exceptions.**

**You MUST NOT:**
- Dismiss failures as "pre-existing" or "unrelated to my changes"
- Skip failing tests or proceed to commit with uninvestigated failures
- Assume that tests in files you didn't directly modify can't be affected by your changes

**You MUST:**
- Investigate every failure
- If uncertain whether your changes caused it, flag it to the user - never silently skip

### When Tests Fail on a Feature Branch

**If tests fail on your feature branch**:

1. **Your changes caused it** - Even "cosmetic" changes can break tests:
   - Encoding changes (UTF-8 BOM, line endings)
   - String formatting in test output
   - Import order changes
   - File renames affecting discovery

2. **Investigation steps**:
   ```bash
   # See all changes since branching from develop
   git diff develop..HEAD

   # See all commits on this branch
   git log develop..HEAD --oneline

   # Check if develop is still green
   git checkout develop
   pwsh -File ".\test\bin\testrunner.ps1" -Unit
   git checkout -  # Return to feature branch
   ```

3. **Common causes**:
   - File encoding issues (missing UTF-8 BOM)
   - Path separator issues (Windows vs Linux)
   - Module import order changes
   - Test discovery pattern changes

4. **If stuck**: Use `git bisect` to find the breaking commit
   ```bash
   git bisect start
   git bisect bad  # Current commit fails
   git bisect good develop  # develop is known good
   # Git will check out commits; run tests at each
   pwsh -File ".\test\bin\testrunner.ps1" -Unit
   git bisect good  # or bad, depending on result
   ```

## Stubbing External Modules in Unit Tests

When production code imports an external module at dot-source time (e.g., `Import-Module PwshSpectreConsole`), unit tests must prevent the real import while still providing the command names that Pester needs for `Mock` and `Should -Invoke`.

**Pattern**: A dedicated loader file (e.g., `spectre.ps1`) owns the module import, guarded by a command-existence check. Unit tests define lightweight stub functions in `BeforeAll` *before* dot-sourcing library files. The loader detects the stubs and skips the real import.

```powershell
# Unit test file (*.Tests.ps1)
BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation

    # Stubs: defined BEFORE dot-sourcing so the loader (spectre.ps1)
    # detects them and skips Import-Module.
    function Format-SpectreTable { param($Border, $Color) process { $_ } }
    function Format-SpectrePanel { param($Header, $Border) process { $_ } }

    . "$PSScriptRoot\production-file.ps1"   # loader sees stubs, skips real import
}
```

```powershell
# Loader file (e.g., lib/wsl/spectre.ps1)
# Stubs defined by unit tests make this check pass, skipping the import.
# Integration tests and production use have no stubs, so the real module loads.
if (Get-Command Format-SpectreTable -ErrorAction SilentlyContinue) {
    return
}
# ... install prompt (guarded for interactive use) ...
Import-Module PwshSpectreConsole -ErrorAction Stop
```

```powershell
# Production library file (e.g., commands.ps1, manager.ps1)
. "$PSScriptRoot\spectre.ps1"
```

**Key rules:**
- Stubs must be defined *before* the dot-source line
- Integration tests (`*.Integration.Tests.ps1`) must NOT define stubs; they test the full stack including real module imports
- The loader checks for a representative command, not for a test environment flag
- Each library that needs Spectre commands dot-sources the loader; the second call is a no-op since the commands already exist

## Advanced Workflows

See [references/workflows.md](references/workflows.md) for:

- Running specific test files
- Debugging test failures
- Pester test structure and mocking patterns
- Writing new tests (TDD approach)

## CI/CD Integration

See [references/github-actions.md](references/github-actions.md) for:

- GitHub Actions workflow patterns
- Matrix strategy for multiple PowerShell versions
- Shell selection limitations and workarounds
