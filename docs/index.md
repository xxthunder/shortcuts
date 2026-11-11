# shortcuts

**A keyboard-driven launcher and automation toolkit for Windows**

## Quick Start

**Just want to get started?** Open PowerShell and run this command:

```powershell
irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
```

After installation, press **Alt+Space** and start typing to launch apps! The launcher is PowerToys Command Palette.

> **Note:** If you get an execution policy error, see [Troubleshooting](#installation-script-fails-with-execution-policy-error).

## What is Shortcuts?

Shortcuts turns your Windows PC into a productivity powerhouse by providing:

- **PowerToys Command Palette**: Press **Alt+Space** to instantly search and open anything
- **Smart Shortcuts**: Tools, websites, and custom commands as files in the shortcuts folders (not in the Command Palette catalog yet)
- **Package Management**: Easy installation of developer tools via Scoop
- **Automation Scripts**: PowerShell utilities to streamline your workflow

**Perfect for:** Developers, power users, and anyone who prefers keyboard over mouse.

## Installation

### Prerequisites

> **Good news!** If you have Windows 10 or later, you already have everything you need.

<details>
<summary><strong>Click here if you want to verify your system</strong></summary>

- **Operating System**: Windows 10 or later ✓
- **PowerShell**: Windows PowerShell 5.1 is sufficient to run `install.ps1`; it installs PowerShell 7.4+ (pwsh) automatically for all other tools
  - Check your version after install: `$PSVersionTable.PSVersion`
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

- The script will install Scoop (package manager) and PowerToys (with Command Palette), set **Alt+Space** as its hotkey and start it
- On a machine where PowerToys already ran, restart PowerToys once (tray icon, Exit, then start PowerToys) so Command Palette picks up the hotkey

**4. Start using Shortcuts!**

- Press **Alt+Space** to open Command Palette
- Start typing to search for apps

## Using Command Palette

### Launch Command Palette

Press **Alt+Space** anywhere, anytime. A search box appears where you can type to find what you need.

### Try These Examples

Open Command Palette (**Alt+Space**) and try typing:

| Type this | What happens |
|-----------|-------------|
| `chrome` | Opens Google Chrome browser |
| `word` | Opens Microsoft Word |
| `code` | Opens VS Code (if installed) |
| `calc` | Opens Calculator |
| `cmd` | Opens Command Prompt |
| `powershell` | Opens PowerShell |
| `notepad` | Opens Notepad |

### Shortcuts folders are not in the catalog yet

Command Palette does not catalog the shortcuts folders yet: the `.url` files in `links/` and the `.bat` wrappers of the tools do not show up when you search. They will, once the folder extension for Command Palette (CPF-002) arrives. Until then, open them from File Explorer or a terminal.

### Coming from Keypirinha?

The installer no longer installs Keypirinha. If you still have it, remove it. Keypirinha holds **Alt+Space** while it runs, so:

1. Exit Keypirinha (tray icon, Exit).
2. Uninstall it:

```powershell
scoop uninstall keypirinha
```

3. Restart PowerToys (tray icon, Exit, then start PowerToys) so Command Palette picks up **Alt+Space**.

## Managing Shortcuts

### Available Shortcuts

Your shortcuts are stored as `.url` files in the `links/` directory. Command Palette does not catalog this folder yet (see [above](#shortcuts-folders-are-not-in-the-catalog-yet)).

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

4. Double-click the file to use it; Command Palette will list it once the folder extension arrives

### Installing Optional Tools

**Other useful tools via Scoop:**

```powershell
scoop install git         # Version control
scoop install nodejs      # JavaScript runtime
scoop install python      # Python programming
scoop install vscode      # Visual Studio Code
```

## WSL Manager

WSL Manager is a PowerShell tool for managing WSL distributions from the Windows side.
It provides both a TUI (menu-driven interface) and CLI commands to:

- **Manage WSL distributions**: list, clone, update, remove, and terminate
- **Set up container engines**: one-command Docker or Podman installation
- **Configure DevContainers**: complete DevContainer setup with DevPods or VS Code (SSH agent, git, etc.)
- **Manage users and proxy**: create users with sudo, configure corporate proxy settings

**[📖 WSL Manager Documentation](wsl-manager.md)**

## More Features

- **[px-proxy](runbooks/px-proxy.md)**: A Windows-side local authenticating proxy (px) that gives native CLI tools and WSL seamless SSPI/Kerberos auth through the corporate proxy, with no stored credentials
- **[update-scoop](runbooks/scoop-update.md)**: An interactive, resilient loop for updating Scoop apps; runs under Windows PowerShell 5.1 in a classic console so it can update pwsh and Windows Terminal

## Update

### Quick Update (Easiest)

1. Open the `bin` folder of your Shortcuts installation
2. Run `update.bat`

### Manual Update

Run the installation command again (it won't duplicate anything):

```powershell
irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
```

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

### Command Palette doesn't open on Alt+Space

**Check these:**

1. PowerToys is running (look for its icon in the system tray)
2. If missing, start PowerToys from the Start Menu
3. Another app may use the same hotkey; close it and try again
4. Run the installation command again; it sets the hotkey. Then restart PowerToys (tray icon, Exit, then start PowerToys)

**Still not working?** Reinstall PowerToys:

```powershell
scoop uninstall powertoys
scoop install powertoys
```

### Scoop commands not recognized

**Solution:**

1. Close and reopen your PowerShell terminal
2. Try running: `Get-Command scoop`
3. If still not found, reinstall using the installation script

### Update doesn't work

**Try these in order:**

1. Run `bin\update.bat`
2. Run installation command again (safe to repeat):

   ```powershell
   irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
   ```

3. Check internet connection
4. Disable antivirus temporarily and try again

## Uninstallation

### Quick Uninstall (Just the Launcher)

If you just want to remove the launcher:

```powershell
scoop uninstall powertoys
```

### Complete Uninstall

**Step 1: Uninstall the launcher**

```powershell
scoop uninstall powertoys
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

## Development

> **For Contributors:** This section is for developers who want to contribute to Shortcuts.

### Documentation

- **[Development Principles](development-principles.md)**: Coding standards, TDD approach, and project conventions
- **[Architecture](architecture/README.md)**: Diagrams and Architecture Decision Records (ADRs)
- **[Roadmap](roadmap.md)**: Project vision and future direction
- **[Backlog](backlog/README.md)**: Current work items, priorities, and completed features
- **Requirements and traces**: The requirements of the tools and the code and tests that implement and test them, below each tool's documentation; px-proxy is the first ([requirements](requirements/px-proxy.md), [traces](traceability/px-proxy.md))

Build the published documentation locally with [uv](https://docs.astral.sh/uv/); CI runs the same command:

```bash
uv run poe docs   # Sphinx with -W: a warning, such as a link to a missing requirement, fails the build
```

The output is in `_build/html`. `ubproject.toml` is the one configuration; ubCode reads it as well.

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

The project requires **PowerShell 7.4+** (pwsh) for all tests.

**Test types:**

- **Unit tests** (`*.Tests.ps1`): Fast, isolated tests with mocked dependencies
- **Integration tests** (`*.Integration.Tests.ps1`): Tests that interact with real systems

**Local development workflow (recommended):**

```powershell
# Step 1: Run unit tests first (faster feedback)
pwsh -File .\test\bin\testrunner.ps1 -Unit

# Step 2: Run integration tests when necessary (e.g., before committing)
pwsh -File .\test\bin\testrunner.ps1 -Integration
```

**Run all tests (CI/comprehensive testing):**

```powershell
pwsh -File .\test\bin\testrunner.ps1
```

**Run tests with code coverage:**

```powershell
# All tests with coverage
pwsh -File .\test\bin\testrunner.ps1 -Coverage

# Unit tests with coverage
pwsh -File .\test\bin\testrunner.ps1 -Unit -Coverage

# Integration tests with coverage
pwsh -File .\test\bin\testrunner.ps1 -Integration -Coverage
```

**Run tests for specific paths:**

```powershell
# Run all tests in a directory
pwsh -File .\test\bin\testrunner.ps1 -TestPath "lib" -Verbosity "Detailed"

# Run a specific test file
pwsh -File .\test\bin\testrunner.ps1 -TestPath "lib\utils\utils.Tests.ps1"
```

**Important Notes:**

- Always run tests **without** the `CI` environment variable set (unless testing CI-specific behavior)
- The test suite automatically detects Pester environment and handles non-interactive scenarios
- Tests require PowerShell 7.4+ (pwsh)
- Path must be quoted when passed to `-File` parameter (e.g., `".\test\bin\testrunner.ps1"`)

#### Code Quality Checks

The test suite automatically runs PSScriptAnalyzer on all PowerShell files before executing unit tests:

- **Checks**: Error and Warning severity violations
- **Files analyzed**: All `.ps1` files in the specified test paths
- **Integration**: Results are included in the JUnit XML test report

#### Test Structure

- `test/bin/testrunner.ps1` - Unified test runner script with switches:
  - No switches: Run all tests (unit + integration) - used in CI/GitHub Actions
  - `-Unit`: Run only unit tests (faster feedback) - local development
  - `-Integration`: Run only integration tests - local development
  - `-Coverage`: Enable code coverage (works with any combination)
- `test/bin/linter.Tests.ps1` - PSScriptAnalyzer integration
- `*.Tests.ps1` - Unit test files (located alongside source files)
- `*.Integration.Tests.ps1` - Integration test files (located alongside source files)

#### Coding Standards

All PowerShell code must:

- Pass PSScriptAnalyzer checks (Error/Warning severity)
- Include Pester unit tests
- Follow project guidelines in `AGENTS.md` and `lib/AGENTS.md`
- Use TDD, DRY, and SOLID principles

For detailed development guidelines, see:

- `AGENTS.md` - Project-wide coding guidelines
- `lib/AGENTS.md` - PowerShell library development guide

```{toctree}
:hidden:
:caption: Tools

wsl-manager
runbooks/px-proxy
runbooks/scoop-update
```

```{toctree}
:hidden:
:caption: Development

development-principles
architecture/README
test-results
Coverage <https://app.codecov.io/gh/xxthunder/shortcuts/tree/develop>
roadmap
backlog/README
```
