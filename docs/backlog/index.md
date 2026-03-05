[← Back to README](../../README.md)

# Backlog

## Status Legend

- **IN PROGRESS** - Currently being worked on
- **TODO** - Ready to be picked up
- **DONE** - Completed

## Table of Contents

### In Progress
- [SC-001 — Backlog refinement](in_progress/sc-001.md)

### TODO
- [SC-002 — Add `shutdown` command to wsl-manager](todo/sc-002.md)
- [SC-003 — Stop action functions from reprinting distro table](todo/sc-003.md)
- [SC-005 — Move argument validation into action functions](todo/sc-005.md)
- [SC-006 — Scoop Update Helper Script](todo/sc-006.md)
- [SC-013 — Fix and enhance documentation](todo/sc-013.md)
- [SC-014 — setup-user CLI does not accept -Username and -Password parameters](todo/sc-014.md)
- [SC-015 — Reorganize project structure: separate tools from libraries](todo/sc-015.md)
- [SC-016 — Improve interactive menu UX: instant key input and Esc-to-menu](todo/sc-016.md)
- [SC-017 — Auto-terminate distros instead of prompting the user](todo/sc-017.md)

### Done
- [SC-011 — WSL Manager: mask credentials and auto-terminate after install](done/sc-011.md)
- [SC-012 — Stop-WslDistro: verify termination with retry](done/sc-012.md)
- [SC-010 — Review and enhance VS Code DevContainer Setup documentation](done/sc-010.md)
- [SC-004 — Consolidate documentation and make all docs reachable from README](done/sc-004.md)
- [SC-007 — Add `setup-proxy` action to wsl-manager](done/sc-007.md)
- [SC-008 — Split backlog into index and per-item files](done/sc-008.md)
- [SC-009 — PowerShell Lint Guard (skill + pre-commit hook)](done/sc-009.md)
- [FEAT-002 — Set up Podman as Docker alternative in WSL](done/feat-002.md)
- [REFACT-005 — Extract `Assert-WslDistroExists` guard (DRY)](done/refact-005.md)
- [REFACT-004 — Remove redundant `Test-WslInstalled` guard checks (DRY)](done/refact-004.md)
- [BUG-004 — Flaky integration test for terminating stopped distribution](done/bug-004.md)
- [CHORE-001 — Move reusable skills to global ~/.claude/skills](done/chore-001.md)
- [CI-003 — Normalize JaCoCo XML paths for Codecov](done/ci-003.md)
- [CI-002 — Normalize JUnit XML paths for Codecov](done/ci-002.md)
- [CI-001 — Upload code coverage and test results to Codecov](done/ci-001.md)
- [REFACT-003 — Refactor wsl-manager integration tests](done/refact-003.md)
- [BUG-003 — UTF-8 BOM in integration test bash scripts](done/bug-003.md)
- [REFACT-002 — Fix `Invoke-SetupUser` CI guard scope](done/refact-002.md)
- [REFACT-001 — Add `-Selection` parameter to Update/Remove](done/refact-001.md)
- [FEAT-004 — Replace Bootstrap with self-contained install.ps1](done/feat-004.md)
- [FEAT-003 — Add Flow Launcher as standalone optional tool](done/feat-003.md)
- [BUG-002 — VS Code WSL Interop interference fixed](done/bug-002.md)
- [FEAT-001 — DevContainer Prep → Docker Prerequisites](done/feat-001.md)
- [BUG-001 — WSL Manager fails when no distributions installed](done/bug-001.md)

---

## Notes

- **ID prefix**: `SC` (shortcuts)
- Use format `[SC-###]` for item IDs — global sequential numbering
- Keep items actionable with clear acceptance criteria
- Do NOT list commit hashes in backlog entries — the backlog is part of the commit itself, so hashes are circular and go stale after squash/rebase

### Closing an item (checklist)

1. **Verify acceptance criteria** — all `[ ]` must be `[x]`. Do NOT close with unchecked items.
2. **Update the heading** — add `✅ COMPLETED` (e.g., `# [SC-004] ✅ COMPLETED - …`)
3. **Update the Status field** — change to `**Completed** (YYYY-MM-DD)`
4. **Update this index** — move the entry from its current section to **Done**, change path from `in_progress/` (or `todo/`) to `done/`
5. **Move the file** — `git mv docs/backlog/in_progress/sc-004.md docs/backlog/done/sc-004.md`

---

[← Back to README](../../README.md)
