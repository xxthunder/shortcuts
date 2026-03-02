[← Back to README](../README.md)

# Flow Launcher Setup Guide

## Overview

Flow Launcher is a modern, actively maintained keyboard launcher for Windows available as an optional alternative launcher alongside Keypirinha. It provides fast, fuzzy search for applications, files, and custom shortcuts with a powerful plugin ecosystem.

**Key Features:**

- **Active Development**: Regular updates and community support
- **Modern Architecture**: Built for Windows 10/11 compatibility
- **Auto-Reload**: Automatically detects configuration changes (no manual refresh!)
- **Plugin Ecosystem**: Built-in plugin store with 100+ plugins
- **Customizable**: Extensive theming and hotkey configuration

---

## Installation

Flow Launcher is a standalone optional tool. Use the dedicated installer:

```powershell
.\tools\flow-launcher\install-flow-launcher.ps1
```

Or use the batch wrapper:

```cmd
tools\flow-launcher\install-flow-launcher.bat
```

The installer will:
1. Install Flow Launcher via Scoop (adds the `extras` bucket if needed)
2. Configure the Program plugin to index your shortcut directories
3. Start Flow Launcher

---

## Using Flow Launcher

### Basic Usage

1. **Open Flow Launcher**: Press **Alt+Space** (default hotkey)
2. **Type to search**: Start typing the name of an app, file, or shortcut
3. **Select result**: Use arrow keys or continue typing to filter
4. **Open**: Press **Enter** to launch the selected item

### Built-in Features

Flow Launcher comes with several powerful built-in plugins:

- **Program**: Search installed applications
- **Files**: Search files and folders by name
- **Web Search**: Search the web directly from the launcher
- **Calculator**: Perform calculations (e.g., `2+2`, `15*8`)
- **Shell**: Execute shell commands
- **System Commands**: Shutdown, restart, lock, etc.

---

## Managing Shortcuts

### How Shortcuts Work

The Shortcuts project stores shortcuts as `.url`, `.bat`, and `.cmd` files across the repository. These are standard Windows file formats.

Flow Launcher's built-in **Program plugin** is configured to scan these directories and index shortcut files directly. No intermediate conversion or community plugins are needed.

The installation script automatically configures the Program plugin to scan:
- `shortcuts/` — the main project folder (checked into git)
- `shortcuts_private/` — private shortcuts (not in git)

### Adding New Shortcuts

**Step 1: Create a `.url` file**

Navigate to `links/` (or `shortcuts_private/`) and create a new file:

```ini
[InternetShortcut]
URL=https://myapp.com
```

Save it as `MyApp.url`.

**Step 2: Reindex Flow Launcher**

1. Press **Alt+Space**
2. Type `Settings` and press Enter
3. Go to **Plugins** → **Program**
4. Click **Reindex**

Your new shortcut will appear in Flow Launcher searches.

### Removing Shortcuts

1. Delete the shortcut file from its directory
2. Reindex Flow Launcher (Settings → Plugins → Program → Reindex)

### Editing Shortcuts

1. Open the `.url` file in a text editor
2. Modify the `URL=` line
3. Save the file
4. Reindex Flow Launcher to pick up changes

### Adding Additional Source Directories

You can add more directories (e.g., from other git repos) to the Program plugin:

**Via script:**

```powershell
. "$env:USERPROFILE\shortcuts\tools\flow-launcher\configure-program-plugin.ps1"
Update-ProgramPluginConfig -Directories @("C:\path\to\other\shortcuts")
```

**Via Flow Launcher UI:**

1. Settings → Plugins → **Program**
2. Under **Program Sources**, click **Add**
3. Browse to your shortcuts directory
4. Click **Reindex**

---

## Configuration

### Changing the Hotkey

**Default**: Alt+Space

**To customize:**

1. Press **Alt+Space** to open Flow Launcher
2. Type `Settings` and press Enter
3. In the **General** tab, find **Hotkey** section
4. Click the hotkey field and press your desired key combination
5. Click **Save**

**Popular alternatives:**
- `Win+Space` (Windows Search alternative)
- `Ctrl+Space` (popular in Unix-like systems)
- `Win+Alt+Space` (old Keypirinha default)

