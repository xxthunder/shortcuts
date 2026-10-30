# Backlog

## Status Legend

- **Open** - Ready to be picked up
- **In Progress** - Currently being worked on
- **Done** - Completed
- **Superseded** - Replaced by a different approach; kept for history, not being built

## Table of Contents

### Open
- [SC-082 — px-proxy sets the proxy variables in the user environment](sc-082.md)
- [SC-081 — Setup CA with the default URL misses the intranet root CA](sc-081.md)
- [SC-080 — update-scoop reports success for apps Scoop skipped](sc-080.md)
- [SC-079 — Containers in a mirrored-mode distribution reach neither the proxy nor its CA](sc-079.md)
- [SC-078 — wsl-manager makes a distribution the default](sc-078.md)
- [SC-077 — One status per test and requirement, passed only when all tests passed](sc-077.md)
- [SC-076 — Short test result IDs, and a Test results page that fits and stays current](sc-076.md)
- [SC-075 — CI on Node 24 actions, Python toolchain past the emSign CA incident](sc-075.md)
- [SC-073f — C4 elements as needs](sc-073f.md)
- [SC-071 — Try Wox as a Keypirinha successor](sc-071.md)
- [SC-070 — Try PowerToys Command Palette as a Keypirinha successor](sc-070.md)
- [SC-066 — wsl-manager hands the Linux side of a distribution to Ansible](sc-066.md)
- [SC-065 — Devcontainer for development and tests on Linux](sc-065.md)
- [SC-061 — setup-proxy must not overwrite or delete apt, Docker and Podman files it does not own](sc-061.md)
- [SC-056 — Escape distribution names before Spectre renders them](sc-056.md)
- [SC-053 — Scoop update helper must surface the `Info` column from `scoop status`](sc-053.md)
- [SC-052 — Scoop update helper must not silently drop apps when `scoop status` fails](sc-052.md)
- [SC-037 — Increase WSL Manager unit test coverage](sc-037.md)
- [SC-034 — Shared dependency utilities and auto-discovery](sc-034.md)
- [SC-032 — Investigate split-pane TUI layout for WSL Manager](sc-032.md)
- [SC-031 — Redesign menu layout with grouped commands and contextual help](sc-031.md)
- [SC-030 — Add progress indicators and status feedback with PwshSpectreConsole](sc-030.md)
- [SC-028 — Improve WSL manager console output handling](sc-028.md)
- [SC-023 — Per-file code coverage in testrunner.ps1](sc-023.md)
- [SC-020 — Import and export WSL distributions to/from files](sc-020.md)

### In Progress
- [SC-083 — Format and lint each PowerShell file as soon as Claude changes it](sc-083.md)
- [SC-073e — codelinks markers in the px-proxy code and tests](sc-073e.md)
- [SC-073c — px-proxy requirements, and the items and ADRs that change them](sc-073c.md)
- [SC-073b — Documentation build and trace gate](sc-073b.md)
- [SC-073a — PowerShell support in sphinx-codelinks](sc-073a.md)
- [SC-073 — Traceability with sphinx-needs, ubCode and codelinks: px-proxy first](sc-073.md)
- [SC-001 — Backlog refinement](sc-001.md)

