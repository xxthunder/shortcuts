#!/bin/bash

# setup-proxy.sh
# Configures or removes proxy settings inside a WSL distribution
# Targets: /etc/profile.d/wsl-manager-proxy.sh (+ /etc/zsh/zshenv), apt, Docker client, Podman (containers.conf)
# This script is idempotent - safe to run multiple times (overwrites config)
# Exit Codes:
# 0: Success
# 1: Prereq failure
# 2: Configuration failure
# 3: Verification failure
# 4: Argument error

USAGE="Usage: $0 --proxy-url=<url> --no-proxy=<hosts> --username=<user>
       $0 --remove --username=<user>"

# 1. Validation (script runs as normal user; sudo is used for privileged commands)

PROXY_URL=""
NO_PROXY=""
TARGET_USER=""
REMOVE_MODE=false

for i in "$@"; do
  case $i in
    --proxy-url=*)
      PROXY_URL="${i#*=}"
      ;;
    --no-proxy=*)
      NO_PROXY="${i#*=}"
      ;;
    --username=*)
      TARGET_USER="${i#*=}"
      ;;
    --remove)
      REMOVE_MODE=true
      ;;
    *)
      ;;
  esac
done

if [ "$REMOVE_MODE" = true ]; then
    if [ -z "$TARGET_USER" ]; then
        echo "Error: --username is required with --remove." >&2
        echo "$USAGE" >&2
        exit 4
    fi
else
    if [ -z "$PROXY_URL" ] || [ -z "$NO_PROXY" ] || [ -z "$TARGET_USER" ]; then
        echo "Error: Missing required arguments." >&2
        echo "$USAGE" >&2
        exit 4
    fi
fi

log_info() {
    echo -e "\033[0;32m[INFO] $1\033[0m"
}

log_error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}

TARGET_HOME=$(eval echo "~$TARGET_USER")
PROFILE="$TARGET_HOME/.profile"
BASHRC="$TARGET_HOME/.bashrc"

# Proxy env vars are written to /etc/profile.d and sourced from /etc/zsh/zshenv
# so both bash and zsh see them on a normal WSL launch (see SC-042). /etc/profile.d
# is read by bash login shells (via /etc/profile) and by zsh login shells (Debian's
# /etc/zsh/zprofile sources /etc/profile). /etc/zsh/zshenv is read by every zsh
# invocation, covering non-login zsh. /etc/environment is NOT used: WSL launches
# shells without a PAM login, so pam_env never loads it.
PROFILE_D_FILE="/etc/profile.d/wsl-manager-proxy.sh"
ZSHENV_FILE="/etc/zsh/zshenv"

MARKER_BEGIN="# BEGIN wsl-manager proxy"
MARKER_END="# END wsl-manager proxy"

# Mode marker — read by `--remove` to dispatch mode-aware teardown (see SC-036e)
MODE_MARKER_DIR="/etc/wsl-manager"
MODE_MARKER_FILE="$MODE_MARKER_DIR/proxy-mode"

# --- Remove mode ---
remove_proxy_configs() {
    log_info "Removing proxy configurations for user '$TARGET_USER'..."

    # Remove the managed proxy exports file
    if [ -f "$PROFILE_D_FILE" ]; then
        sudo rm -f "$PROFILE_D_FILE"
        log_info "Removed $PROFILE_D_FILE"
    else
        log_info "No proxy file found at $PROFILE_D_FILE (already clean)"
    fi

    # Remove the zsh sourcing block
    if sudo grep -q "$MARKER_BEGIN" "$ZSHENV_FILE" 2>/dev/null; then
        sudo sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$ZSHENV_FILE"
        log_info "Removed proxy block from $ZSHENV_FILE"
    fi

    # Migration: clean legacy locations (/etc/environment, ~/.profile, ~/.bashrc)
    if sudo grep -q "$MARKER_BEGIN" /etc/environment 2>/dev/null; then
        sudo sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" /etc/environment
        log_info "Removed legacy proxy block from /etc/environment"
    fi
    if grep -q "$MARKER_BEGIN" "$PROFILE" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$PROFILE"
        log_info "Removed legacy proxy block from $PROFILE"
    fi
    if grep -q "$MARKER_BEGIN" "$BASHRC" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$BASHRC"
        log_info "Removed legacy proxy block from $BASHRC"
    fi

    # Remove apt proxy config
    if [ -f /etc/apt/apt.conf.d/99proxy ]; then
        sudo rm -f /etc/apt/apt.conf.d/99proxy
        log_info "Removed /etc/apt/apt.conf.d/99proxy"
    else
        log_info "No apt proxy config found (already clean)"
    fi

    # Remove Docker proxy config
    local docker_config="$TARGET_HOME/.docker/config.json"
    if [ -f "$docker_config" ]; then
        rm -f "$docker_config"
        log_info "Removed $docker_config"
    else
        log_info "No Docker proxy config found (already clean)"
    fi

    # Remove Podman proxy config
    local containers_conf="$TARGET_HOME/.config/containers/containers.conf"
    if [ -f "$containers_conf" ]; then
        rm -f "$containers_conf"
        log_info "Removed $containers_conf"
    else
        log_info "No Podman proxy config found (already clean)"
    fi

    # Remove mode marker last — survives partial failure so reruns dispatch correctly
    if [ -f "$MODE_MARKER_FILE" ]; then
        sudo rm -f "$MODE_MARKER_FILE"
        log_info "Removed $MODE_MARKER_FILE"
    fi

    log_info "Proxy configurations removed successfully!"
}

if [ "$REMOVE_MODE" = true ]; then
    remove_proxy_configs || { log_error "Failed to remove proxy configurations"; exit 2; }
    exit 0