### Themes

Flow Launcher supports extensive theming:

1. Open Flow Launcher (**Alt+Space**)
2. Type `Settings` → **Theme** tab
3. Browse built-in themes or download from the community
4. Select a theme and click **Apply**

**Popular themes:**
- **Dark** (default)
- **Light**
- **Dracula**
- **Nord**

### Customizing Search Results

**Adjust result count:**

Settings → General → **Max Results** (default: 5, max: 20)

**Enable/Disable plugins:**

Settings → Plugins → Toggle plugins on/off

---

## Plugin System

Flow Launcher's plugin ecosystem extends its capabilities beyond basic search.

### Recommended Plugins

- **Everything**: Ultra-fast file search (requires Everything search engine)
- **Explorer**: Quick access to system folders
- **WindowWalker**: Switch between open windows
- **Color Picker**: Convert colors between formats (hex, RGB, HSL)

### Installing Plugins

1. Open Flow Launcher (**Alt+Space**)
2. Type `pm install <plugin-name>`
3. Or: Settings → Plugins → **Store** tab → Browse and install

### Using the Program Plugin for Shortcuts

The Shortcuts project uses the built-in **Program plugin** to index `.url` shortcut files directly from source directories.

**How it works:**

1. Shortcut files (`.url`, `.bat`, `.cmd`) are stored across `shortcuts/` and `shortcuts_private/`
2. The Program plugin is configured to scan these root directories
3. Custom suffixes (`.url`, `.bat`, `.cmd`) are enabled for indexing
4. Shortcuts appear directly in search results

**Configuration is automated** by `configure-program-plugin.ps1`, which edits:

```
%USERPROFILE%\scoop\persist\flow-launcher\UserData\Settings\Plugins\Flow.Launcher.Plugin.Program\Settings.json
```

**Benefits:**

- Uses a built-in plugin (no community plugin installation required)
- Supports multiple source directories natively (e.g., multiple git repos)
- Directories can be added via script or UI

---

## Migration from Keypirinha

If you previously used Keypirinha with the Shortcuts project:

### What Changes

| Feature | Keypirinha | Flow Launcher |
|---------|------------|---------------|
| **Hotkey** | Win+Alt+Space | Alt+Space |
| **Refresh** | Manual ("Refresh catalog") | Reindex via Program plugin settings |
| **Config** | `config/keypirinha/` | Scoop persist directory |
| **Updates** | Abandoned (2021) | Active development |

### Migration Steps

1. **Run the updated Shortcuts installer** (Flow Launcher installs automatically)
2. **Test Flow Launcher**: Press Alt+Space and search for a shortcut
3. **Uninstall Keypirinha** (optional):
   ```powershell
   scoop uninstall keypirinha
   ```
4. **Update muscle memory**: Start using Alt+Space instead of Win+Alt+Space

### Keeping Both Launchers

You can run both Flow Launcher and Keypirinha simultaneously if desired:

- Flow Launcher: Alt+Space
- Keypirinha: Win+Alt+Space (or configure different hotkey)

This allows gradual migration without disrupting your workflow.

---

## Troubleshooting

### Flow Launcher doesn't start

**Check:**

1. Is Flow Launcher installed?
   ```powershell
   scoop list flow-launcher
   ```
2. Is it running? (Check system tray for Flow Launcher icon)
3. Launch manually:
   ```powershell
   & "$env:USERPROFILE\scoop\apps\flow-launcher\current\Flow.Launcher.exe"
   ```

### Hotkey doesn't work

**Possible causes:**

1. **Another app is using Alt+Space**
   - Common culprits: Windows PowerToys, other launchers
   - Solution: Change Flow Launcher hotkey in Settings

2. **Flow Launcher isn't running**
   - Check system tray
   - Launch Flow Launcher manually

3. **Hotkey was changed accidentally**
   - Open Flow Launcher via Start Menu
   - Go to Settings → General → Hotkey

### Shortcuts don't appear

**Solution:**