### Done
- [SC-074 — README as landing page, the documentation on GitHub Pages](sc-074.md)
- [SC-073d — Pester test results linked to their tests](sc-073d.md)
- [SC-072 — Backlog index the backlog script can derive](sc-072.md)
- [SC-069 — Remove Flow Launcher](sc-069.md)
- [SC-068 — Distribution table: tell the WSL architecture from the WSL version](sc-068.md)
- [SC-067 — px starts at logon](sc-067.md)
- [SC-064 — Update WSL itself from wsl-manager](sc-064.md)
- [SC-063 — setup-docker fails on WSL 3.0 at systemd-binfmt](sc-063.md)
- [SC-062 — Document the repository architecture as a C4 model in Structurizr DSL](sc-062.md)
- [SC-060 — Install the corporate root CA into a WSL distribution](sc-060.md)
- [SC-059 — WSL Manager docs claim `configure-wsl` writes `autoProxy = true`](sc-059.md)
- [SC-058 — Redraw the WSL Manager panel at the live console width after a resize](sc-058.md)
- [SC-057 — Refresh the distribution list in the WSL Manager menu](sc-057.md)
- [SC-055 — Open a terminal in an installed distribution from wsl-manager](sc-055.md)
- [SC-054 — Podman and user unit tests must not reach the real wsl.exe](sc-054.md)
- [SC-051 — px-proxy runbook: fix Keypirinha invocation, document manual start and VPN ordering](sc-051.md)
- [SC-050 — Trim AGENTS.md duplication, point to powershell-dev skill](sc-050.md)
- [SC-049 — px unit tests must never kill a real px process](sc-049.md)
- [SC-048 — Stable px defaults for sharing (workers = 1, idle = 300)](sc-048.md)
- [SC-047 — Resilient, looping, 5.1-compatible Scoop update helper](sc-047.md)
- [SC-046 — Make px `[settings]` user-configurable via px-user.ini](sc-046.md)
- [SC-045 — Setup-proxy mode prompt: Enter defaults to Auto](sc-045.md)
- [SC-044 — Give px headroom for Claude Code connection bursts (workers/threads)](sc-044.md)
- [SC-043 — Trust the corporate TLS-inspection CA for tools with bundled cert stores (uv)](sc-043.md)
- [SC-042 — WSL ambient proxy env bypasses px (autoProxy override + zsh profile gap)](sc-042.md)
- [SC-041 — Move tool-specific documentation into docs/runbooks/](sc-041.md)
- [SC-040 — Add Windows-side px authenticating proxy tool](sc-040.md)
- [SC-039 — Refresh @claude model aliases to current 4.x family](sc-039.md)
- [SC-038 — Repoint claude.yml shared-skills plugin to renamed xxthunder-agentic-skills repo](sc-038.md)
- [SC-036f — Auto proxy setup detects a running Windows px](sc-036f.md)
- [SC-036a — Add setup-proxy mode/auth prompts and mode marker](sc-036a.md)
- [SC-036 — Corporate proxy for WSL without stored credentials](sc-036.md)
- [SC-035 — Add sync-ssh-config command for WSL SSH config sync](sc-035.md)
- [SC-033 — Tool-level dependency declaration and installation](sc-033.md)
- [SC-029 — Drop PowerShell 5.1 requirement and adopt PowerShell 7.6+ as minimum version](sc-029.md)
- [SC-027 — Make shared skills available to Claude GitHub App via plugin](sc-027.md)
- [SC-026 — Add setup-devpod action to wsl-manager](sc-026.md)
- [SC-025 — Apply automount metadata and umask defaults in per-distro wsl.conf](sc-025.md)
- [SC-024 — Maintain PowerShell 5.1 compatibility and fix batch wrapper violations](sc-024.md)
- [SC-022 — Make generic skills reusable across repositories](sc-022.md)
- [SC-021 — Apply default WSL global settings (.wslconfig) via wsl-manager](sc-021.md)
- [SC-019 — Allow model selection via @claude trigger phrase](sc-019.md)
- [SC-018 — Install Claude GitHub App and remove legacy workflows](sc-018.md)
- [SC-017 — Auto-terminate distros instead of prompting the user](sc-017.md)
- [SC-016e — Add Read-SpectreConfirm for destructive operations](sc-016e.md)
- [SC-016d — Replace distro selection with Read-SpectreSelection](sc-016d.md)
- [SC-016c — Replace distro table with Format-SpectreTable and single WSL Manager panel](sc-016c.md)
- [SC-016b — Replace main menu with Read-SpectreSelection](sc-016b.md)
- [SC-016a — Add PwshSpectreConsole module dependency to setup process](sc-016a.md)
- [SC-016 — Modernize WSL Manager TUI with PwshSpectreConsole](sc-016.md)
- [SC-015 — Reorganize project structure: separate tools from libraries](sc-015.md)
- [SC-014 — setup-user CLI does not accept -Username and -Password parameters](sc-014.md)
- [SC-013 — Fix and enhance documentation](sc-013.md)
- [SC-012 — Stop-WslDistro: verify termination with retry](sc-012.md)
- [SC-011 — WSL Manager: mask credentials and auto-terminate after install](sc-011.md)
- [SC-010 — Review and enhance VS Code DevContainer Setup documentation](sc-010.md)
- [SC-009 — PowerShell Lint Guard (skill + pre-commit hook)](sc-009.md)
- [SC-008 — Split backlog into index and per-item files](sc-008.md)
- [SC-007 — Add `setup-proxy` action to wsl-manager with automatic proxy detection](sc-007.md)
- [SC-006 — Scoop Update Helper Script](sc-006.md)
- [SC-005 — Refactor WSL Manager command dispatch (DRY)](sc-005.md)
- [SC-004 — Consolidate documentation and make all docs reachable from README](sc-004.md)
- [SC-003 — Stop action functions from reprinting distro table in interactive mode](sc-003.md)
- [SC-002 — Add `shutdown` command to wsl-manager](sc-002.md)
- [REFACT-005 — Extract `Assert-WslDistroExists` guard to replace inline distro validation (DRY)](refact-005.md)
- [REFACT-004 — Remove redundant `Test-WslInstalled` guard checks (DRY)](refact-004.md)
- [REFACT-003 — Refactor wsl-manager integration tests to call wsl-manager functions](refact-003.md)
- [REFACT-002 — Fix `Invoke-SetupUser` CI guard scope and add explicit parameters](refact-002.md)
- [REFACT-001 — Add `-Selection` parameter to `Invoke-UpdateDistro` and `Invoke-RemoveDistro`](refact-001.md)
- [FEAT-004 — Replace Bootstrap with Self-Contained install.ps1](feat-004.md)
- [FEAT-003 — Add Flow Launcher as Standalone Optional Tool](feat-003.md)
- [FEAT-002 — Set up Podman as Docker alternative in WSL](feat-002.md)
- [FEAT-001 — DevContainer Prep → Docker Prerequisites](feat-001.md)
- [CI-003 — Normalize JaCoCo XML paths for Codecov coverage](ci-003.md)
- [CI-002 — Normalize JUnit XML paths for Codecov Test Analytics](ci-002.md)
- [CI-001 — Upload code coverage and test results to Codecov](ci-001.md)
- [CHORE-001 — Move reusable skills to global ~/.claude/skills](chore-001.md)
- [BUG-004 — Flaky integration test for terminating already-stopped distribution](bug-004.md)
- [BUG-003 — UTF-8 BOM in integration test bash scripts causes shebang error](bug-003.md)
- [BUG-002 — VS Code WSL Interop Interference Fixed](bug-002.md)
- [BUG-001 — WSL Manager fails when no distributions are installed](bug-001.md)

### Superseded
- [SC-036e — Mode-aware `--remove` teardown and Negotiate docs](sc-036e.md)
- [SC-036d — Negotiate mode Phase 4 — switch targets to localhost and auto-start px](sc-036d.md)
- [SC-036c — Negotiate mode Phases 2–3 — Kerberos + px activation](sc-036c.md)
- [SC-036b — Negotiate mode Phase 1 — bootstrap install of krb5 and px](sc-036b.md)

---

```{toctree}
:hidden:
:glob:

*
```

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
