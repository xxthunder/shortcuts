# Agent Instructions for Shortcuts

## Overview

This document provides technical guidelines for AI agents working on the Shortcuts project. For user-facing documentation, see @README.md.

## Project Architecture

**Shortcuts** is a Windows automation project that provides CLI tools, shortcuts, and system utilities accessible through the Keypirinha launcher.

### Technical Stack

- **Language**: PowerShell 7.4+ (bootstrap scripts remain PS 5.1-compatible)
- **Package Manager**: Scoop (for Windows tools)
- **Launcher Integration**: Keypirinha (fast keyboard-driven launcher)
- **Testing**: Pester 5.7.1+
- **Linting**: PSScriptAnalyzer 1.24.0+

### Directory Structure

- `bin/`: Installation and update scripts
- `config/`: Configuration files
- `lib/`: Shared PowerShell library (reusable functions)
  - `utils/`: Utility functions (`utils.ps1`)
  - `wsl/`: WSL-specific functions (`wsl.ps1`, etc.)
  - `install/`: Installation utilities
- `tools/`: Tool-specific utilities and installers
  - `wsl-manager/`: WSL Manager entry point and integration tests
- `links/`: Keypirinha link definitions (.url files)
- `test/`: Test files and test utilities
- `.bootstrap/`: Bootstrap system for initial setup

#### PowerShell Script Wrapper Convention

**Executable PowerShell scripts should have a `.bat` wrapper in the same directory.**

This allows scripts to be executed directly from the command line or Keypirinha without requiring the full `pwsh -File` syntax.

**Example:**

```text
tools/wsl-manager/
├── wsl-manager.ps1      # The actual PowerShell script
└── wsl-manager.bat      # Wrapper that calls: pwsh -ExecutionPolicy Bypass -File %~dp0wsl-manager.ps1 %*
```

**Benefits:**

- Users can run `wsl-manager` instead of `pwsh -File path/to/wsl-manager.ps1`
- Batch wrapper handles PowerShell execution policy
- Arguments are passed through automatically via `%*`
- Consistent user experience across all executable scripts

## Documentation Hierarchy

- Each tool gets one doc (e.g., `wsl-manager.md`). Supported workflows like DevContainer setup belong as a section within the tool's doc, not as standalone guides.
- **Don't let a feature outgrow its tool** - DevContainer support is a feature of WSL Manager, not a separate product.

### Writing Style

- **No em-dashes** (`—`) in any `.md` file. Use a colon (`:`) to introduce explanations, a semicolon (`;`) to join independent clauses, or a normal dash (`-`) for asides and parenthetical remarks.

## Backlog Lifecycle

**A backlog item is the single canonical artifact for a unit of work, and it MUST exist before any design or implementation begins.** If work is requested for which no backlog item exists, create the item first (next `SC-###`, status **Open** or **In Progress**, added to the README index) and capture the design *in that item* (Summary, Description, Scope Decisions, Acceptance Criteria, UAT Procedure). Do NOT create a separate design/spec document that duplicates the backlog item; the backlog item is the design of record. Reserve standalone design docs (e.g. under `docs/architecture/`) for genuinely large, multi-item efforts (epics), and link them from the item rather than duplicating its acceptance criteria.

When starting work on a backlog item, update its status to **In Progress** and move it in the README index before committing implementation changes. When a subtask or the full item is completed, update status accordingly per the closing checklist in `docs/backlog/README.md`. Backlog updates are part of the implementation commit, not a separate afterthought.

## Coding Guidelines

- TDD
- DRY
- SOLID
- boundary checks
- equivalence classes
- error handling
- parametrized tests
- test fixtures
- mocking external dependencies
- conventional commits

### Linting Suppression Policy

**Never suppress these rules; fix the code instead:**
- `PSReviewUnusedParameter`: make the parameter actually used, or remove it.
- `PSUseSingularNouns`: rename the function to use a singular noun (PowerShell convention: `Verb-SingularNoun`).

