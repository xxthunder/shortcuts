[← Back to README](../../README.md)

# Backlog

## Status Legend

- **Open** - Ready to be picked up
- **In Progress** - Currently being worked on
- **Done** - Completed
- **Superseded** - Replaced by a different approach; kept for history, not being built

## Table of Contents

### In Progress

- [SC-001 — Backlog refinement](sc-001.md)
- [SC-016 — Modernize WSL Manager TUI with PwshSpectreConsole](sc-016.md)

### Open

- [SC-052 — Scoop update helper must not silently drop apps when `scoop status` fails](sc-052.md)
- [SC-053 — Scoop update helper must surface the `Info` column from `scoop status`](sc-053.md)
- [SC-054 — Podman and user unit tests must not reach the real wsl.exe](sc-054.md)
- [SC-055 — Open a terminal in an installed distribution from wsl-manager](sc-055.md)
- [SC-028 — Improve WSL manager console output handling](sc-028.md)
- [SC-030 — Add progress indicators and status feedback with PwshSpectreConsole](sc-030.md)
- [SC-031 — Redesign menu layout with grouped commands and contextual help](sc-031.md)
- [SC-020 — Import and export WSL distributions to/from files](sc-020.md)
- [SC-023 — Per-file code coverage in testrunner.ps1](sc-023.md)
- [SC-032 — Investigate split-pane TUI layout for WSL Manager](sc-032.md)
- [SC-034 — Shared dependency utilities and auto-discovery](sc-034.md)
- [SC-037 — Increase WSL Manager unit test coverage](sc-037.md)

### Superseded

- [SC-036b — Negotiate mode Phase 1: bootstrap install of krb5 and px](sc-036b.md) — replaced by [SC-040](sc-040.md) + [SC-036f](sc-036f.md)
- [SC-036c — Negotiate mode Phases 2–3: Kerberos + px activation](sc-036c.md) — replaced by [SC-040](sc-040.md) + [SC-036f](sc-036f.md)
- [SC-036d — Negotiate mode Phase 4: switch targets to localhost and auto-start px](sc-036d.md) — replaced by [SC-040](sc-040.md) + [SC-036f](sc-036f.md)
- [SC-036e — Mode-aware `--remove` teardown and Negotiate docs](sc-036e.md) — replaced by [SC-040](sc-040.md) + [SC-036f](sc-036f.md)

### Done

