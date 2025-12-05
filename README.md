# Shortcuts

## Prerequisites

Before installing Shortcuts, ensure your system meets these requirements:

- **Operating System**: Windows 10 or later
- **PowerShell**: Version 5.1 or later (comes pre-installed on Windows 10+)
  - To check your version, run: `$PSVersionTable.PSVersion`
- **Internet Connection**: Required for downloading tools and packages
- **Execution Policy**: PowerShell scripts must be allowed to run
  - If needed, run: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

## Complete Installation

If you just came here to install the Shortcuts, open a PowerShell terminal (version 5.1 or later) and run:

```powershell
irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
```

The most important tool of Shortcuts is Keypirinha.
It provides a fast and configurable way to open your favorite tools, links and URLs.
It was started automatically after installation (you can see a *k*-icon in your taskbar's icon area).

### Using Keypirinha

> **Note:** Keypirinha can be launched by hitting **Win+Alt+Space**.

In the small window that pops up you can search for any tool installed on your PC or shortcuts we provide.

**Try these examples:**

- Type **word** - Opens Microsoft Word
- Type **chrome** - Opens Google Chrome
- Type **SPL** - Opens a custom shortcut (if configured)
- Type **wt**, **cmd** or **powershell** - Opens command-line tools
- Type **calc** - Opens Calculator

> **Important:** After installing new applications or updating shortcuts, run **'Refresh catalog'** in Keypirinha. This commands Keypirinha to rescan your PC for new tools and shortcuts.

## Available Shortcuts

Shortcuts provides quick access to common tools and URLs through Keypirinha. The available shortcuts depend on your specific configuration in the `links/` directory.

**Common shortcut categories:**

- **Development Tools**: Quick access to IDEs, text editors, and development utilities
- **Web Links**: Frequently used websites and web applications
- **System Utilities**: Administrative tools and system configurations
- **Project-Specific Links**: Custom shortcuts defined in your configuration

To see all available shortcuts, open Keypirinha (**Win+Alt+Space**) and start typing. Keypirinha will show matching shortcuts as you type.

**Note:** Shortcuts are defined in `.url` files in the `links/` directory and are automatically discovered by Keypirinha after running 'Refresh catalog'.

## Optional Installations

### PowerShell Core

PowerShell Core is the latest stable release of PowerShell maintained by its own community.
It can be easily installed via scoop. Again open a PowerShell terminal and run:

```powershell
scoop install pwsh
```

## Update

When you already installed Shortcuts and you want to update to the latest version, you can just hit **Win+Alt+Space** and search for update.bat.

Another possibility for updating Shortcuts is to open a PowerShell terminal and run the install command again:

```powershell
irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
```

After the update, hit **Win+Alt+Space** and search for 'Refresh catalog'.
Execute this to update Keypirinha's catalog database.
After a short time the new shortcuts are available.

## Troubleshooting

### Keypirinha doesn't start or show the window

- Check if Keypirinha is running: Look for the *k*-icon in your system tray
- If not running, manually start it from the Windows Start Menu.
- Try restarting Keypirinha: Right-click the *k*-icon → Exit, then start it again

### Shortcuts or applications don't appear in Keypirinha

1. Open Keypirinha (**Win+Alt+Space**)
2. Type **Refresh catalog** and press Enter
3. Wait a few seconds for Keypirinha to rescan
4. If still not appearing, check that the application is installed or the `.url` file exists in `links/`

### Installation script fails with execution policy error

Run this command in PowerShell as Administrator:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Scoop commands not recognized

- Close and reopen your PowerShell terminal
- Check if Scoop is in your PATH: `Get-Command scoop`
- If Scoop is missing, reinstall it from the installation script

### Update.bat doesn't work

Try running the installation command directly in PowerShell:

```powershell
irm https://raw.githubusercontent.com/xxthunder/shortcuts/refs/heads/develop/bin/install.ps1 | iex
```

## Uninstallation

To remove Shortcuts and its components:

### 1. Uninstall Keypirinha

```powershell
scoop uninstall keypirinha
```

### 2. Remove Scoop packages (optional)

To see all installed packages:

```powershell
scoop list
```

To remove specific packages:

```powershell
scoop uninstall <package-name>
```

### 3. Remove Scoop entirely (optional)

```powershell
scoop uninstall scoop
```

### 4. Clean up directories

Manually delete these directories if desired:

- `%USERPROFILE%\scoop` - Scoop installation directory
- `%USERPROFILE%\shortcuts` - Shortcuts repository folder