### No Speculative Alternatives

**Issue**: Building alternative/fallback approaches that weren't requested.

**Guideline**: Implement exactly what was requested. Do NOT create "alternative approaches", "backward compatibility" paths, or "optional fallback" mechanisms unless the user explicitly asks for them. One clean solution is better than two competing ones.

**Anti-pattern**:
```
# DON'T: Build two competing approaches "in case the user prefers one"
# DON'T: Create a migration path from an approach that was never shipped
```

**When to apply**: Always. If you think an alternative approach might be useful, mention it in conversation instead of building it.

## PowerShell Implementation Guidelines

### Core Principles

When working with PowerShell code in this project, follow these guidelines:

#### 1-2, 4, 7, 9. Script structure, library usage, error handling, environment awareness, external commands

For PowerShell script structure, library discovery (`lib/`), error handling, CI/interactive awareness, and external-command execution (`Invoke-CommandLine`), see the `powershell-dev` skill (`.claude/skills/powershell-dev/`).

#### 3. File Encoding

**All `.ps1` files must be saved as UTF-8 with BOM** (Byte Order Mark).

PSScriptAnalyzer enforces `PSUseBOMForUnicodeEncodedFile`; any `.ps1` file containing non-ASCII characters (e.g., em dashes, accented letters, Unicode symbols) without a UTF-8 BOM will fail linting. To avoid issues, **always save `.ps1` files with BOM**, regardless of whether they currently contain non-ASCII characters.

This applies only to `.ps1` files. Other file types (`.sh`, `.yml`, `.json`, `.md`, `.bat`) should remain UTF-8 without BOM, as BOM can cause problems in those formats.

#### 3a. Line Endings

This project uses `autocrlf=false` and `safecrlf=true` (always). Git will **not** auto-convert line endings; `.gitattributes` defines the rules, but files must have correct line endings **before** `git add`:

- `.sh`, `.bash`: **LF** (`eol=lf` in `.gitattributes`) - required for WSL/Linux execution
- `.ps1`, `.psm1`, `.psd1`, `.bat`, `.cmd`, `.md`: **CRLF** (`eol=crlf` in `.gitattributes`)

**AI agents**: the `create` tool writes CRLF on Windows. After creating `.sh` files, convert line endings to LF before staging. For example:

```powershell
$content = Get-Content -Raw 'path/to/script.sh'
$content = $content -replace "`r`n", "`n"
[System.IO.File]::WriteAllText('path/to/script.sh', $content, [System.Text.UTF8Encoding]::new($false))
```

#### 5. Path Handling

Resolve paths via `$PSScriptRoot`/`Join-Path` and validate with `Test-Path` before use.

#### 6. Output and Logging

Use the `Write-Status`/`Write-Success`/`Write-ErrorMsg` helpers already defined in `lib/utils/utils.ps1` for user-facing output.

#### 8. PowerShell Command Execution from Bash

**Issue**: Mixing Bash and PowerShell pipelines causes errors.

**Guideline**: NEVER pipe PowerShell output to PowerShell cmdlets through Bash.

**Anti-pattern** (what NOT to do):
```bash
# DON'T: This fails because Select-String is not a Bash command
powershell -File script.ps1 | Select-String -Pattern "foo"

# DON'T: This also fails
pwsh -Command "Get-Content file.txt" | Select-String "pattern"
```

**Correct patterns**:

```bash
# Option 1: Keep everything in PowerShell
pwsh -Command "powershell -File script.ps1 | Select-String -Pattern 'foo'"

# Option 2: Use Bash-native tools
powershell -File script.ps1 | grep "foo"

