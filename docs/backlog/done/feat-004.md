# [FEAT-004] ✅ COMPLETED - Replace Bootstrap with Self-Contained install.ps1

**Status**: Completed (2026-02-11)
**Priority**: Medium
**Component**: `bin/install.ps1`, `scoop_mandatory.json`, `scoop_optional.json`
**Type**: Feature / Refactoring
**Absorbs**: DEBT-001 (Bootstrap removal)

**Description**:
Replaced external `avengineers/bootstrap` dependency with a self-contained `install.ps1`. Two modes (remote via `irm | iex`, local via `-InPlace`), mandatory/optional tool split, dot-sourceable functions.

**Implementation**:
- Rewrote `bin/install.ps1` with remote/local mode detection via `$PSScriptRoot`
- Created `scoop_mandatory.json` (keypirinha + extras bucket)
- Created `scoop_optional.json` (pwsh, windows-terminal, ditto, winmerge, sysinternals, vscode, autohotkey)
- Removed `scoopfile.json` and all `avengineers/bootstrap` references
- Exposed functions: `Install-Scoop`, `Install-ScoopDependency`, `Install-Git`, `Install-MandatoryToolset`, `Install-OptionalToolset`
- Unit tests covering all functions, dot-source support, JSON validation
- Removed `.bootstrap` from `.gitignore`
