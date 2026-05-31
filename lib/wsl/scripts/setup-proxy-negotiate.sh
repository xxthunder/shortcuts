#!/bin/bash

# setup-proxy-negotiate.sh
# Negotiate (Kerberos) proxy mode — Phase 1 bootstrap install (SC-036b).
#
# Reads the temporary Basic-auth bootstrap URL from stdin (one line) so it
# never appears in /proc/<pid>/cmdline or any process environment. The URL is
# written to root-owned config files (apt + temp pip.conf) for the install
# step only and does not enter the user's interactive shell environment.
#
# Phase 1 ends with krb5-user, pipx, and px-proxy installed. Kerberos
# configuration, kinit, and px startup ship in SC-036c; the switch of
# .profile/apt/Docker/Podman to localhost:3128 ships in SC-036d.
#
# Exit codes:
#   0  : Success
#   1  : Prereq failure
#   2  : Configuration / install failure
#   3  : Verification failure
#   4  : Argument error

USAGE="Usage: $0 --proxy-url=<url> --no-proxy=<hosts> --username=<user>
       (bootstrap proxy URL with credentials must be piped to stdin)
       $0 --remove --username=<user>"

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

log_info() {
    echo -e "\033[0;32m[INFO] $1\033[0m"
}

log_error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}

if [ "$REMOVE_MODE" = true ]; then
    if [ -z "$TARGET_USER" ]; then
        log_error "--username is required with --remove."
        echo "$USAGE" >&2
        exit 4
    fi
    log_error "Negotiate --remove teardown is not yet implemented (ships in SC-036e)."
    log_error "Use 'wsl-manager setup-proxy' interactively or call setup-proxy.sh --remove directly to clean up Basic-mode artifacts."
    exit 4
fi

if [ -z "$PROXY_URL" ] || [ -z "$NO_PROXY" ] || [ -z "$TARGET_USER" ]; then
    log_error "Missing required arguments."
    echo "$USAGE" >&2
    exit 4
fi

# Bootstrap URL on stdin. Refuse a TTY so we don't accidentally block on a
# missing pipe when invoked manually.
if [ -t 0 ]; then
    log_error "Bootstrap proxy URL must be piped on stdin. Refusing to read from a terminal."
    echo "$USAGE" >&2
    exit 4
fi

IFS= read -r BOOTSTRAP_PROXY_URL || true
if [ -z "$BOOTSTRAP_PROXY_URL" ]; then
    log_error "Empty bootstrap proxy URL on stdin."
    exit 4
fi

TARGET_HOME=$(eval echo "~$TARGET_USER")
PIP_CONF_DIR="$TARGET_HOME/.config/pip"
PIP_CONF_FILE="$PIP_CONF_DIR/pip.conf"

PROFILE="$TARGET_HOME/.profile"
BASHRC="$TARGET_HOME/.bashrc"
MARKER_BEGIN="# BEGIN wsl-manager proxy"
MARKER_END="# END wsl-manager proxy"

MODE_MARKER_DIR="/etc/wsl-manager"
MODE_MARKER_FILE="$MODE_MARKER_DIR/proxy-mode"

# Always remove the temp pip.conf — it briefly held creds and must not survive
# the script regardless of which step failed.
cleanup_pip_conf() {
    if [ -f "$PIP_CONF_FILE" ]; then
        rm -f "$PIP_CONF_FILE"
    fi
}
trap cleanup_pip_conf EXIT

# Strip any legacy Basic-mode proxy block from the user's shell rc files. A
# distro migrating from SC-007 Basic mode carries
#   # BEGIN wsl-manager proxy
#   export http_proxy="http://user:pass@host:port"
#   ...
#   # END wsl-manager proxy
# in ~/.profile (and possibly ~/.bashrc). Those creds are exported into every
# login shell and are readable by any process via /proc/<pid>/environ — exactly
# the leak Negotiate mode exists to eliminate. Remove the managed block now so
# no Basic-auth creds linger in the environment during Phases 1-3. SC-036d later
# rewrites the same marker block to point at http://localhost:3128 (no creds).
log_info "Removing any legacy Basic-mode proxy block from shell rc files..."
remove_legacy_proxy_env() {
    if grep -q "$MARKER_BEGIN" "$PROFILE" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$PROFILE"
        log_info "Removed legacy proxy block from $PROFILE (Basic-auth creds no longer in env)"
    fi
    if grep -q "$MARKER_BEGIN" "$BASHRC" 2>/dev/null; then
        sed -i "/$MARKER_BEGIN/,/$MARKER_END/d" "$BASHRC"
        log_info "Removed legacy proxy block from $BASHRC"
    fi
}
remove_legacy_proxy_env

