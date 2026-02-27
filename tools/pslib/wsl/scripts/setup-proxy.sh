#!/bin/bash

# setup-proxy.sh
# Configures proxy settings inside a WSL distribution
# Targets: .bashrc, apt, Docker client, Podman (containers.conf)
# This script is idempotent - safe to run multiple times (overwrites config)
# Exit Codes:
# 0: Success
# 1: Prereq failure
# 2: Configuration failure
# 3: Verification failure
# 4: Argument error

USAGE="Usage: $0 --proxy-url=<url> --no-proxy=<hosts> --username=<user>"

# 1. Validation
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root." >&2
  exit 1
fi

PROXY_URL=""
NO_PROXY=""
TARGET_USER=""

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
    *)
      ;;
  esac
done

if [ -z "$PROXY_URL" ] || [ -z "$NO_PROXY" ] || [ -z "$TARGET_USER" ]; then
    echo "Error: Missing required arguments." >&2
    echo "$USAGE" >&2
    exit 4
fi

log_info() {
    echo -e "\033[0;32m[INFO] $1\033[0m"
}

log_error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}

TARGET_HOME=$(eval echo "~$TARGET_USER")
BASHRC="$TARGET_HOME/.bashrc"

# 2. Configure .bashrc managed block
log_info "Configuring proxy environment variables in $BASHRC..."

MARKER_BEGIN="# BEGIN wsl-manager proxy"
MARKER_END="# END wsl-manager proxy"

configure_bashrc() {
    # Remove existing managed block if present
    if grep -q "$MARKER_BEGIN" "$BASHRC" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$BASHRC"
        log_info "Removed existing proxy block from $BASHRC"
    fi

    # Append new managed block
    cat >> "$BASHRC" <<EOF
$MARKER_BEGIN
export http_proxy="$PROXY_URL"
export https_proxy="$PROXY_URL"
export HTTP_PROXY="$PROXY_URL"
export HTTPS_PROXY="$PROXY_URL"
export no_proxy="$NO_PROXY"
export NO_PROXY="$NO_PROXY"
$MARKER_END
EOF

    chown "$TARGET_USER:$TARGET_USER" "$BASHRC"
    log_info "Proxy environment variables configured in $BASHRC"
}
configure_bashrc || { log_error "Failed to configure .bashrc"; exit 2; }

# 3. Configure apt proxy
log_info "Configuring apt proxy..."

configure_apt() {
    cat > /etc/apt/apt.conf.d/99proxy <<EOF
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

    chown -R "$TARGET_USER:$TARGET_USER" "$docker_dir"
    log_info "Docker client proxy configured in $docker_dir/config.json"
}
configure_docker || { log_error "Failed to configure Docker proxy"; exit 2; }

# 5. Configure Podman proxy (containers.conf)
log_info "Configuring Podman proxy..."

configure_podman() {
    local containers_dir="$TARGET_HOME/.config/containers"
    mkdir -p "$containers_dir"

    cat > "$containers_dir/containers.conf" <<EOF
[engine]
env = ["http_proxy=$PROXY_URL", "https_proxy=$PROXY_URL", "no_proxy=$NO_PROXY"]
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$containers_dir"
    log_info "Podman proxy configured in $containers_dir/containers.conf"
}
configure_podman || { log_error "Failed to configure Podman proxy"; exit 2; }

# 6. Verification
log_info "Verifying proxy configuration..."

verify_ok=true

if ! grep -q "$MARKER_BEGIN" "$BASHRC"; then
    log_error ".bashrc proxy block not found"
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
