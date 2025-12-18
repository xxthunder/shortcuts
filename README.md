<p align="center">
  <img src="docs/images/shortcuts_logo_title_transparent.png" alt="Shortcuts Logo" width="400">
</p>

<p align="center">
  <strong>A keyboard-driven launcher and automation toolkit for Windows</strong>
</p>

<p align="center">
  <a href="https://github.com/xxthunder/shortcuts/actions/workflows/test.yml">
    <img src="https://github.com/xxthunder/shortcuts/actions/workflows/test.yml/badge.svg" alt="CI Status">
  </a>
  <a href="https://github.com/xxthunder/shortcuts/blob/develop/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
  </a>
  <a href="https://github.com/xxthunder/shortcuts">
    <img src="https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg" alt="PowerShell 5.1+">
  </a>
  <a href="https://github.com/xxthunder/shortcuts">
    <img src="https://img.shields.io/badge/platform-Windows-lightgrey.svg" alt="Platform: Windows">
  </a>
</p>

---

## Table of Contents

- [Quick Start](#quick-start)
- [What is Shortcuts?](#what-is-shortcuts)
- [Installation](#installation)
- [Using Keypirinha](#using-keypirinha)
- [Managing Shortcuts](#managing-shortcuts)
- [Update](#update)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)
- [Development](#development)

---

## Quick Start

**Just want to get started?** Open PowerShell and run this command:

```powershell
irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
```

After installation, press **Win+Alt+Space** and start typing to launch apps and shortcuts!

> **Note:** If you get an execution policy error, see [Troubleshooting](#installation-script-fails-with-execution-policy-error).

---

## What is Shortcuts?

Shortcuts turns your Windows PC into a productivity powerhouse by providing:

- **Keypirinha Launcher**: Press **Win+Alt+Space** to instantly search and open anything
- **Smart Shortcuts**: Quick access to tools, websites, and custom commands
- **Package Management**: Easy installation of developer tools via Scoop
- **Automation Scripts**: PowerShell utilities to streamline your workflow

**Perfect for:** Developers, power users, and anyone who prefers keyboard over mouse.

---

## Installation

### Prerequisites

> **Good news!** If you have Windows 10 or later, you already have everything you need.

<details>
<summary><strong>Click here if you want to verify your system</strong></summary>

- **Operating System**: Windows 10 or later ✓
- **PowerShell**: Version 5.1+ (pre-installed on Windows 10+)
  - Check your version: `$PSVersionTable.PSVersion`
- **Internet Connection**: Required for downloads

</details>

### Installation Steps

**1. Open PowerShell**
   - Press `Win + X` and select "Windows PowerShell" or "Terminal"
   - Or search for "PowerShell" in Start Menu

**2. Run the installation command:**

```powershell
irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
```

**3. Wait for installation to complete**
   - The script will install Scoop (package manager) and Keypirinha (launcher)
   - You'll see a *k*-icon appear in your taskbar when done

**4. Start using Shortcuts!**
   - Press **Win+Alt+Space** to launch Keypirinha
   - Start typing to search for apps and shortcuts

---

## Using Keypirinha

### Launch Keypirinha

Press **Win+Alt+Space** anywhere, anytime. A search box appears where you can type to find what you need.

### Try These Examples

Open Keypirinha (**Win+Alt+Space**) and try typing:

| Type this | What happens |
|-----------|-------------|
| `chrome` | Opens Google Chrome browser |
| `word` | Opens Microsoft Word |
| `code` | Opens VS Code (if installed) |
| `calc` | Opens Calculator |
| `cmd` | Opens Command Prompt |
| `powershell` | Opens PowerShell |
| `notepad` | Opens Notepad |

### Pro Tips

- **Fuzzy search**: Type `chr` to find Chrome, `wrd` to find Word
- **Calculator**: Type math directly: `2+2`, `15*8`, etc.
- **Files**: Start typing a file path to open folders
- **Recent items**: Your recently used items appear first

### Important: Refresh Catalog

After installing new apps or adding shortcuts, refresh Keypirinha's catalog:

1. Press **Win+Alt+Space**
2. Type **"Refresh catalog"**
3. Press Enter
4. Wait a few seconds for the scan to complete

---

## Managing Shortcuts

### Available Shortcuts

Your shortcuts are stored as `.url` files in the `links/` directory. After refreshing Keypirinha's catalog, these appear instantly when you search.

**Common categories:**

- **Web Links**: Favorite websites and web apps
- **Development Tools**: IDEs, editors, debugging tools
- **System Utilities**: Windows tools and configurations
- **Custom Commands**: Project-specific shortcuts

### Creating Your Own Shortcuts

1. Navigate to the `links/` folder in your Shortcuts installation
2. Create a new `.url` file (e.g., `MyApp.url`)
3. Edit the file with this format:
   ```ini
   [InternetShortcut]
   URL=https://example.com
   ```
4. Refresh Keypirinha catalog (**Win+Alt+Space** → "Refresh catalog")
5. Type the shortcut name to use it!

### Installing Optional Tools

**PowerShell Core** (recommended for developers):

```powershell
scoop install pwsh
```

**Other useful tools via Scoop:**

```powershell
scoop install git         # Version control
scoop install nodejs      # JavaScript runtime
scoop install python      # Python programming
scoop install vscode      # Visual Studio Code
```

---

## Update

### Quick Update (Easiest)

1. Press **Win+Alt+Space**
2. Type **"update"**
3. Select and run `update.bat`
4. After update completes, type **"Refresh catalog"** in Keypirinha

### Manual Update

Run the installation command again (it won't duplicate anything):

```powershell
irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
```

> **Remember:** Always refresh Keypirinha's catalog after updates to see new shortcuts.

---

## Troubleshooting

### Installation script fails with execution policy error

**Problem:** PowerShell blocks the installation script.

**Solution:** Run this command in PowerShell, then try installing again:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or use the bypass option (one-time):

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
```

### Keypirinha doesn't start or show the window

**Check these:**

1. Look for the *k*-icon in your system tray (bottom-right corner)
2. If missing, search for "Keypirinha" in Start Menu and launch it
3. Try restarting: Right-click the *k*-icon → Exit → Launch again

**Still not working?** Reinstall Keypirinha:

```powershell
scoop uninstall keypirinha
scoop install keypirinha
```

### Shortcuts or apps don't appear in Keypirinha

**Solution (fixes 90% of cases):**

1. Press **Win+Alt+Space**
2. Type **"Refresh catalog"**
3. Press Enter and wait 5-10 seconds

**Still missing?** Check if:
- The application is actually installed
- The `.url` file exists in the `links/` folder
- Keypirinha is running (check system tray)

### Scoop commands not recognized

**Solution:**

1. Close and reopen your PowerShell terminal
2. Try running: `Get-Command scoop`
3. If still not found, reinstall using the installation script

### Update doesn't work

**Try these in order:**

1. Run update via Keypirinha (**Win+Alt+Space** → "update")
2. Run installation command again (safe to repeat):
   ```powershell
   irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
   ```
3. Check internet connection
4. Disable antivirus temporarily and try again

### Keypirinha hotkey (Win+Alt+Space) doesn't work

**Possible causes:**

1. Another app is using the same hotkey
2. Keypirinha isn't running (check system tray)
3. You can configure a different hotkey in Keypirinha settings

**To change hotkey:**
- Right-click Keypirinha *k*-icon → Configure Keypirinha → Edit main settings

---

## Uninstallation

### Quick Uninstall (Just Keypirinha)

If you just want to remove the launcher:

```powershell
scoop uninstall keypirinha
```

### Complete Uninstall

**Step 1: Uninstall Keypirinha**

```powershell
scoop uninstall keypirinha
```

**Step 2: Remove other Scoop packages (optional)**

See what's installed:
```powershell
scoop list
```

Remove specific packages:
```powershell
scoop uninstall <package-name>
```

**Step 3: Remove Scoop entirely (optional)**

```powershell
scoop uninstall scoop
```

**Step 4: Clean up directories (optional)**

Manually delete these folders if desired:
- `%USERPROFILE%\scoop` - Scoop and all installed packages
- `%USERPROFILE%\shortcuts` - Shortcuts repository

> **Tip:** You can also use File Explorer's address bar: paste `%USERPROFILE%` and press Enter to navigate there.

---

## Development

> **For Contributors:** This section is for developers who want to contribute to Shortcuts.

### Getting Started

**AI-Assisted Development:**
If you're using AI tools (Claude Code, GitHub Copilot, etc.), read `AGENTS.md` first. It contains detailed technical guidelines, coding standards, and architectural patterns for AI agents.

**Human Developers:**
Read both this section and `AGENTS.md` for comprehensive development guidelines.

### Testing and Code Quality

The project uses **Pester** for testing and **PSScriptAnalyzer** for code quality checks.

#### Prerequisites for Development

The project requires:
- **Pester**: PowerShell testing framework (version 5.2.0+)
- **PSScriptAnalyzer**: PowerShell linter (version 1.18.0+)

**Easy installation:**

```powershell
.\test\bin\init.ps1
```

This script automatically installs all required development dependencies.

<details>
<summary>Manual installation (if needed)</summary>

```powershell
Install-Module -Name Pester -MinimumVersion 5.2.0 -Force -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -MinimumVersion 1.18.0 -Force
```

</details>

#### Running Tests

The project supports testing on both **PowerShell 5.1** and **PowerShell 7.x** to ensure compatibility across all environments.

**Run all tests on PowerShell 7.x (recommended):**

```powershell
pwsh -File .\test\bin\test-all.ps1
```

**Run all tests on PowerShell 5.1:**

```powershell
powershell -File .\test\bin\test-all.ps1
```

**Run tests on both versions (comprehensive):**

```powershell
# PowerShell 7.x
pwsh -File .\test\bin\test-all.ps1

# PowerShell 5.1
powershell -File .\test\bin\test-all.ps1
```

**Run tests for specific paths:**

```powershell
pwsh -File .\test\bin\test.ps1 -TestPath "tools\pslib" -Verbosity "Detailed"
```

**Important Notes:**

- Always run tests **without** the `CI` environment variable set (unless testing CI-specific behavior)
- The test suite automatically detects Pester environment and handles non-interactive scenarios
- Tests should pass on both PowerShell 5.1 and 7.x for CI compatibility
- Path must be quoted when passed to `-File` parameter (e.g., `".\test\bin\test-all.ps1"`)

#### Code Quality Checks

The test suite automatically runs PSScriptAnalyzer on all PowerShell files before executing unit tests:

- **Checks**: Error and Warning severity violations
- **Files analyzed**: All `.ps1` files in the specified test paths
- **Integration**: Results are included in the JUnit XML test report

#### Test Structure

- `test/bin/test.ps1` - Main test runner script
- `test/bin/test-all.ps1` - Convenience wrapper for running all tests
- `test/bin/linter.Tests.ps1` - PSScriptAnalyzer integration
- `*.Tests.ps1` - Unit test files (located alongside source files)

#### Coding Standards

All PowerShell code must:

- Pass PSScriptAnalyzer checks (Error/Warning severity)
- Include Pester unit tests
- Follow project guidelines in `AGENTS.md` and `tools/pslib/AGENTS.md`
- Use TDD, DRY, and SOLID principles

For detailed development guidelines, see:

- `AGENTS.md` - Project-wide coding guidelines
- `tools/pslib/AGENTS.md` - PowerShell library development guide