# Option 3: Use Read tool to read PowerShell output, then process
# (Preferred for AI agents - saves output to file first)
```

**When to use each**:
- **Option 1**: When you need PowerShell cmdlet features (objects, -Context, etc.)
- **Option 2**: When simple text matching is sufficient
- **Option 3**: When processing large outputs or need to reference multiple times

#### 9. Script Structure

**IMPORTANT: Set-StrictMode in Dot-Sourced Files**

- **Standalone executable scripts** (e.g., `install.ps1`, `wsl-manager.ps1`): **Use `Set-StrictMode -Version Latest`**
- **Dot-sourced library files** (e.g., `utils.ps1`, `wsl.ps1`, `setProxy.ps1`): **DO NOT use `Set-StrictMode`**

**Reason**: When a script is dot-sourced (`. .\script.ps1`), `Set-StrictMode` persists in the caller's scope and affects all subsequent code in that PowerShell session. This can break other scripts that weren't written to handle strict mode, especially when sourced into PowerShell profiles.

For the standalone and dot-sourced file templates, see the `powershell-dev` skill.

### Testing Requirements

All PowerShell code must include **Pester tests**.

**For comprehensive Pester test execution guidance, use the `powershell-test-exec` skill** (`.claude/skills/powershell-test-exec/`).

The skill covers:

- Running unit tests (`-Unit`), integration tests (`-Integration`), and coverage (`-Coverage`)
- PowerShell 7.4+ test execution
- AI agent patterns for calling PowerShell from Bash
- GitHub Actions CI/CD patterns
- TDD workflow and pre-commit checks

#### Quick Reference

```bash
# Unit tests (fast feedback)
pwsh -File ".\test\bin\testrunner.ps1" -Unit

# Integration tests
pwsh -File ".\test\bin\testrunner.ps1" -Integration

# All tests with coverage
pwsh -File ".\test\bin\testrunner.ps1" -Coverage

# Bootstrap script (PS 5.1 only - install.ps1 and .bootstrap/ scripts)
powershell -File ".\bin\install.ps1"
```

**Test types:**

- `*.Tests.ps1` - Unit tests (mocked dependencies)
- `*.Integration.Tests.ps1` - Integration tests (real systems)

**Testing requirements:**

- Mock external dependencies
- Test both success and failure paths
- Ensure tests pass on PowerShell 7.4+

**Never mock `Test-RunningInCIorTestEnvironment` in integration tests.**
This function exists to prevent interactive prompts (`Read-Host`) in CI/test environments.
Mocking it to `$false` in integration tests would trigger real `Read-Host` calls that hang CI.
In **unit tests**, mocking it is allowed and encouraged to cover both CI and interactive code paths.

**Cross-file test isolation (MANDATORY):**
Pester runs all test files in the same PowerShell process. Functions loaded via dot-sourcing
persist across files and cause flaky, order-dependent failures. Every test file that
dot-sources a library **must** use `Start-SutIsolation`/`Stop-SutIsolation` from `test/bin/lib/TestIsolation.ps1`:

```powershell
BeforeAll {
    . "$PSScriptRoot\..\..\test\bin\lib\TestIsolation.ps1"
    Start-SutIsolation
    . "$PSScriptRoot\module.ps1"
}

