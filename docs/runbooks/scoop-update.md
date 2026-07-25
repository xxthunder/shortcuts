[← Back to README](../../README.md)

# Scoop Update Helper Runbook

## Overview

`update-scoop` is an interactive helper for updating your [Scoop](https://scoop.sh)-managed apps. It refreshes Scoop once, then loops: it lists the apps that have updates, lets you pick which to update (or all), and stays open so you can update, re-check, and retry without relaunching. You leave the loop by pressing `Q`.

It is built around three properties:

- **Resilient**: if a Scoop command fails (for example, an app is locked), the error is shown and you are returned to the menu. The session never crashes or exits on a Scoop error.
- **Looping**: it runs until you quit, so you can update several apps, close a locked application, and retry in one sitting.
- **Runs under Windows PowerShell 5.1 in a classic console**: this is what lets it update `pwsh` and Windows Terminal (see below).

**Why 5.1 and a classic console:** a program cannot replace its own running executable. If the helper ran under `pwsh` (PowerShell 7), updating `pwsh` would fail because `pwsh.exe` is locked; if it ran inside Windows Terminal, updating Windows Terminal would fail because `WindowsTerminal.exe` is locked. So `update-scoop.bat` launches the helper under `powershell.exe` (Windows PowerShell 5.1) inside a classic `conhost` window, detached from wherever you started it. `conhost.exe` is used explicitly so that even if Windows Terminal is set as your default terminal application, the helper still opens in a classic console rather than a Windows Terminal tab.

**When to use it:** whenever you want to update Scoop apps interactively, and especially when you need to update `pwsh` or Windows Terminal, which cannot be updated from a normal PowerShell 7 / Windows Terminal session.

---

## Prerequisites

- [Scoop](https://scoop.sh) installed. The helper checks for it and exits with a message if it is missing.
- Nothing else: the helper uses only Windows PowerShell 5.1, which ships with Windows.

---

## Usage

Run from Keypirinha (type `update-scoop`) or from a terminal:

```bat
tools\scoop\update-scoop.bat
```

Always launch via the `.bat` wrapper (not `update-scoop.ps1` directly): the wrapper is what forces the classic console + Windows PowerShell 5.1 that makes `pwsh` / Windows Terminal updates possible.

A new console window opens with the menu:

```text
Updatable Apps:
  1. pwsh              (7.5.4 -> 7.5.5)
  2. windows-terminal  (1.19  -> 1.20)

Enter number(s) comma-separated, [A]ll, [R]efresh, [Q]uit:
```

| Input | What it does |
|-------|--------------|
| `1` or `1,3` | Updates the numbered app(s). |
| `A` | Updates all listed apps. |
| `R` | Re-runs the Scoop bucket refresh and re-checks for updates. |
| `Q` | Quits and closes the window. |

After an update runs, the helper pauses ("Press any key to continue...") so you can read the output before the list is redrawn. The bucket refresh (`scoop update`) runs once automatically at startup; use `R` to refresh again.

### Updating pwsh or Windows Terminal

Because the helper runs under Windows PowerShell 5.1 in a classic console:

- **`pwsh`** can be updated directly: select it from the list.
- **Windows Terminal** can only be replaced while no Windows Terminal window is open. If a Windows Terminal window is still running, the update fails, the error is shown in red, and you are returned to the menu. Close all Windows Terminal windows, press `R` to re-check, then update `windows-terminal`. All of this happens in the same helper session.

---

## Troubleshooting

**It opened in a Windows Terminal tab, not a classic console.**
Launch via `update-scoop.bat`, not `update-scoop.ps1`. The wrapper uses `conhost.exe` specifically to bypass the "Windows Terminal is my default terminal application" setting. If you invoked the `.ps1` directly (or copied only part of the wrapper command), you lose that behavior.

**"Scoop is not installed."**
Install Scoop first (see the [Scoop website](https://scoop.sh) or the project README), then re-run.

**A `windows-terminal` update keeps failing.**
A Windows Terminal window is still open (it does not have to be the one you launched from). Close every Windows Terminal window, press `R`, and retry. The helper itself runs in a classic console, so it does not block the update.

**An update fails for some other reason.**
The raw Scoop error is printed and you are returned to the menu; the session keeps running. Read the error, resolve the cause (for example a running process or a network/proxy issue), press `R` to re-check, and retry.

[← Back to README](../../README.md)
