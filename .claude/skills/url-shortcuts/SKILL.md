---
name: url-shortcuts
description: "Create and manage .url shortcut files in the links/ directory of the Shortcuts project. Use when: (1) Creating new shortcuts, (2) Adding tool shortcuts, (3) Adding website shortcuts, (4) Organizing shortcuts in the links/ directory."
---

# URL Shortcuts

Create and manage .url shortcut files in `links/` for quick access to tools and websites.

## Shortcut File Format

Shortcuts are standard Windows .url files:

```ini
[InternetShortcut]
URL=https://example.com
```

## Creating Shortcuts

### Web URL Shortcut

```ini
[InternetShortcut]
URL=https://github.com
```

Save as: `links/GitHub.url`

### Application Shortcut

```ini
[InternetShortcut]
URL=C:\Program Files\App\app.exe
```

Save as: `links/MyApp.url`

### File/Folder Shortcut

```ini
[InternetShortcut]
URL=C:\Users\username\Documents
```

Save as: `links/Documents.url`

## Shortcut Organization

### Directory Structure

```
links/
├── web/
│   ├── GitHub.url
│   ├── Google.url
│   └── Gmail.url
├── tools/
│   ├── VSCode.url
│   ├── Postman.url
│   └── Docker.url
└── local/
    ├── Documents.url
    └── Projects.url
```

### Naming Conventions

- Use descriptive, searchable names
- PascalCase or Title Case
- No spaces in directory names (use subdirectories)
- Extension: `.url`

## Creating Shortcuts in PowerShell

### Manual Creation

```powershell
$shortcutContent = @"
[InternetShortcut]
URL=https://github.com
"@

$shortcutPath = Join-Path (Join-Path $PSScriptRoot "links") "GitHub.url"
Set-Content -Path $shortcutPath -Value $shortcutContent
```

### Using Helper Function

```powershell
function New-UrlShortcut {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $false)]
        [string]$Category = ""
    )

    $content = @"
[InternetShortcut]
URL=$Url
"@

    $linksDir = Join-Path $PSScriptRoot "links"

    if ($Category) {
        $categoryDir = Join-Path $linksDir $Category
        if (-not (Test-Path $categoryDir)) {
            New-Item -Path $categoryDir -ItemType Directory | Out-Null
        }
        $shortcutPath = Join-Path $categoryDir "$Name.url"
    } else {
        $shortcutPath = Join-Path $linksDir "$Name.url"
    }

    Set-Content -Path $shortcutPath -Value $content
    Write-Information "Created shortcut: $shortcutPath"
}

# Usage
New-UrlShortcut -Name "GitHub" -Url "https://github.com" -Category "web"
```

## Common Shortcuts

### Development Tools

```powershell
# VS Code
New-UrlShortcut -Name "VSCode" -Url "C:\Users\$env:USERNAME\scoop\apps\vscode\current\Code.exe"

# Git Bash
New-UrlShortcut -Name "GitBash" -Url "C:\Program Files\Git\git-bash.exe"

# PowerShell
New-UrlShortcut -Name "PowerShell" -Url "pwsh.exe"
```

### Websites

```powershell
# GitHub
New-UrlShortcut -Name "GitHub" -Url "https://github.com"

# Stack Overflow
New-UrlShortcut -Name "StackOverflow" -Url "https://stackoverflow.com"

# Documentation
New-UrlShortcut -Name "PowerShellDocs" -Url "https://docs.microsoft.com/powershell"
```

### Local Folders

```powershell
# Projects
New-UrlShortcut -Name "Projects" -Url "C:\Users\$env:USERNAME\Projects"

# Downloads
New-UrlShortcut -Name "Downloads" -Url "C:\Users\$env:USERNAME\Downloads"
```

## Shortcut Templates

See `assets/shortcut-template.url` for a template file.

## Best Practices

1. **Descriptive names** - Use clear, searchable names
2. **Organize by category** - Use subdirectories for organization
3. **Test shortcuts** - Verify URLs/paths are correct
4. **Use environment variables** - For user-specific paths (`$env:USERNAME`)
5. **Document shortcuts** - Comment complex shortcuts
6. **Validate paths** - Check paths exist before creating shortcuts

## Interactive Shortcut Creator

```powershell
#Requires -Version 5.1

. "$PSScriptRoot\lib\utils\utils.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$name = Read-Host "Shortcut name"
$url = Read-Host "URL or path"
$category = Read-Host "Category (optional, press Enter to skip)"

New-UrlShortcut -Name $name -Url $url -Category $category

Write-Host "`nShortcut created!" -ForegroundColor Green
```

## Batch Shortcut Creation

```powershell
$shortcuts = @(
    @{ Name = "GitHub"; Url = "https://github.com"; Category = "web" }
    @{ Name = "Gmail"; Url = "https://gmail.com"; Category = "web" }
    @{ Name = "VSCode"; Url = "code"; Category = "tools" }
)

foreach ($shortcut in $shortcuts) {
    New-UrlShortcut @shortcut
}

Write-Host "`nAll shortcuts created!" -ForegroundColor Green
```
