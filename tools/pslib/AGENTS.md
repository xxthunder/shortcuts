# Agent Instructions for PowerShell Library

## Purpose

This document provides guidance for AI agents working with the PowerShell library in the shortcuts project.

## Context Understanding

Before modifying any PowerShell code in this directory:

1. Read `*.ps1` to understand existing patterns
2. Check how library functions are used in parent directories
3. Understand the CI vs interactive environment distinction

## Task-Specific Guidelines

### When Adding New Functions

- Search codebase for similar functionality first (avoid duplication)
- Follow the established pattern in `*.ps1`
- Use the Task tool with subagent_type=Explore to understand usage patterns
- Ensure new functions are general-purpose, not task-specific

### When Modifying Existing Functions

- Use Grep to find all usages across the codebase first
- Test changes won't break existing callers
- Maintain backward compatibility unless explicitly requested
- Consider impact on both CI and interactive environments

### When Debugging PowerShell Issues

- Check `$global:LASTEXITCODE` handling
- Verify PATH environment variable state
- Review error handling in `Invoke-CommandLine`
- Consider whether issue is environment-specific (CI vs local)

### PowerShell-Specific Considerations

- Respect PowerShell suppression attributes (they're there for a reason)
- Don't remove error handling without understanding implications
- Be careful with `Invoke-Expression` - security implications exist
- Test path operations with both files and directories

## Common Tasks

### Researching Usage

- Use Grep to find: ". .*pslib.*.ps1" (sourcing pattern)
- Use Grep to find specific function calls: "Invoke-CommandLine|New-Directory|etc."

### Understanding Flow

1. Scripts source .ps1 files with dot-sourcing: `. "$PSScriptRoot\pslib\<someFile>.ps1"`
2. Functions become available in script scope
3. Functions handle both CI and interactive scenarios

### Error Investigation

- Check if `$StopAtError` is set correctly
- Verify exit codes are being checked
- Look for silent execution suppressing important errors
- Review `Write-Error` vs `Write-Output` usage

## Integration Points

- These utilities are sourced by scripts in any directory of this repository
- Functions should remain stateless where possible
- Environment variables (PATH) are managed through these utilities
- User interaction is abstracted through `Get-UserConfirmation`

## Development Principles

### Testing Framework: Pester

All PowerShell code in this library must be tested using **Pester**, the standard testing framework for PowerShell.

#### Pester Basics

- **Installation**: Pester should be installed via `Install-Module -Name Pester -Force -SkipPublisherCheck` or by running `.\test\bin\init.ps1`
- **Test files**: Name test files with `.Tests.ps1` suffix (e.g., `utils.Tests.ps1`)
- **Location**: Place tests in the same directory as the code or in a dedicated `tests` subdirectory
- **Running tests**:
  ```powershell
  # Run all tests (recommended)
  pwsh -File .\test\bin\test.ps1

  # Run specific test file
  Invoke-Pester -Path .\path\to\script.Tests.ps1

  # Test on PowerShell 5.1 for compatibility
  powershell -File .\test\bin\test.ps1
  ```

#### Pester Test Structure

```powershell
Describe "Function-Name" {
    Context "When condition or scenario" {
        It "Should do expected behavior" {
            # Arrange
            $input = "test"

            # Act
            $result = Function-Name -Parameter $input

            # Assert
            $result | Should -Be "expected"
        }
    }
}
```

#### Mocking in Pester

- Use `Mock` to replace external dependencies
- Example: `Mock Test-Path { return $true }`
- Verify mocks were called: `Should -Invoke Test-Path -Times 1`
- Mock environment variables: `Mock Get-Item { @{ Value = "mocked" } } -ParameterFilter { $Path -eq "Env:\VARIABLE" }`

#### Best Practices

- Test both success and failure paths
- Mock all external dependencies (file system, environment, external commands)
- Use `BeforeAll` and `AfterAll` for setup/teardown
- Use `BeforeEach` and `AfterEach` for per-test setup/teardown
- Test CI and interactive environment behavior separately
- Use `-ParameterFilter` to mock specific scenarios
- **Verify tests pass on both PowerShell 5.1 and 7.x** before committing

#### PowerShell Version Compatibility

**IMPORTANT**: All code must be compatible with **PowerShell 5.1** and **PowerShell 7.x**.

**Common compatibility issues to avoid:**

- ❌ **`ErrorMessage` parameter in `ValidateScript`** (PowerShell 6.0+ only)
  ```powershell
  # WRONG - Only works in PowerShell 6.0+
  [ValidateScript({ $_ -gt 0 }, ErrorMessage = "Must be positive")]

  # CORRECT - Works in PowerShell 5.1+
  [ValidateScript({ $_ -gt 0 })]
  ```

- ❌ **Ternary operator** `? :` (PowerShell 7.0+ only)
  ```powershell
  # WRONG - Only works in PowerShell 7.0+
  $result = $condition ? "yes" : "no"

  # CORRECT - Works in PowerShell 5.1+
  $result = if ($condition) { "yes" } else { "no" }
  ```

- ❌ **Null-coalescing operators** `??`, `??=` (PowerShell 7.0+ only)

**Testing on both versions:**

Always run tests on both PowerShell versions before creating a pull request:

```powershell
# Test on PowerShell 7.x
pwsh -File .\test\bin\test.ps1

# Test on PowerShell 5.1
powershell -File .\test\bin\test.ps1
```

The CI pipeline runs tests on both versions and will fail if either version encounters errors.

### Test-Driven Development (TDD)

When creating or modifying PowerShell functions:

1. **Write tests first**: Create Pester tests before implementing functionality
2. **Red-Green-Refactor cycle**:
   - Write a failing test (Red)
   - Implement minimum code to pass (Green)
   - Refactor while keeping tests green
3. **Test coverage**: Ensure tests cover:
   - Normal operation paths
   - Error conditions and edge cases
   - CI vs interactive environment behavior
   - Both file and directory operations (where applicable)
4. **Mock external dependencies**: Use Pester mocking for system calls, file operations, and environment variables
5. **Test naming**: Use descriptive test names that explain the scenario being tested

### SOLID Principles (Adapted for PowerShell)

#### Single Responsibility Principle (SRP)

- Each function should do one thing well
- `Invoke-CommandLine` executes commands, `New-Directory` creates directories
- If a function needs many parameters or does multiple unrelated things, split it

#### Open/Closed Principle (OCP)

- Functions should be open for extension, closed for modification
- Use parameters with defaults to allow behavior customization
- Example: `$StopAtError`, `$PrintCommand`, `$Silent` in `Invoke-CommandLine`
- Add optional parameters rather than modifying existing behavior

#### Liskov Substitution Principle (LSP)

- Functions with similar purposes should have consistent interfaces
- Path operations (`Remove-Path`, `New-Directory`) should handle paths consistently
- Return types and error handling should be predictable

#### Interface Segregation Principle (ISP)

- Don't force callers to depend on parameters they don't use
- Use `[Parameter(Mandatory = $false)]` appropriately
- Provide sensible defaults so simple use cases remain simple
- Example: `Get-UserConfirmation` has optional `$defaultValueForUser` and `$valueForCi`

#### Dependency Inversion Principle (DIP)

- Depend on abstractions, not concretions
- Use `Test-Path` rather than checking `$null` or catching exceptions
- Use `Test-RunningInCIorTestEnvironment` rather than checking specific env vars directly
- Abstract platform-specific operations behind generic function names

### Applying Principles Together

When adding new functionality:

1. Write Pester tests first (TDD)
2. Ensure function has single, clear purpose (SRP)
3. Use parameters for extensibility (OCP)
4. Follow established patterns for consistency (LSP)
5. Keep interfaces minimal and optional (ISP)
6. Abstract environment/platform specifics (DIP)
