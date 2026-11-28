#!/usr/bin/env bash

# setup-binfmt-interop.sh
# Registers the WSLInterop binfmt format so Windows executables run (Docker/VS Code compatibility)
# This script is idempotent - safe to run multiple times
# Exit Codes:
# 0: Success
# 3: Configuration failure

log_info() {
    echo -e "\033[0;32m[INFO] $1\033[0m"
}

log_error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}

# Configure WSL interop via binfmt.d (Docker/VS Code compatibility)
log_info "Configuring WSL interop via binfmt.d..."
setup_binfmt_interop() {
    # Create binfmt.d directory if it doesn't exist
    sudo mkdir -p /etc/binfmt.d

    # Check if WSLInterop.conf already exists
    if [ -f /etc/binfmt.d/WSLInterop.conf ]; then
        log_info "WSLInterop.conf already exists, verifying content..."

        # Verify it has the correct content
        if grep -q ":WSLInterop:M::MZ::/init:PF" /etc/binfmt.d/WSLInterop.conf; then
            log_info "WSLInterop.conf is already correctly configured"
        else
            log_info "WSLInterop.conf exists but has different content, updating..."
            echo ":WSLInterop:M::MZ::/init:PF" | sudo tee /etc/binfmt.d/WSLInterop.conf > /dev/null
        fi
    else
        log_info "Creating WSLInterop.conf..."
        echo ":WSLInterop:M::MZ::/init:PF" | sudo tee /etc/binfmt.d/WSLInterop.conf > /dev/null
    fi

    # Apply the rule. Given a file, systemd-binfmt registers just that rule. Restarting
    # systemd-binfmt.service would first flush all rules through
    # /proc/sys/fs/binfmt_misc/status, which WSL 3.0 mounts read-only, and fail.
    if pidof systemd > /dev/null; then
        sudo /usr/lib/systemd/systemd-binfmt /etc/binfmt.d/WSLInterop.conf
    fi
}
setup_binfmt_interop || { log_error "Failed to configure WSL interop via binfmt.d"; exit 3; }
