# Shortcuts - Development Principles

**Version**: 1.0.0 | **Created**: 2026-01-12 | **Adapted**: 2026-01-28

This document defines the core principles for developing the Shortcuts project. These principles ensure code quality, maintainability, and consistency across the codebase.

> **Note**: This document covers *how* we develop code. For *what* we plan to build, see:
> - `docs/roadmap.md` - High-level vision and planned features
> - `docs/backlog.md` - Detailed backlog of tasks and improvements

---

## Core Principles

### I. Test-First Development (NON-NEGOTIABLE)

**TDD is mandatory for all PowerShell code in this project.**

- Tests MUST be written BEFORE implementation (Red-Green-Refactor cycle)
- Unit tests (`*.Tests.ps1`) MUST pass before committing
- Integration tests (`*.Integration.Tests.ps1`) MUST pass for modified integration points
- When modifying existing functions, tests MUST be updated first to reflect new behavior
- Tests and implementation MUST be committed together - never separately

**Rationale**: TDD ensures code correctness, prevents regressions, and maintains high code quality. The strict test-first approach prevents technical debt and ensures all code is testable by design.

### II. Library-First Architecture

**All reusable functionality MUST be implemented as library functions in `tools/pslib/`.**

- Library functions MUST be self-contained and independently testable
- Before writing new code, MUST check existing library functions in `tools/pslib/utils/` and `tools/pslib/wsl/`
- Executable scripts MUST have `.bat` wrapper for command-line accessibility
- External command execution MUST use `Invoke-CommandLine` from pslib

**Rationale**: Promotes code reusability, reduces duplication, and ensures consistent behavior across all scripts. Centralized utilities are easier to test, maintain, and improve.

### III. PowerShell Standards

**All PowerShell code MUST adhere to project coding standards.**

- MUST use PowerShell 5.1+ compatible syntax (no PowerShell 6.0+ exclusive features)
- MUST pass PSScriptAnalyzer checks (Error/Warning severity)
- MUST include proper help documentation (SYNOPSIS, DESCRIPTION, EXAMPLE)
- MUST follow standard script structure with `#Requires -Version 5.1`
- MUST use `[CmdletBinding()]` and proper parameter declarations

**Rationale**: Ensures compatibility across Windows PowerShell 5.1 and PowerShell 7.x environments, maintains code quality, and provides consistent user experience.

### IV. Error Handling & Robustness

**All scripts MUST implement robust error handling.**

- MUST set `Set-StrictMode -Version Latest`
- MUST set `$ErrorActionPreference = 'Stop'`
- MUST use try/catch blocks for main logic
- MUST provide clear, user-friendly error messages
- MUST validate paths and inputs before use
- MUST check for dependencies (e.g., Scoop availability) before executing commands

**Rationale**: Prevents silent failures, provides actionable error information, and ensures scripts fail fast with clear diagnostics.

### V. Environment Awareness

**Scripts MUST work correctly in both interactive and CI/test environments.**

- MUST use `Test-RunningInCIorTestEnvironment` to detect execution context
- MUST provide non-interactive paths for CI/automated scenarios
- MUST provide interactive prompts for user-driven scenarios
- MUST mock external dependencies in tests (file system, commands, environment variables)
- MUST test both CI and interactive behavior paths separately

**Rationale**: Ensures scripts work reliably in automated pipelines and manual execution, preventing CI failures and improving user experience.

### VI. Code Reusability (DRY)

**Don't Repeat Yourself - reuse existing code and patterns.**

- MUST check `tools/pslib/` for existing functionality before implementing
- MUST extract common patterns into library functions
- MUST follow SOLID principles in code design
- MUST avoid duplicating functionality across scripts
- MUST use parameterized tests and test fixtures to reduce test duplication

**Rationale**: Reduces maintenance burden, ensures consistent behavior, and makes the codebase easier to understand and modify.

### VII. Documentation & Traceability

**Code changes MUST be documented and traceable.**

- MUST use conventional commits (feat, fix, refactor, test, docs, chore)
- MUST include clear commit messages explaining "why" not just "what"
- MUST reference file:line in code reviews and discussions
- MUST update documentation when changing functionality
- MUST remind users to refresh Keypirinha catalog when adding/modifying shortcuts

**Rationale**: Maintains project history, enables effective code review, and ensures users understand how to use new features.

---

## Development Workflow

**All code changes MUST follow this workflow:**

1. **Research**: Check if functionality exists in `tools/pslib/` or other scripts
2. **Design**: Plan the script structure and identify reusable components
3. **Test First**: Write Pester tests before implementation (Red phase)
4. **Implement**: Write the PowerShell script following guidelines (Green phase)
5. **Test Again**: Verify all tests pass (Red-Green-Refactor complete)
6. **Pre-Commit Validation**: Run unit tests and integration tests
7. **Document**: Add comments and help documentation
8. **Commit Together**: Tests and implementation in same commit

**Critical checkpoint**: NEVER modify implementation without updating tests first.

---

## Quality Gates

**Before any commit, ALL of these gates MUST pass:**

### Unit Test Gate

```powershell
pwsh -File ".\test\bin\testrunner.ps1" -Unit
```

All unit tests MUST pass.

### Integration Test Gate (if integration points modified)

```powershell
pwsh -File ".\test\bin\testrunner.ps1" -Integration
```

All integration tests MUST pass.

### Linter Gate

PSScriptAnalyzer checks are automatically included in test suite. Code MUST have no Error or Warning severity violations.

### Compatibility Gate

Tests MUST pass on both PowerShell 5.1 and PowerShell 7.x:

```powershell
# PowerShell 7.x
pwsh -File ".\test\bin\testrunner.ps1"

# PowerShell 5.1
powershell -File ".\test\bin\testrunner.ps1"
```

---

## Reference Documentation

For detailed technical implementation guidance:
- `AGENTS.md` - Project-wide development guidelines
- `tools/pslib/AGENTS.md` - PowerShell library-specific guidance
- `README.md` - User-facing installation and usage documentation
