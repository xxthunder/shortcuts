---
name: powershell-wrapper-creator
description: Create .bat wrappers for PowerShell scripts following project conventions. Use when: (1) Creating executable PowerShell scripts, (2) Making scripts launchable from command line, (3) Making scripts accessible from Keypirinha, (4) Following the PowerShell Script Wrapper Convention documented in AGENTS.md.
---

# PowerShell Script Wrapper Creator

Create .bat wrappers for PowerShell scripts to make them easily executable.

## The Wrapper Convention

Executable PowerShell scripts should have a .bat wrapper in the same directory.

### Benefits

- Users can run `script-name` instead of `powershell -File path/to/script-name.ps1`
- Batch wrapper handles PowerShell execution policy automatically
- Arguments are passed through automatically via `%*`
- Consistent user experience across all executable scripts
- Works with Keypirinha launcher

## Wrapper Template

```batch
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0script-name.ps1" %*
```

### Template Breakdown

- `@echo off` - Suppress command echoing
- `powershell` - Use Windows PowerShell 5.1 (inbox on all Windows 10+, ensures bootstrapping works)
- `-ExecutionPolicy Bypass` - Run without policy restrictions
- `-File` - Execute script file
- `"%~dp0script-name.ps1"` - Path to PS1 file in same directory
- `%*` - Pass all arguments to PowerShell script

## Creating Wrappers

### Manual Creation

1. Create the PowerShell script: `my-script.ps1`
2. Create the wrapper: `my-script.bat`
3. Use the template, replacing `script-name` with `my-script`

### Example Structure

```
tools/wsl-manager/
├── wsl-manager.ps1      # PowerShell script
└── wsl-manager.bat      # Wrapper
```

Wrapper content:
```batch
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0wsl-manager.ps1" %*
```

## Why `powershell` instead of `pwsh`?

All batch wrappers **must** use `powershell` (Windows PowerShell 5.1), not `pwsh` (PowerShell 7):

- This project targets **PowerShell 5.1+** (see `development-principles.md`)
- PowerShell 5.1 is inbox on all Windows 10+ machines - no install required
- PowerShell 7 (`pwsh`) is installed via Scoop, which is itself bootstrapped by these scripts
- Using `pwsh` in wrappers creates a chicken-and-egg problem on fresh machines
- All scripts must use only 5.1-compatible syntax, so they work under both versions

## Automated Wrapper Creation

### PowerShell Function

```powershell
function New-BatWrapper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("powershell", "pwsh")]
        [string]$PowerShellVersion = "powershell"
    )
    
    # Validate script exists
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "Script not found: $ScriptPath"
        return
    }
    
    # Get script name without extension
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($ScriptPath)
    $scriptDir = Split-Path $ScriptPath -Parent
    
    # Create wrapper path
    $wrapperPath = Join-Path $scriptDir "$scriptName.bat"
    
    # Check if wrapper already exists
    if (Test-Path $wrapperPath) {
        Write-Warning "Wrapper already exists: $wrapperPath"
        $overwrite = Read-Host "Overwrite? (y/n)"
        if ($overwrite -ne "y") {
            return
        }
    }
    
    # Create wrapper content
    $wrapperContent = @"
@echo off
$PowerShellVersion -ExecutionPolicy Bypass -File "%~dp0$scriptName.ps1" %*
"@
    
    # Write wrapper
    Set-Content -Path $wrapperPath -Value $wrapperContent
    Write-Information "Created wrapper: $wrapperPath"
}

# Usage
New-BatWrapper -ScriptPath ".\tools\my-script.ps1"
```

### Batch Creation for Directory

```powershell
function New-BatWrappersForDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )
    
    $ps1Files = Get-ChildItem -Path $Directory -Filter "*.ps1" -Recurse
    
    foreach ($ps1File in $ps1Files) {
        # Skip test files
        if ($ps1File.Name -like "*.Tests.ps1") {
            continue
        }
        
        New-BatWrapper -ScriptPath $ps1File.FullName
    }
}

# Usage
New-BatWrappersForDirectory -Directory ".\tools\wsl-manager"
```

## When to Create Wrappers

### Create Wrapper For:

- Scripts meant to be run by users directly
- Scripts launched from command line
- Scripts accessible via Keypirinha
- Utility scripts in tools/ directory
- Management scripts (install, update, etc.)

### Don't Create Wrapper For:

- Test files (`*.Tests.ps1`)
- Library files (sourced with dot-sourcing)
- Internal helper scripts
- CI-only scripts
- Scripts in .bootstrap/ (they have their own patterns)

## Testing Wrappers

### Test from Command Line

```bash
# Test wrapper
script-name arg1 arg2

# Should be equivalent to:
powershell -File script-name.ps1 arg1 arg2
```

### Test from Keypirinha

1. Create wrapper
2. Refresh Keypirinha catalog
3. Press Win+Alt+Space
4. Type script name
5. Press Enter

## Template Asset

See `assets/wrapper-template.bat` for a template file.

## Best Practices

1. **Same directory** - Wrapper must be in same directory as .ps1 file
2. **Same name** - Wrapper must have same name as .ps1 file (except extension)
3. **Use powershell** - Use Windows PowerShell 5.1 for compatibility (see development-principles.md)
4. **Pass arguments** - Always include `%*` to pass arguments
5. **Bypass execution policy** - Use `-ExecutionPolicy Bypass`
6. **Test** - Verify wrapper works before committing
7. **Commit together** - Commit .ps1 and .bat in same commit

## Troubleshooting

### Wrapper Not Found

Check:
- Wrapper is in same directory as .ps1 file
- Wrapper has correct name
- Wrapper has .bat extension

### Script Not Executing

Check:
- `%~dp0` is present (relative path to script)
- Script name matches exactly (case-sensitive on some systems)
- PowerShell version is installed (pwsh vs powershell)

### Arguments Not Passed

Check:
- `%*` is included at end of command
- Arguments are quoted if they contain spaces
