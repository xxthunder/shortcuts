# GitHub Copilot Instructions

For detailed development guidelines and coding standards for this project, please refer to:

- **[AGENTS.md](../AGENTS.md)** - Main development guidelines for the Shortcuts project
- **[tools/pslib/AGENTS.md](../tools/pslib/AGENTS.md)** - PowerShell library development guidelines
- **[tools/pslib/CLAUDE.md](../tools/pslib/CLAUDE.md)** - Library-specific Claude instructions

## Quick Reference

### Coding Guidelines
- Test-Driven Development (TDD)
- DRY (Don't Repeat Yourself)
- SOLID principles
- Conventional commits

### PowerShell Best Practices
- Use existing library functions from `tools/pslib/` before writing new code
- Always include robust error handling with `Set-StrictMode` and `$ErrorActionPreference = "Stop"`
- Make scripts CI-aware using `Test-RunningInCIorTestEnvironment`
- Include Pester tests for all PowerShell code
- Follow project-specific patterns for Scoop and Keypirinha integration

See the linked AGENTS.md files above for comprehensive guidelines.
