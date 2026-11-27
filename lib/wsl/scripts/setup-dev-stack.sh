#!/usr/bin/env bash

# setup-dev-stack.sh
# Applies the dev-stack Ansible role to this WSL distribution
# This script is idempotent - safe to run multiple times
# - Installs ansible-core and git, fetches the pinned role, runs the playbook
# Exit Codes:
# 0: Success
# 1: Prereq failure (run as root instead of a non-root user, or missing argument values)
# 2: apt install of ansible-core/git failed
# 3: ansible-galaxy role install failed
# 4: Argument error
# 5: ansible-playbook failed

# No -e: under errexit, a failing ~/.bash_logout (clear_console without a console) turns every exit code into 1.
set -uo pipefail

USAGE="Usage: $0 --runtime=<podman|docker> --username=<user> --claude-code=<true|false>"

log_info() {
    echo -e "\033[0;32m[INFO] $1\033[0m"
}

log_error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}

RUNTIME=""
TARGET_USER=""
CLAUDE_CODE=""

for i in "$@"; do
    case $i in
        --runtime=*)
            RUNTIME="${i#*=}"
            ;;
        --username=*)
            TARGET_USER="${i#*=}"
            ;;
        --claude-code=*)
            CLAUDE_CODE="${i#*=}"
            ;;
        *)
            echo "Error: Unknown option '$i'." >&2
            echo "$USAGE" >&2
            exit 4
            ;;
    esac
done

# 1. Validation (runs as a normal user; sudo is used for privileged commands)
if [ "$(id -u)" -eq 0 ]; then
    log_error "Run this script as a non-root user"
    exit 1
fi

if [ -z "$RUNTIME" ] || [ -z "$TARGET_USER" ] || [ -z "$CLAUDE_CODE" ]; then
    echo "Error: Missing required arguments." >&2
    echo "$USAGE" >&2
    exit 1
fi

case "$RUNTIME" in
    podman|docker) ;;
    *)
        echo "Error: Invalid runtime '$RUNTIME'." >&2
        echo "$USAGE" >&2
        exit 4
        ;;
esac

case "$CLAUDE_CODE" in
    true|false) ;;
    *)
        echo "Error: Invalid --claude-code value '$CLAUDE_CODE'." >&2
        echo "$USAGE" >&2
        exit 4
        ;;
esac

ANSIBLE_DIR="$(dirname "$(readlink -f "$0")")/../ansible"

# 1b. Migration: the old wsl-manager Docker install wrote docker.list with another Signed-By
# than the role's docker.sources; apt refuses both together. Remove only what wsl-manager wrote.
OLD_DOCKER_LIST="/etc/apt/sources.list.d/docker.list"
OLD_DOCKER_KEY="/etc/apt/keyrings/docker.gpg"
if [ -f "$OLD_DOCKER_LIST" ] && grep -q "signed-by=/etc/apt/keyrings/docker.gpg" "$OLD_DOCKER_LIST"; then
    log_info "Removing the old wsl-manager Docker apt source $OLD_DOCKER_LIST and key $OLD_DOCKER_KEY"
    sudo rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
fi

# 2. Install ansible-core and git
log_info "Installing ansible-core and git..."
if ! { sudo apt-get update && sudo apt-get install -y ansible-core git; }; then
    log_error "Failed to install ansible-core and git"
    exit 2
fi

# 3. Fetch the pinned role (--force replaces an older clone after a version bump)
log_info "Installing the dev_stack role..."
if ! ansible-galaxy role install -r "$ANSIBLE_DIR/requirements.yml" --force; then
    log_error "Failed to install the dev_stack role"
    exit 3
fi

# 4. Run the playbook
log_info "Running the dev-stack playbook..."
# Failed tasks go to stderr, which the caller shows; stdout is discarded by the caller
if ! ANSIBLE_DISPLAY_FAILED_STDERR=true ansible-playbook -i localhost, "$ANSIBLE_DIR/dev-stack.yml" \
    -e "runtime=$RUNTIME" -e "username=$TARGET_USER" -e "claude_code=$CLAUDE_CODE"; then
    log_error "The dev-stack playbook failed"
    exit 5
fi

log_info "Dev stack is set up"
exit 0