AfterAll {
    Stop-SutIsolation
}
```

See `lib/AGENTS.md` for additional testing guidelines

### Project-Specific Considerations

#### Scoop Integration

This project heavily uses Scoop for package management:

- Check for Scoop before using it
- Use `scoop install`, `scoop update`, `scoop list`
- Reference `scoopfile.json` for managed packages
- Use `Invoke-CommandLine` for all Scoop commands (see "External Commands" section)

#### Keypirinha Integration

Scripts that add/modify shortcuts should remind users to refresh the Keypirinha catalog:

```powershell
Write-Host "Remember to refresh Keypirinha catalog (see README.md for details)" -ForegroundColor Yellow
```

#### Bootstrap System

The project uses a `.bootstrap` system (see `.bootstrap/` directory):

- Handles initial setup
- Manages dependencies
- Keep bootstrap scripts independent from main tools

### Workflow

#### CI and Branch Hygiene

**Context**: This project uses GitHub Actions CI. The `develop` branch is always green.

**CRITICAL: There are no pre-existing test failures. Ever.** CI ensures `develop` is always green. Feature branches are created from `develop`. Therefore, any failure on a feature branch was introduced by that branch; no exceptions.

**You MUST NOT:**
- Dismiss failures as "pre-existing" or "unrelated to my changes"
- Skip failing tests or proceed to commit with uninvestigated failures
- Assume that tests in files you didn't directly modify can't be affected by your changes

**You MUST:**
- Investigate every failure - even in files you didn't touch
- If uncertain whether your changes caused it, flag it to the user - never silently skip
- Fix the issue before proceeding

**Investigation steps**:
1. `git diff develop..HEAD`: review ALL changes on the branch
2. Analyze if ANY change (even cosmetic ones like string formatting) could affect tests
3. If uncertain, use `git bisect` to identify the breaking commit

**Anti-pattern**:
```bash
# DON'T: Assume failures are unrelated
"These test failures are pre-existing, not caused by my bullet point change"
```

**Correct pattern**:
```bash
# DO: Investigate if your changes could be the cause
git diff develop..HEAD  # Review ALL changes
git log develop..HEAD   # Review ALL commits on branch
# Even cosmetic changes to test files can break things
```

#### Docs-Only Changes May Land Directly on `develop`

**Context**: `develop` is a protected ref (PR required, 2 status checks). The repository owner has bypass rights and uses them intentionally for documentation-only changes.

A change is **docs-only** when every file in the diff is a `.md` file under `docs/` or the repository root. Anything else - `.ps1`, `.psm1`, `.psd1`, `.bat`, `.cmd`, `.sh`, `.yml`, `.json`, `.gitattributes` - disqualifies it, however small the edit.

For a docs-only change:

- Commit and push straight to `develop`; no feature branch, no PR.
- The unit-test suite and PSScriptAnalyzer may be skipped: no file in their input changed. Say so explicitly in the report rather than implying they passed.
- CI still runs (`test.yml` triggers on `push` to `main` and `develop`), so a docs-only push is still covered; it just is not gated pre-merge.

The push prints `Cannot update this protected ref` alongside a successful ref update. That is expected for the owner. **Verify the push landed** (`git fetch origin develop`, then compare `origin/develop` to `HEAD`) instead of reading the push output, which is ambiguous.

Contributors without bypass rights must use a pull request for documentation too.

#### GitHub Actions Shell

The CI workflow no longer uses a matrix (only one shell: `pwsh`). Steps use `shell: pwsh` directly, except the "Remote install" step which uses `shell: powershell` to simulate a fresh machine running `install.ps1` under Windows PowerShell 5.1.

#### CI Environment: Never Assume, Always Verify

**Issue**: Fabricating claims about what is or isn't available in CI without checking.

**Context**: The CI runner is a full Windows machine with WSL, PwshSpectreConsole, Scoop, and all project dependencies. `install.ps1` installs production dependencies; `test/bin/init.ps1` installs test dependencies (Pester, PSScriptAnalyzer) and runs `wsl --update`. All 1000+ tests run with 0 skipped.

**Guideline**: Before making any claim about the CI environment (what's installed, what's available, what's skipped), read `test.yml`, `init.ps1`, and `install.ps1`. Trust CI test results over assumptions. If CI reports 0 skipped, nothing is skipped.

**You MUST NOT:**
- Assume standard GitHub Actions limitations apply (e.g., "WSL isn't available") without checking
- Invent plausible-sounding explanations for test behavior without verifying
- Add defensive stubs or skip-guards for dependencies that are actually installed in CI
- Double down on wrong assumptions when challenged; re-investigate instead

**You MUST:**
- Read the CI workflow and setup scripts before claiming anything about the CI environment
- When CI results contradict your mental model, trust the data
- Say "I don't know" rather than fabricate an explanation

#### Backlog Conventions

Backlog structure and format are defined by the `refinement` skill (from the `xxthunder-dev-skills` plugin). See `docs/backlog/README.md` for the TOC and notes.

- **No unrelated files in feature commits**: keep commits scoped to the feature; unrelated additions get their own commit.
- **Always update backlog with every commit**: move item to IN PROGRESS at start, check off acceptance criteria as they're completed, move to DONE when finished. Backlog updates go in the same commit as the code.

#### Communication

- **Problem statements are not build directives**: when the user describes a problem or goal, ask what approach they want before implementing. Especially for changes to shared infrastructure (hooks, CI, config) that affect all contributors.

#### Windows/Git Bash Pitfalls

- **NUL vs /dev/null**: On Windows under Git Bash/MSYS2, redirecting to `NUL` creates a literal file named `nul`. Always use `/dev/null` in Bash contexts.

#### When to Use EnterPlanMode (MANDATORY)

**ALWAYS use EnterPlanMode before implementation when:**

1. **User says "review" or "plan"** - They explicitly want exploration, not implementation
2. **Backlog items** - Items in `docs/backlog/` require architectural understanding before coding
3. **New features** - Adding functionality, not just fixing bugs
4. **Architectural decisions** - Unclear where functionality belongs in existing structure
5. **"Belongs to" questions** - When you're unsure which module/function should own the code

**Red flags that require planning first:**
- "Where should this go?"
- "Does this already exist somewhere?"
- "Is this related to [existing feature]?"
- Any uncertainty about architecture, ownership, or approach

**Anti-pattern (what NOT to do):**
```
User: "Review FEAT-001 for DevContainer prep"
Agent: *immediately creates new functions and commits*
```

**Correct pattern:**
```
User: "Review FEAT-001 for DevContainer prep"
Agent: *uses EnterPlanMode to explore architecture, understand relationships,
        propose whether this is new feature vs. enhancement to existing*
