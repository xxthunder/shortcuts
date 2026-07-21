[← Back to Docs](../wsl-manager.md)

# WSL Manager — C4 Architecture (SC-016)

This document describes the planned architecture for the WSL Manager with the modernized PwshSpectreConsole TUI, following the [C4 model](https://c4model.com/) at three levels: Context, Container, and Component.

All diagrams use [Mermaid.js](https://mermaid.js.org/) C4 syntax.

---

## Level 1 — System Context

Shows the WSL Manager system in relation to its users and the external systems it interacts with.

```mermaid
C4Context
    title WSL Manager — System Context Diagram

    Person(user, "Developer / DevOps Engineer", "Manages WSL distributions for local development environments")

    System(wslManager, "WSL Manager", "PowerShell-based interactive tool for managing WSL distributions: install, clone, remove, update, configure Docker/Podman/DevPod, proxy, and user setup")

    System_Ext(wsl2, "Windows Subsystem for Linux 2", "Microsoft's Linux compatibility layer; manages distribution lifecycle via wsl.exe")
    System_Ext(psGallery, "PowerShell Gallery", "Module repository; source for PwshSpectreConsole dependency")
    System_Ext(dockerRepo, "Docker / Podman Repositories", "APT package repositories for container engine installation inside WSL distributions")
    System_Ext(devpodCdn, "DevPod CDN", "Download endpoint for the DevPod CLI binary")
    System_Ext(corpProxy, "Corporate Proxy / PAC", "Optional corporate proxy infrastructure; auto-detected from Windows registry")

    Rel(user, wslManager, "Interacts via TUI or CLI", "Terminal / pwsh")
    Rel(wslManager, wsl2, "Invokes wsl.exe for distribution lifecycle", "CLI / process")
    Rel(wslManager, psGallery, "Installs PwshSpectreConsole module", "Install-Module")
    Rel(wslManager, dockerRepo, "Installs Docker/Podman inside WSL distros", "bash scripts via wsl.exe")
    Rel(wslManager, devpodCdn, "Downloads DevPod CLI into WSL distros", "curl via wsl.exe")
    Rel(wslManager, corpProxy, "Reads proxy settings from registry/PAC", "Windows registry")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Level 2 — Container Diagram

Zooms into the WSL Manager system, showing its internal containers (executable units / deployable modules) and how they collaborate.

```mermaid
C4Container
    title WSL Manager — Container Diagram

    Person(user, "Developer", "Manages WSL distributions")

    System_Boundary(wslManagerSystem, "WSL Manager System") {
        Container(entryPoint, "wsl-manager.ps1", "PowerShell Script", "CLI entry point; parses parameters and delegates to the manager orchestrator")
        Container(tuiLayer, "TUI Layer (manager.ps1)", "PowerShell + PwshSpectreConsole", "Interactive menu with arrow-key navigation, rich tables, and confirmation dialogs; SC-016 modernization (menu and table shipped, distro picker and confirmations planned)")
        Container(dispatcher, "Command Dispatcher (commands.ps1)", "PowerShell Script", "Routes commands to action functions; contains all Invoke-* workflow handlers and distro selection logic")
        Container(wslLib, "WSL Library (lib/wsl/)", "PowerShell Modules", "Core WSL operations: distro lifecycle, exec, user, wsl.conf, Docker, Podman, DevPod, proxy")
        Container(bashScripts, "Bash Install Scripts", "Shell Scripts", "Executed inside WSL distros for Docker, Podman, DevPod installation, and proxy configuration")
        Container(utilsLib, "Utilities (lib/utils/)", "PowerShell Module", "Shared helpers: Invoke-CommandLine, console output, path management, CI detection")
    }

    System_Ext(wsl2, "WSL 2 (wsl.exe)", "Distribution lifecycle management")
    System_Ext(spectreConsole, "PwshSpectreConsole", "Terminal UI primitives: selection prompts, tables, confirmations")
    System_Ext(proxyInfra, "Corporate Proxy / PAC", "Proxy auto-detection via Windows registry")

    Rel(user, entryPoint, "Runs with command args", "pwsh CLI")
    Rel(user, tuiLayer, "Interacts via keyboard", "Terminal")
    Rel(entryPoint, tuiLayer, "Delegates interactive mode", "dot-source")
    Rel(entryPoint, dispatcher, "Delegates CLI commands", "function call")
    Rel(tuiLayer, dispatcher, "Routes menu selection to command", "Invoke-WslCommand")
    Rel(tuiLayer, spectreConsole, "Renders menus, tables, confirmations", "Read-SpectreSelection, Format-SpectreTable")
    Rel(dispatcher, wslLib, "Calls WSL operations", "function calls")
    Rel(wslLib, wsl2, "Manages distributions", "wsl.exe CLI")
    Rel(wslLib, bashScripts, "Executes inside distros", "wsl.exe --exec bash")
    Rel(wslLib, utilsLib, "Uses shared helpers", "dot-source")
    Rel(wslLib, proxyInfra, "Reads proxy settings", "registry / setProxy.ps1")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Level 3 — Component Diagram

Zooms into the WSL Library container, showing the individual PowerShell modules and their responsibilities.

```mermaid
C4Component
    title WSL Manager — Component Diagram (WSL Library)

    Container_Boundary(tuiContainer, "TUI Layer") {
        Component(showMenu, "Show-WslMenu", "Shipped SC-016b", "Arrow-key menu using Read-SpectreSelection; replaces Read-Host letter input")
        Component(showTable, "Show-WslDistroTable", "Shipped SC-016c", "Rich distro table using Format-SpectreTable with colored status columns")
        Component(selectDistro, "Select-WslDistro", "Planned SC-016d", "Distro picker using Read-SpectreSelection; replaces numbered Read-Host input")
        Component(confirmAction, "Confirm-DestructiveAction", "Planned SC-016e", "Read-SpectreConfirm for remove, terminate, shutdown operations")
    }

    Container_Boundary(dispatcherContainer, "Command Dispatcher (commands.ps1)") {
        Component(invokeWslCmd, "Invoke-WslCommand", "PowerShell", "Central dispatch: routes command string to the matching Invoke-* handler")
        Component(invokeCreate, "Invoke-CreateDistro", "PowerShell", "Install workflow: lists available distros, prompts for selection, calls New-WslDistro")
        Component(invokeClone, "Invoke-CloneDistro", "PowerShell", "Clone workflow: select source distro, prompt target name, calls Copy-WslDistro")
        Component(invokeRemove, "Invoke-RemoveDistro", "PowerShell", "Remove workflow: select distro, calls Remove-WslDistro")
        Component(invokeSetup, "Invoke-Setup* Handlers", "PowerShell", "Setup workflows: User, Docker, Podman, DevPod, Proxy — each delegates to lib functions")
        Component(invokeOps, "Invoke-TerminateDistro / Invoke-ShutdownWsl", "PowerShell", "Operational commands: stop single distro or shutdown entire WSL subsystem")
    }

    Container_Boundary(wslLibContainer, "WSL Library (lib/wsl/)") {
        Component(core, "core.ps1", "PowerShell", "WSL status checks: Test-WslInstalled, Assert-Wsl2Installed, Get-WslDistroList, Get-WslDistroState, Get-WslDistroType, Stop-WslDistro")
        Component(install, "install.ps1", "PowerShell", "Distribution provisioning: Get-WslAvailableDistro, New-WslDistro")
        Component(ops, "ops.ps1", "PowerShell", "Distribution operations: Remove-WslDistro, Copy-WslDistro, Update-WslDistro, Stop-WslSubsystem, Merge-WslConfig, Invoke-ConfigureWsl")
        Component(exec, "exec.ps1", "PowerShell", "Command execution bridge: Invoke-WslDistroCommand, Invoke-WslDistroScript — runs bash inside WSL distros")
        Component(wslConf, "wsl-conf.ps1", "PowerShell", "Per-distro configuration: Set-WslConf, Test-WslSystemdConfigured, Test-WslInteropConfigured, Test-WslAutomountConfigured")
        Component(userMgmt, "user.ps1", "PowerShell", "User management: New-WslUser, Get-WslDefaultUser")
        Component(docker, "docker.ps1", "PowerShell", "Docker Engine lifecycle: Test-WslDockerInstalled, Install-WslDockerEngine")
        Component(podman, "podman.ps1", "PowerShell", "Rootless Podman lifecycle: Test-WslPodmanInstalled, Install-WslPodman")
        Component(devpod, "devpod.ps1", "PowerShell", "DevPod CLI lifecycle: Test-WslDevPodInstalled, Install-WslDevPod")
        Component(proxy, "proxy.ps1", "PowerShell", "Proxy configuration: Install-WslProxy auto-detects PAC/registry/px, configures profile.d + zshenv env, apt, Docker, Podman")
    }

    Container_Boundary(scriptContainer, "Bash Install Scripts (lib/wsl/scripts/)") {
        Component(dockerSh, "install-docker.sh", "Bash", "Installs Docker CE, Docker Compose; configures binfmt.d; adds user to docker group")
        Component(podmanSh, "install-podman.sh", "Bash", "Installs Podman rootless; configures subuid/subgid and registries")
        Component(devpodSh, "install-devpod.sh", "Bash", "Downloads DevPod CLI binary; configures container provider (docker/podman)")
        Component(proxySh, "setup-proxy.sh", "Bash", "Writes proxy env vars to /etc/profile.d (sourced from zshenv), apt.conf, Docker config, Podman config")
    }

    Rel(showMenu, invokeWslCmd, "Selected command")
    Rel(showTable, core, "Get-WslDistroList -Detailed")
    Rel(selectDistro, core, "Get-WslDistroList -Detailed")
    Rel(confirmAction, invokeOps, "Confirmed destructive action")

    Rel(invokeWslCmd, invokeCreate, "install")
    Rel(invokeWslCmd, invokeClone, "clone")
    Rel(invokeWslCmd, invokeRemove, "remove")
    Rel(invokeWslCmd, invokeSetup, "setup-*")
    Rel(invokeWslCmd, invokeOps, "terminate / shutdown")

    Rel(invokeCreate, install, "New-WslDistro")
    Rel(invokeClone, ops, "Copy-WslDistro")
    Rel(invokeRemove, ops, "Remove-WslDistro")
    Rel(invokeSetup, docker, "Install-WslDockerEngine")
    Rel(invokeSetup, podman, "Install-WslPodman")
    Rel(invokeSetup, devpod, "Install-WslDevPod")
    Rel(invokeSetup, proxy, "Install-WslProxy")
    Rel(invokeSetup, userMgmt, "New-WslUser")
    Rel(invokeOps, core, "Stop-WslDistro")
    Rel(invokeOps, ops, "Stop-WslSubsystem")

    Rel(docker, exec, "Invoke-WslDistroScript")
    Rel(docker, wslConf, "Set-WslConf, Test-*Configured")
    Rel(podman, exec, "Invoke-WslDistroScript")
    Rel(podman, wslConf, "Set-WslConf, Test-*Configured")
    Rel(devpod, exec, "Invoke-WslDistroScript")
    Rel(proxy, exec, "Invoke-WslDistroScript")
    Rel(userMgmt, exec, "Invoke-WslDistroCommand")
    Rel(userMgmt, wslConf, "Set-WslConf")

    Rel(exec, dockerSh, "install-docker.sh")
    Rel(exec, podmanSh, "install-podman.sh")
    Rel(exec, devpodSh, "install-devpod.sh")
    Rel(exec, proxySh, "setup-proxy.sh")

    UpdateLayoutConfig($c4ShapeInRow="4", $c4BoundaryInRow="1")
```

---

## SC-016 Change Impact Summary

The following table maps the SC-016 changes to the affected components and their current status:

| SC-016 Change | Current Implementation | Planned Implementation | Affected Components | Status |
|---|---|---|---|---|
| Menu selection | `Read-Host` letter input | `Read-SpectreSelection` arrow-key navigation | `manager.ps1` → `Show-WslMenu` (new) | Done (SC-016b) |
| Distro table | `Write-Host` with basic colors | `Format-SpectreTable` with borders and colored status | `commands.ps1` → `Show-WslDistroTable` (new) | Done (SC-016c) |
| Distro picker | `Read-Host` numbered input | `Read-SpectreSelection` for distro lists | `commands.ps1` → `Select-WslDistro` (modified) | Open (SC-016d) |
| Destructive confirmations | Implicit (no confirmation in TUI) | `Read-SpectreConfirm` for remove, terminate, shutdown | `commands.ps1` → `Confirm-DestructiveAction` (new) | Open (SC-016e) |
| Status coloring | `Write-Host -ForegroundColor` | Spectre markup: `[green]Running[/]`, `[red]Stopped[/]` | `Show-WslDistroTable` | Done (SC-016c) |
| Module dependency | None | `PwshSpectreConsole` v2 from PSGallery | Setup process / `Install-Module` | Done (SC-016a) |

### Key architectural principle

> Only the **TUI layer** changes. The `commands.ps1` action functions (`Invoke-*`) and the entire `lib/wsl/` library remain structurally unchanged.

[← Back to Docs](../wsl-manager.md)