fi

# --- Configure mode ---

# 2. Configure shell proxy environment
# Exports go in /etc/profile.d (read by bash and zsh login shells) and are
# sourced from /etc/zsh/zshenv (read by every zsh) so both shells see them on a
# normal WSL launch (SC-042). A per-user ~/.profile block was insufficient: zsh
# never reads it, and /etc/environment is only loaded by pam_env, which the WSL
# launch path bypasses.
log_info "Configuring proxy environment for bash and zsh..."

configure_shell_env() {
    # Managed exports file (single source of truth). Overwrite any previous version.
    sudo tee "$PROFILE_D_FILE" > /dev/null <<EOF
# Managed by wsl-manager (SC-042). Regenerated by setup-proxy; do not edit.
export http_proxy="$PROXY_URL"
export https_proxy="$PROXY_URL"
export HTTP_PROXY="$PROXY_URL"
export HTTPS_PROXY="$PROXY_URL"
export no_proxy="$NO_PROXY"
export NO_PROXY="$NO_PROXY"
EOF
    sudo chmod 0644 "$PROFILE_D_FILE"
    log_info "Wrote proxy exports to $PROFILE_D_FILE"

    # Source it from zshenv so non-login zsh shells (which skip /etc/profile) also
    # get the vars. Remove any prior block first for idempotency.
    sudo mkdir -p "$(dirname "$ZSHENV_FILE")"
    if sudo grep -q "$MARKER_BEGIN" "$ZSHENV_FILE" 2>/dev/null; then
        sudo sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$ZSHENV_FILE"
    fi
    sudo tee -a "$ZSHENV_FILE" > /dev/null <<EOF
$MARKER_BEGIN
[ -r $PROFILE_D_FILE ] && . $PROFILE_D_FILE
$MARKER_END
EOF
    log_info "Configured $ZSHENV_FILE to source $PROFILE_D_FILE"

    # Migration: remove managed blocks from legacy locations
    if sudo grep -q "$MARKER_BEGIN" /etc/environment 2>/dev/null; then
        sudo sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" /etc/environment
        log_info "Removed legacy proxy block from /etc/environment"
    fi
    if grep -q "$MARKER_BEGIN" "$PROFILE" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$PROFILE"
        log_info "Removed legacy proxy block from $PROFILE"
    fi
    if grep -q "$MARKER_BEGIN" "$BASHRC" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$BASHRC"
        log_info "Removed legacy proxy block from $BASHRC"
    fi
}
configure_shell_env || { log_error "Failed to configure shell proxy env"; exit 2; }

# 3. Configure apt proxy
log_info "Configuring apt proxy..."

configure_apt() {
    sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null <<EOF
Acquire::http::Proxy "$PROXY_URL";
Acquire::https::Proxy "$PROXY_URL";
EOF
    log_info "Apt proxy configured in /etc/apt/apt.conf.d/99proxy"
}
configure_apt || { log_error "Failed to configure apt proxy"; exit 2; }

# 4. Configure Docker client proxy
log_info "Configuring Docker client proxy..."

configure_docker() {
    local docker_dir="$TARGET_HOME/.docker"
    mkdir -p "$docker_dir"

    cat > "$docker_dir/config.json" <<EOF
{
  "proxies": {
    "default": {
      "httpProxy": "$PROXY_URL",
      "httpsProxy": "$PROXY_URL",
      "noProxy": "$NO_PROXY"
    }
  }
}
EOF
    log_info "Docker client proxy configured in $docker_dir/config.json"
}
configure_docker || { log_error "Failed to configure Docker proxy"; exit 2; }

# 5. Configure Podman proxy (containers.conf)
log_info "Configuring Podman proxy..."

configure_podman() {
    local config_dir="$TARGET_HOME/.config"
    local containers_dir="$config_dir/containers"
    mkdir -p "$containers_dir"

    cat > "$containers_dir/containers.conf" <<EOF
[engine]
env = ["http_proxy=$PROXY_URL", "https_proxy=$PROXY_URL", "no_proxy=$NO_PROXY"]
EOF
    log_info "Podman proxy configured in $containers_dir/containers.conf"
}
configure_podman || { log_error "Failed to configure Podman proxy"; exit 2; }

# 6. Verification
log_info "Verifying proxy configuration..."

verify_ok=true

if [ ! -f "$PROFILE_D_FILE" ]; then
    log_error "$PROFILE_D_FILE not found"
    verify_ok=false
fi

if ! sudo grep -q "$MARKER_BEGIN" "$ZSHENV_FILE" 2>/dev/null; then
    log_error "$ZSHENV_FILE proxy block not found"
    verify_ok=false
fi

if [ ! -f /etc/apt/apt.conf.d/99proxy ]; then
    log_error "apt proxy config not found"
    verify_ok=false
fi

if ! grep -q "httpProxy" "$TARGET_HOME/.docker/config.json" 2>/dev/null; then
    log_error "Docker proxy config not found"
    verify_ok=false
fi

if ! grep -q "http_proxy" "$TARGET_HOME/.config/containers/containers.conf" 2>/dev/null; then
    log_error "Podman proxy config not found"
    verify_ok=false
fi

if [ "$verify_ok" = false ]; then
    log_error "Proxy verification failed"
    exit 3
fi

# Write mode marker so `--remove` knows which teardown to run (see SC-036e)
sudo mkdir -p "$MODE_MARKER_DIR"
echo "basic" | sudo tee "$MODE_MARKER_FILE" > /dev/null
log_info "Wrote mode marker: $MODE_MARKER_FILE = basic"

log_info "Proxy configuration completed successfully!"
exit 0