- [SC-051 — px-proxy runbook: fix Keypirinha invocation, document manual start and VPN ordering](sc-051.md)
- [SC-050 — Trim AGENTS.md duplication, point to powershell-dev skill](sc-050.md)
- [SC-049 — px unit tests must never kill a real px process](sc-049.md)
- [SC-048 — Stable px defaults for sharing (workers = 1, idle = 300)](sc-048.md)
- [SC-047 — Resilient, looping, 5.1-compatible Scoop update helper](sc-047.md)
- [SC-046 — Make px `[settings]` user-configurable via px-user.ini](sc-046.md)
- [SC-045 — Setup-proxy mode prompt: Enter defaults to Auto](sc-045.md)
- [SC-036 — Corporate proxy for WSL without stored credentials](sc-036.md)
- [SC-036f — Auto proxy setup detects a running Windows px](sc-036f.md)
- [SC-040 — Add Windows-side px authenticating proxy tool](sc-040.md)
- [SC-042 — WSL ambient proxy env bypasses px (autoProxy override + zsh profile gap)](sc-042.md)
- [SC-043 — Trust the corporate TLS-inspection CA for tools with bundled cert stores (uv)](sc-043.md)
- [SC-044 — Give px headroom for Claude Code connection bursts (workers/threads)](sc-044.md)
- [SC-041 — Move tool-specific documentation into docs/runbooks/](sc-041.md)
- [SC-039 — Refresh @claude model aliases to current 4.x family](sc-039.md)
- [SC-038 — Repoint claude.yml shared-skills plugin to renamed xxthunder-agentic-skills repo](sc-038.md)
- [SC-017 — Auto-terminate distros instead of prompting the user](sc-017.md)
- [SC-036a — Add setup-proxy mode/auth prompts and mode marker](sc-036a.md)
- [SC-035 — Add sync-ssh-config command for Windows DevPod access](sc-035.md)
- [SC-016e — Add Read-SpectreConfirm for destructive operations](sc-016e.md)
- [SC-016d — Replace distro selection with Read-SpectreSelection](sc-016d.md)
- [SC-016c — Replace distro table with Format-SpectreTable](sc-016c.md)
- [SC-033 — Tool-level dependency declaration and installation](sc-033.md)
- [SC-016b — Replace main menu with Read-SpectreSelection](sc-016b.md)
- [SC-016a — Add PwshSpectreConsole module dependency to setup process](sc-016a.md)
- [SC-029 — Drop PowerShell 5.1 requirement and adopt PowerShell 7.6+](sc-029.md)
- [SC-027 — Make shared skills available to Claude GitHub App via plugin](sc-027.md)
- [SC-013 — Fix and enhance documentation](sc-013.md)
- [SC-026 — Add setup-devpod action to wsl-manager](sc-026.md)
- [SC-025 — Apply automount metadata and umask defaults in per-distro wsl.conf](sc-025.md)
- [SC-006 — Scoop Update Helper Script](sc-006.md)
- [SC-024 — Maintain PowerShell 5.1 compatibility and fix batch wrapper violations](sc-024.md)
- [SC-022 — Make generic skills reusable across repositories](sc-022.md)
- [SC-015 — Reorganize project structure: separate tools from libraries](sc-015.md)
- [SC-021 — Apply default WSL global settings (.wslconfig) via wsl-manager](sc-021.md)
- [SC-005 — Refactor WSL Manager command dispatch (DRY)](sc-005.md)
- [SC-019 — Allow model selection via @claude trigger phrase](sc-019.md)
- [SC-003 — Stop action functions from reprinting distro table](sc-003.md)
- [SC-002 — Add `shutdown` command to wsl-manager](sc-002.md)
- [SC-018 — Install Claude GitHub App and remove legacy workflows](sc-018.md)
- [SC-014 — setup-user CLI does not accept -Username and -Password parameters](sc-014.md)
- [SC-011 — WSL Manager: mask credentials and auto-terminate after install](sc-011.md)
- [SC-012 — Stop-WslDistro: verify termination with retry](sc-012.md)
- [SC-010 — Review and enhance VS Code DevContainer Setup documentation](sc-010.md)
- [SC-004 — Consolidate documentation and make all docs reachable from README](sc-004.md)
- [SC-007 — Add `setup-proxy` action to wsl-manager](sc-007.md)
- [SC-008 — Split backlog into index and per-item files](sc-008.md)
- [SC-009 — PowerShell Lint Guard (skill + pre-commit hook)](sc-009.md)
- [FEAT-002 — Set up Podman as Docker alternative in WSL](feat-002.md)
- [REFACT-005 — Extract `Assert-WslDistroExists` guard (DRY)](refact-005.md)
- [REFACT-004 — Remove redundant `Test-WslInstalled` guard checks (DRY)](refact-004.md)
- [BUG-004 — Flaky integration test for terminating stopped distribution](bug-004.md)
- [CHORE-001 — Move reusable skills to global ~/.claude/skills](chore-001.md)
- [CI-003 — Normalize JaCoCo XML paths for Codecov](ci-003.md)
- [CI-002 — Normalize JUnit XML paths for Codecov](ci-002.md)
- [CI-001 — Upload code coverage and test results to Codecov](ci-001.md)
- [REFACT-003 — Refactor wsl-manager integration tests](refact-003.md)
- [BUG-003 — UTF-8 BOM in integration test bash scripts](bug-003.md)
- [REFACT-002 — Fix `Invoke-SetupUser` CI guard scope](refact-002.md)
- [REFACT-001 — Add `-Selection` parameter to Update/Remove](refact-001.md)
- [FEAT-004 — Replace Bootstrap with self-contained install.ps1](feat-004.md)
- [FEAT-003 — Add Flow Launcher as standalone optional tool](feat-003.md)
- [BUG-002 — VS Code WSL Interop interference fixed](bug-002.md)
- [FEAT-001 — DevContainer Prep → Docker Prerequisites](feat-001.md)
- [BUG-001 — WSL Manager fails when no distributions installed](bug-001.md)

---

## Notes

- **ID prefix**: `SC` (shortcuts)
- Use format `[SC-###]` for item IDs - global sequential numbering
- Keep items actionable with clear acceptance criteria
- Do NOT list commit hashes in backlog entries - the backlog is part of the commit itself, so hashes are circular and go stale after squash/rebase

### Closing an item (checklist)

1. **Verify acceptance criteria** - all `[ ]` must be `[x]`. Do NOT close with unchecked items.
2. **Update the heading** - add `✅ DONE -` prefix (e.g., `# [SC-004] ✅ DONE - …`)
3. **Update the Status field** - change to `**Status**: Done (YYYY-MM-DD)`
4. **Update this README** - move the entry from its current section to **Done**

---

[← Back to README](../../README.md)