# Mark mode early so a partial failure still dispatches to the right teardown
# (SC-036e). negotiate-bootstrap means: krb5/px partially installed, .profile
# and other targets untouched.
log_info "Marking proxy mode as 'negotiate-bootstrap'..."
sudo mkdir -p "$MODE_MARKER_DIR" || { log_error "Failed to create $MODE_MARKER_DIR"; exit 2; }
echo "negotiate-bootstrap" | sudo tee "$MODE_MARKER_FILE" > /dev/null || { log_error "Failed to write mode marker"; exit 2; }

# Write apt proxy config with bootstrap creds. apt reads this file directly;
# no env var required. Root-owned, world-readable like the SC-007 file (creds
# are unavoidable here — apt has no other way to authenticate to a Basic-auth
# upstream proxy during the bootstrap install).
log_info "Writing /etc/apt/apt.conf.d/99proxy with bootstrap credentials..."
configure_apt() {
    sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null <<EOF
Acquire::http::Proxy "$BOOTSTRAP_PROXY_URL";
Acquire::https::Proxy "$BOOTSTRAP_PROXY_URL";
EOF
}
configure_apt || { log_error "Failed to configure apt proxy"; exit 2; }

# Write temp pip.conf (creds in [global] proxy). pipx and pip both read it.
# Deleted by the EXIT trap regardless of outcome.
log_info "Writing temporary $PIP_CONF_FILE for pipx..."
configure_pip() {
    mkdir -p "$PIP_CONF_DIR"
    cat > "$PIP_CONF_FILE" <<EOF
[global]
proxy = $BOOTSTRAP_PROXY_URL
EOF
    chmod 600 "$PIP_CONF_FILE"
}
configure_pip || { log_error "Failed to configure pip proxy"; exit 2; }

# Install Kerberos client + pipx via apt (uses the apt-config-embedded proxy).
log_info "Installing krb5-user and pipx via apt..."
# apt-get update returns 0 even when every source fails behind the proxy — failed
# fetches are only W: warnings ("ignored, or old ones used instead"). A wrong
# bootstrap password therefore yields a 407 that apt swallows, and the install
# below can still succeed offline if the packages are already cached/installed.
# Capture the output and treat a 407 (or any non-zero exit) as a hard failure so
# bad credentials abort here instead of producing a false success.
apt_update_output=$(sudo apt-get update 2>&1)
apt_update_rc=$?
echo "$apt_update_output"
if [ "$apt_update_rc" -ne 0 ] || echo "$apt_update_output" | grep -qi 'Proxy Authentication Required'; then
    log_error "apt-get update failed — proxy rejected the bootstrap credentials (HTTP 407) or the proxy is unreachable. Check the username/password."
    exit 2
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y krb5-user pipx || {
    log_error "Failed to install krb5-user / pipx"
    exit 2
}

# pipx install px-proxy. Idempotent: skip if already installed.
log_info "Installing px-proxy via pipx..."
if pipx list --short 2>/dev/null | awk '{print $1}' | grep -qx 'px-proxy'; then
    log_info "px-proxy already installed (pipx list); skipping pipx install"
else
    pipx install px-proxy || { log_error "pipx install px-proxy failed"; exit 2; }
fi

# Add ~/.local/bin to PATH for future shells. pipx ensurepath edits the user's
# shell rc; harmless if already present.
log_info "Running pipx ensurepath..."
pipx ensurepath || log_info "pipx ensurepath returned non-zero (often benign — PATH already set)"

# Verification
log_info "Verifying bootstrap install..."
verify_ok=true

if [ ! -x "$TARGET_HOME/.local/bin/px" ]; then
    log_error "$TARGET_HOME/.local/bin/px not found or not executable"
    verify_ok=false
fi

if ! command -v kinit > /dev/null 2>&1; then
    log_error "kinit not on PATH after install"
    verify_ok=false
fi

if [ "$verify_ok" = false ]; then
    log_error "Bootstrap verification failed"
    exit 3
fi

log_info "Phase 1 bootstrap complete."
log_info "  Mode marker: $MODE_MARKER_FILE = negotiate-bootstrap"
log_info "  px:    $TARGET_HOME/.local/bin/px"
log_info "  kinit: $(command -v kinit)"
log_info "Next: Phases 2-3 (Kerberos config + px activation) ship in SC-036c."

exit 0