1. Verify shortcut files exist in your `shortcuts/` or `shortcuts_private/` directories
2. Check that the Program plugin is configured:
   ```powershell
   Get-Content "$env:USERPROFILE\scoop\persist\flow-launcher\UserData\Settings\Plugins\Flow.Launcher.Plugin.Program\Settings.json"
   ```
   - `ProgramSources` should list your directories
   - `CustomSuffixes` should contain `"url"`, `"bat"`, `"cmd"`
   - `UseCustomSuffixes` should be `true`
3. Reconfigure if needed:
   ```powershell
   . "$env:USERPROFILE\shortcuts\tools\flow-launcher\configure-program-plugin.ps1"
   Update-ProgramPluginConfig -Directories @("$env:USERPROFILE\shortcuts", "$env:USERPROFILE\shortcuts_private")
   ```
4. Reindex: Settings → Plugins → Program → **Reindex**

### Flow Launcher is slow

**Optimization tips:**

1. **Disable unused plugins**: Settings → Plugins → Disable plugins you don't use
2. **Reduce Max Results**: Settings → General → Max Results (lower = faster)
3. **Clear cache**: Settings → General → **Clear Cache**
4. **Check for updates**: Outdated versions may have performance issues
   ```powershell
   scoop update flow-launcher
   ```

### New shortcuts not appearing after adding files

**Check:**

1. **Reindex the Program plugin**:
   - Settings → Plugins → Program → **Reindex**

2. **Restart Flow Launcher** if reindex doesn't help:
   - Right-click Flow Launcher icon in system tray
   - Click **Exit**
   - Launch again from Start Menu

3. **Verify Program plugin configuration**:
   ```powershell
   Get-Content "$env:USERPROFILE\scoop\persist\flow-launcher\UserData\Settings\Plugins\Flow.Launcher.Plugin.Program\Settings.json" | ConvertFrom-Json | Select-Object ProgramSources, CustomSuffixes, UseCustomSuffixes
   ```

---

## Advanced Configuration

### Auto-Start on Login

Flow Launcher should auto-start by default. If not:

1. Open Task Manager (Ctrl+Shift+Esc)
2. Go to **Startup** tab
3. Find **Flow Launcher** and set to **Enabled**

**Or via PowerShell:**

```powershell
$targetExe = "$env:USERPROFILE\scoop\apps\flow-launcher\current\Flow.Launcher.exe"
$shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Flow.Launcher.lnk"
$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($shortcutPath)
$link.TargetPath = $targetExe
$link.Save()
```

### Custom Search Scope

Configure which directories Flow Launcher scans:

1. Settings → Plugins → **Program**
2. Add/remove directories in **Indexed Programs**
3. Click **Reindex** after changes

### Query Syntax

Flow Launcher supports advanced query syntax:

- `>`: Execute shell command (e.g., `> ipconfig`)
- `?`: Web search (e.g., `? flow launcher`)
- `+`: Calculator (e.g., `+ 2+2`)
- `/`: Navigate folders (e.g., `/C:\Users`)

---

## Resources

- **Official Website**: [flowlauncher.com](https://flowlauncher.com)
- **GitHub**: [github.com/Flow-Launcher/Flow.Launcher](https://github.com/Flow-Launcher/Flow.Launcher)
- **Documentation**: [flowlauncher.com/docs](https://flowlauncher.com/docs)
- **Plugin Store**: Settings → Plugins → Store
- **Community**: Discord server linked on official website

---

## Comparison: Flow Launcher vs. Keypirinha

| Feature | Flow Launcher | Keypirinha |
|---------|---------------|------------|
| **Development Status** | ✅ Active (2024+) | ❌ Abandoned (2021) |
| **Last Update** | Regular updates | 2020 |
| **Plugin Store** | ✅ Built-in with 100+ plugins | ❌ Manual installation |
| **Auto-Reload** | ✅ Yes | ❌ Manual refresh required |
| **Windows 11 Support** | ✅ Full support | ⚠️ Limited/untested |
| **Community** | ✅ Active Discord/GitHub | ❌ Inactive |
| **Theming** | ✅ Extensive | ✅ Basic |
| **Performance** | ✅ Fast | ✅ Fast |
| **Open Source** | ✅ Yes (MIT) | ✅ Yes (Zlib) |

**Verdict**: Flow Launcher is the recommended choice for future-proof, actively maintained launcher integration.

---

[← Back to README](../README.md)
