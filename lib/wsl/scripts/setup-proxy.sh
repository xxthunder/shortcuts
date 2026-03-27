#!/bin/bash

# setup-proxy.sh
# Configures or removes proxy settings inside a WSL distribution
# Targets: .profile, apt, Docker client, Podman (containers.conf)
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

MARKER_BEGIN="# BEGIN wsl-manager proxy"
MARKER_END="# END wsl-manager proxy"

# --- Remove mode ---
remove_proxy_configs() {
    log_info "Removing proxy configurations for user '$TARGET_USER'..."

    # Remove managed block from .profile
    if grep -q "$MARKER_BEGIN" "$PROFILE" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$PROFILE"
        log_info "Removed proxy block from $PROFILE"
    else
        log_info "No proxy block found in $PROFILE (already clean)"
    fi

    # Migration: also remove from .bashrc (old location)
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

    log_info "Proxy configurations removed successfully!"
}

if [ "$REMOVE_MODE" = true ]; then
    remove_proxy_configs || { log_error "Failed to remove proxy configurations"; exit 2; }
    exit 0
fi

# --- Configure mode ---

# 2. Configure .profile managed block
# Environment variables go in .profile so they are available in login shells
# (both interactive and non-interactive, e.g. wsl.exe --exec bash -l script.sh).
# .bashrc is only sourced for interactive shells and is skipped by the
# non-interactive guard (case $- in *i*) ;; *) return ;; esac).
log_info "Configuring proxy environment variables in $PROFILE..."

configure_profile() {
    # Remove existing managed block if present
    if grep -q "$MARKER_BEGIN" "$PROFILE" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$PROFILE"
        log_info "Removed existing proxy block from $PROFILE"
    fi

    # Migration: also remove from .bashrc (old location)
    if grep -q "$MARKER_BEGIN" "$BASHRC" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$BASHRC"
        log_info "Removed legacy proxy block from $BASHRC"
    fi

    # Append new managed block to .profile
    cat >> "$PROFILE" <<EOF
$MARKER_BEGIN
export http_proxy="$PROXY_URL"
export https_proxy="$PROXY_URL"
export HTTP_PROXY="$PROXY_URL"
export HTTPS_PROXY="$PROXY_URL"
export no_proxy="$NO_PROXY"
export NO_PROXY="$NO_PROXY"
$MARKER_END
EOF

    log_info "Proxy environment variables configured in $PROFILE"
}
configure_profile || { log_error "Failed to configure .profile"; exit 2; }

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

if ! grep -q "$MARKER_BEGIN" "$PROFILE"; then
    log_error ".profile proxy block not found"
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

log_info "Proxy configuration completed successfully!"
exit 0
