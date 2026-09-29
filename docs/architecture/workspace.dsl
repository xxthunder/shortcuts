workspace "Shortcuts" "Keyboard-driven launcher and automation toolkit for Windows. Single source of the architecture diagrams (SC-062)." {

    !identifiers flat

    model {
        developer = person "Developer" "Works on a Windows machine and starts tools and links from the keyboard."

        shortcuts = softwareSystem "Shortcuts" "Installs a keyboard-driven toolset on Windows and manages WSL distributions for development." {
            installer = container "Installer and updater" "Bootstraps Scoop and git, clones the repository, installs the mandatory and optional tools and PwshSpectreConsole, copies the Keypirinha profile and creates the hotkeys startup shortcut. bin/install.ps1, bin/update.bat." "Windows PowerShell 5.1"
            launcherCatalog = container "Launcher catalog" "Internet shortcuts to web apps and tools that the launchers index. links/*.url." "Internet shortcut files" "Data store"
            helperCommands = container "Helper commands" "Small commands launched by name: rdp.cmd opens a Remote Desktop session, getUserInfo.ps1 shows a domain user's details. bin/." "cmd, PowerShell"
            hotkeys = container "Hotkeys" "Global hotkeys, started at login through a startup shortcut. tools/AutoHotKey." "AutoHotkey script"
            scoopHelper = container "Scoop update helper" "Lists the Scoop apps with updates and updates the selected ones; runs in a classic console so pwsh and Windows Terminal can be updated. tools/scoop, lib/scoop/scoop.ps1." "Windows PowerShell 5.1"
            npmInstaller = container "npm package installer" "Installs or updates Node.js through Scoop and a global npm package. lib/install/install-npm-global.ps1." "PowerShell 7"
            proxyTools = container "Proxy tools" "px-proxy.ps1 installs, configures, starts and tests px; setProxy.ps1 sets the session proxy from the PAC file. tools/proxy." "PowerShell 7"
            wslManager = container "WSL Manager" "Installs, clones, updates and removes WSL distributions and prepares them for dev containers, as a TUI and a CLI. tools/wsl-manager, lib/wsl loaded through wsl.ps1." "PowerShell 7, PwshSpectreConsole" {
                menu = component "Menu and entry point" "Parses the CLI command or runs the interactive menu above the distribution table. wsl-manager.ps1, manager.ps1: Invoke-WslManager, Start-InteractiveMode, Show-WslMenu." "PowerShell"
                spectre = component "Spectre loader" "Imports PwshSpectreConsole and offers to install it when it is missing. spectre.ps1." "PowerShell"
                table = component "Distribution table" "Renders the distributions with their state. commands.ps1: Show-WslDistroTable." "PowerShell"
                picker = component "Distribution picker" "Arrow-key picker with a Back entry; resolves names and numbers for the CLI. commands.ps1: Select-WslDistro." "PowerShell"
                confirm = component "Confirmation" "[y/N] prompt before destructive actions; skipped for CLI arguments and in CI. commands.ps1: Confirm-DestructiveAction." "PowerShell"
                dispatcher = component "Command dispatcher" "Routes a command to its handler for TUI and CLI alike. commands.ps1: Invoke-WslCommand." "PowerShell"
                lifecycleHandlers = component "Lifecycle handlers" "Install, start, stop, clone, update and remove a distribution. commands.ps1: Invoke-CreateDistro, Invoke-OpenDistroShell, Invoke-TerminateDistro, Invoke-CloneDistro, Invoke-UpdateDistro, Invoke-RemoveDistro." "PowerShell"
                setupHandlers = component "Setup handlers" "Prepare a distribution for dev containers. commands.ps1: Invoke-SetupUser, Invoke-SetupCa, Invoke-SetupProxy, Invoke-SetupDocker, Invoke-SetupPodman, Invoke-SetupDevPod, Invoke-SyncSshConfig." "PowerShell"
                wslWideHandlers = component "WSL-wide handlers" "Configure WSL as a whole and repair interop. commands.ps1: Invoke-ConfigureWslDefault, Invoke-ShutdownWsl, Invoke-RepairInterop." "PowerShell"
                core = component "Status checks" "Lists distributions and their state, checks WSL 2 and systemd, stops a distribution. core.ps1." "PowerShell"
                install = component "Provisioning" "Lists the online catalog and installs a distribution. install.ps1." "PowerShell"
                ops = component "Operations" "Removes, clones and updates a distribution, opens a shell, shuts WSL down, merges the .wslconfig defaults. ops.ps1." "PowerShell"
                wslConf = component "wsl.conf" "Reads, merges and checks a distribution's /etc/wsl.conf. wsl-conf.ps1." "PowerShell"
                userMgmt = component "Users" "Creates the default user with sudo. user.ps1." "PowerShell"
                exec = component "Execution bridge" "Runs commands and Bash scripts inside a distribution through wsl.exe. exec.ps1." "PowerShell"
                docker = component "Docker setup" "Installs Docker Engine in a distribution. docker.ps1: Install-WslDockerEngine." "PowerShell"
                podman = component "Podman setup" "Installs rootless Podman in a distribution. podman.ps1: Install-WslPodman." "PowerShell"
                devpod = component "DevPod setup" "Installs the DevPod CLI and its provider. devpod.ps1: Install-WslDevPod." "PowerShell"
                ssh = component "SSH sync" "Syncs SSH keys and config between Windows and a distribution. ssh.ps1: Invoke-WslSyncSshConfig." "PowerShell"
                proxy = component "Proxy setup" "Detects px or the PAC proxy and configures a distribution for it. proxy.ps1: Install-WslProxy." "PowerShell"
                ca = component "Root CA setup" "Selects the corporate root CAs from the Windows root store, by subject pattern or as the root of an HTTPS site's certificate chain, and installs or removes them in a distribution. ca.ps1: Get-CorporateRootCertificate, Get-UrlRootCertificate, Install-WslCaCertificate, Remove-WslCaCertificate." "PowerShell"
                utils = component "Utilities" "Shared helpers: Invoke-CommandLine, console output, CI detection. lib/utils/utils.ps1." "PowerShell"
            }
            distroScripts = container "Distribution scripts" "Bash scripts that WSL Manager runs inside a distribution; they escalate with sudo themselves. lib/wsl/scripts." "Bash inside a WSL distribution" {
                installDockerSh = component "install-docker.sh" "Installs Docker CE and Compose, configures binfmt, adds the user to the docker group." "Bash"
                installPodmanSh = component "install-podman.sh" "Installs rootless Podman from the distribution's packages, enables linger and the user's Podman socket, and points DOCKER_HOST at it." "Bash"
                installDevpodSh = component "install-devpod.sh" "Downloads the DevPod CLI and configures its provider." "Bash"
                setupProxySh = component "setup-proxy.sh" "Writes the proxy settings for shells, apt, Docker and Podman." "Bash"
                setupCaSh = component "setup-ca.sh" "Writes wsl-manager-*.crt to /usr/local/share/ca-certificates and runs update-ca-certificates." "Bash"
                syncSshConfigSh = component "sync-ssh-config.sh" "Copies SSH keys into the distribution and syncs DevPod entries back to Windows." "Bash"
            }
            claudeCodeInstaller = container "Claude Code installer" "Installs or updates the Claude Code CLI with the native installer. tools/claude-code." "PowerShell"
            flowLauncherSetup = container "Flow Launcher setup" "Installs Flow Launcher as an optional launcher and configures its Program plugin to index .url files. tools/flow-launcher." "PowerShell"
            windowsTweaks = container "Windows tweaks" "Disables Caps Lock, the screen saver and more through registry files. tools/windows." "cmd, registry files"
            gitHooks = container "Git hooks" "pre-commit checks BOM and PSScriptAnalyzer on staged .ps1 files, commit-msg checks the conventional-commit subject with its backlog item; installed by install-hooks.ps1. tools/githooks." "POSIX shell, run by Git"
            architectureViewer = container "Architecture viewer" "Starts Structurizr local on this model. tools/structurizr." "Bash, PowerShell"
        }

        keypirinha = softwareSystem "Keypirinha" "Keyboard launcher; indexes the shortcuts folder and shortcuts_private." "External"
        flowLauncher = softwareSystem "Flow Launcher" "Optional keyboard launcher." "External"
        scoop = softwareSystem "Scoop" "Command-line installer for Windows with its buckets." "External"
        github = softwareSystem "GitHub" "Hosts the shortcuts repository." "External"
        psGallery = softwareSystem "PowerShell Gallery" "Source of the PwshSpectreConsole module." "External"
        windows = softwareSystem "Windows" "Registry, Internet Settings including the PAC URL, and the certificate store." "External"
        wsl = softwareSystem "Windows Subsystem for Linux" "wsl.exe and the WSL 2 distributions." "External"
        px = softwareSystem "px" "Local authenticating proxy on localhost:3128, installed through Scoop." "External"
        corpProxy = softwareSystem "Corporate proxy" "Found through the PAC file; px authenticates to it." "External"
        packageRepos = softwareSystem "Docker and Podman package repositories" "APT repositories for the container engines." "External"
        devpodReleases = softwareSystem "DevPod releases" "Download location of the DevPod CLI." "External"
        claudeInstall = softwareSystem "Claude Code installer script" "Native installer at claude.ai." "External"
        structurizrLocal = softwareSystem "Structurizr local" "The structurizr/structurizr container image, run with docker or podman." "External"

        developer -> keypirinha "Launches tools and links by name"
        developer -> flowLauncher "Launches links by name (optional)"
        developer -> hotkeys "Presses global hotkeys"
        developer -> installer "Installs and updates Shortcuts"
        developer -> menu "Runs commands or uses the menu"
        developer -> gitHooks "Commits changes; Git runs the hooks"
        keypirinha -> launcherCatalog "Indexes and opens"
        keypirinha -> helperCommands "Launches"
        keypirinha -> wslManager "Launches wsl-manager.bat"
        keypirinha -> scoopHelper "Launches update-scoop.bat"
        keypirinha -> proxyTools "Launches px-proxy.bat"
        keypirinha -> installer "Launches update.bat"
        keypirinha -> architectureViewer "Launches structurizr-local.bat"
        flowLauncher -> launcherCatalog "Indexes .url files"

        installer -> github "Clones and pulls the repository"
        installer -> scoop "Installs Scoop, git and the tool sets"
        installer -> psGallery "Installs PwshSpectreConsole"
        installer -> keypirinha "Copies the profile and starts it"
        installer -> hotkeys "Creates the startup shortcut"
        scoopHelper -> scoop "Updates apps and buckets"
        npmInstaller -> scoop "Installs Node.js"
        proxyTools -> scoop "Installs px"
        proxyTools -> px "Configures, starts, stops and tests"
        proxyTools -> windows "Reads the PAC URL from Internet Settings"
        px -> corpProxy "Authenticates upstream"
        claudeCodeInstaller -> claudeInstall "Downloads and runs"
        flowLauncherSetup -> scoop "Installs Flow Launcher"
        flowLauncherSetup -> flowLauncher "Configures the Program plugin"
        windowsTweaks -> windows "Imports registry settings"
        architectureViewer -> structurizrLocal "Runs on docs/architecture"

        menu -> spectre "Loads PwshSpectreConsole"
        menu -> table "Shows the distributions"
        menu -> dispatcher "Runs the selected command"
        spectre -> psGallery "Installs PwshSpectreConsole when missing"
        table -> core "Get-WslDistroList -Detailed"
        picker -> core "Get-WslDistroList -Detailed"
        dispatcher -> lifecycleHandlers "install, shell, terminate, clone, update, remove"
        dispatcher -> setupHandlers "setup-user, setup-ca, setup-proxy, setup-docker, setup-podman, setup-devpod, sync-ssh-config"
        dispatcher -> wslWideHandlers "configure-wsl, shutdown, repair-interop"
        lifecycleHandlers -> picker "Selects a distribution"
        lifecycleHandlers -> confirm "Confirms remove and stop"
        lifecycleHandlers -> install "New-WslDistro"
        lifecycleHandlers -> ops "Copy-, Update-, Remove-WslDistro, Open-WslDistroShell"
        lifecycleHandlers -> core "Stop-WslDistro"
        setupHandlers -> picker "Selects a distribution"
        setupHandlers -> userMgmt "New-WslUser"
        setupHandlers -> docker "Install-WslDockerEngine"
        setupHandlers -> podman "Install-WslPodman"
        setupHandlers -> devpod "Install-WslDevPod"
        setupHandlers -> ca "Install-WslCaCertificate, Remove-WslCaCertificate"
        setupHandlers -> proxy "Install-WslProxy"
        setupHandlers -> ssh "Invoke-WslSyncSshConfig"
        wslWideHandlers -> confirm "Confirms shutdown"
        wslWideHandlers -> ops "Invoke-ConfigureWsl, Stop-WslSubsystem"
        wslWideHandlers -> wslConf "Set-WslConf for interop"
        docker -> exec "Invoke-WslDistroScript"
        docker -> wslConf "Set-WslConf, Test-*Configured"
        podman -> exec "Invoke-WslDistroScript"
        podman -> wslConf "Set-WslConf, Test-*Configured"
        devpod -> exec "Invoke-WslDistroScript"
        ca -> exec "Invoke-WslDistroScript"
        ca -> windows "Reads the root certificate store"
        proxy -> exec "Invoke-WslDistroScript"
        proxy -> proxyTools "Uses the PAC and px detection of setProxy.ps1"
        ssh -> exec "Invoke-WslDistroScript"
        userMgmt -> exec "Invoke-WslDistroCommand"
        userMgmt -> wslConf "Set-WslConf"
        ops -> exec "Invoke-WslDistroCommand"
        core -> exec "Invoke-WslDistroCommand"
        exec -> utils "Invoke-CommandLine"
        core -> wsl "Lists and stops distributions"
        install -> wsl "Installs from the online catalog"
        ops -> wsl "Exports, imports, unregisters, shuts down"
        exec -> wsl "Runs commands inside a distribution"
        exec -> installDockerSh "Runs"
        exec -> installPodmanSh "Runs"
        exec -> installDevpodSh "Runs"
        exec -> setupCaSh "Runs"
        exec -> setupProxySh "Runs"
        exec -> syncSshConfigSh "Runs"
        installDockerSh -> packageRepos "Installs Docker CE"
        installPodmanSh -> packageRepos "Installs Podman"
        installDevpodSh -> devpodReleases "Downloads the DevPod CLI"
    }

    views {
        systemContext shortcuts "SystemContext" {
            include *
        }

        container shortcuts "Containers" {
            include *
        }

        component wslManager "WslManager-Overview" "All components of WSL Manager." {
            include *
        }

        component wslManager "WslManager-ManageDistributions" "User goal: manage distributions (install, start, stop, clone, update, remove)." {
            include developer menu table dispatcher lifecycleHandlers picker confirm core install ops exec wsl
        }

        component wslManager "WslManager-PrepareDistribution" "User goal: prepare a distribution for dev containers." {
            include developer menu dispatcher setupHandlers picker userMgmt docker podman devpod ca proxy ssh wslConf exec distroScripts proxyTools windows packageRepos devpodReleases
        }

        component wslManager "WslManager-ConfigureWsl" "User goal: configure WSL as a whole." {
            include developer menu dispatcher wslWideHandlers confirm ops wslConf wsl
        }

        component distroScripts "DistributionScripts" "The Bash scripts WSL Manager runs inside a distribution." {
            include *
        }

        styles {
            element "Person" {
                shape Person
                background #08427b
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Data store" {
                shape Folder
            }
        }
    }
}