```

**Enforcement**: When in doubt, ALWAYS prefer planning over immediate implementation. Use EnterPlanMode proactively to avoid architectural misalignment.

#### When Implementing or Modifying PowerShell Functionality

For the step-by-step new-functionality and modify-existing-function workflows, see the `powershell-dev` skill.

> **Backlog tracking is mandatory**: see Development Workflow in `docs/development-principles.md` for the full start/finish protocol.

**CRITICAL: Never modify implementation without updating tests, and never commit tests separately from the implementation they cover.**

#### Mandatory Pre-Commit Checks

**Before every commit, you MUST run unit tests (and integration tests if you touched integration points) via the `powershell-test-exec` skill, and PSScriptAnalyzer must be clean.**

**Never commit if:**

- Any unit test fails
- Any integration test fails
- You changed a function but didn't update its tests
- You're unsure if tests cover your changes

### Code Review Checklist

When reviewing code, verify adherence to:

- **Guidelines**: TDD, DRY, SOLID principles (see "Coding Guidelines")
- **Structure**: Script structure, error handling, pslib usage (see "Core Principles")
- **Testing**: Pester tests with proper mocking (see "Testing Requirements")
- **Security**: No hardcoded secrets, proper input validation
- **Documentation**: Clear comments, synopsis/examples in headers
- **Integration**: Conventional commits, Keypirinha compatibility

Provide specific feedback with `file:line` references.

### Shared Skills Plugin

This project uses the [xxthunder/xxthunder-agentic-skills](https://github.com/xxthunder/xxthunder-agentic-skills) plugin for shared skills (refinement, commit-helper, tdd-workflow, retrospective). The plugin is loaded automatically:

- **Locally**: installed to `~/.claude/plugins/` via `claude plugins add`
- **GitHub Actions**: configured via the `plugins` input in `.github/workflows/claude.yml`

### Reference Documentation

For core development principles and quality gates:

- `docs/development-principles.md`: Core principles (TDD, error handling, environment awareness, etc.)

For detailed PowerShell library guidelines:

- `lib/AGENTS.md`: In-depth PowerShell development guide

For project documentation:

- `docs/wsl-manager.md`: WSL Manager consolidated specification
- `README.md`: User-facing installation and usage guide
- `bin/install.ps1`: Main installation entry point
