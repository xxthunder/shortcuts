#!/bin/bash

# setup-ca.sh
# Installs or removes the corporate root CA certificates that wsl-manager manages
# Target: /usr/local/share/ca-certificates/wsl-manager-<thumbprint>.crt, then update-ca-certificates
# Install adds the given certificates and keeps the other managed ones. Every run deletes managed
# certificates that have expired. --remove deletes all managed ones.
# Files not named wsl-manager-*.crt are never touched.
# This script is idempotent - safe to run multiple times.
# Exit Codes:
# 0: Success
# 1: Prereq failure
# 2: Configuration failure
# 3: Verification failure
# 4: Argument error

USAGE="Usage: $0 --cert=<thumbprint>:<base64-der> [--cert=<thumbprint>:<base64-der> ...]
       $0 --remove"

CA_DIR="/usr/local/share/ca-certificates"
BUNDLE="/etc/ssl/certs/ca-certificates.crt"
# Full path: /usr/sbin is not on a non-root user's PATH on Debian
UPDATE_CA="/usr/sbin/update-ca-certificates"
PREFIX="wsl-manager-"

# 1. Argument parsing

REMOVE_MODE=false
CERTS=()

for i in "$@"; do
  case $i in
    --cert=*)
      CERTS+=("${i#*=}")
      ;;
    --remove)
      REMOVE_MODE=true
      ;;
    *)
      echo "Error: Unknown argument: $i" >&2
      echo "$USAGE" >&2
      exit 4
      ;;
  esac
done

if [ "$REMOVE_MODE" = true ] && [ ${#CERTS[@]} -gt 0 ]; then
    echo "Error: --remove takes no --cert arguments." >&2
    echo "$USAGE" >&2
    exit 4
fi
if [ "$REMOVE_MODE" = false ] && [ ${#CERTS[@]} -eq 0 ]; then
    echo "Error: At least one --cert argument is required." >&2
    echo "$USAGE" >&2
    exit 4
fi

for entry in "${CERTS[@]}"; do
    thumbprint="${entry%%:*}"
    der_base64="${entry#*:}"
    if [[ "$entry" != *:* ]] || ! [[ "$thumbprint" =~ ^[0-9A-F]{40}$ ]] || ! [[ "$der_base64" =~ ^[A-Za-z0-9+/]+=*$ ]]; then
        echo "Error: Malformed --cert argument (expected <40 hex digits>:<base64>)." >&2
        echo "$USAGE" >&2
        exit 4
    fi
done

log_info() {
    echo -e "\033[0;32m[INFO] $1\033[0m"
}

log_error() {
    echo -e "\033[0;31m[ERROR] $1\033[0m" >&2
}

# 2. Prerequisites

if [ ! -x "$UPDATE_CA" ]; then
    log_error "$UPDATE_CA not found. Install the ca-certificates package first."
    exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
    log_error "openssl not found. It comes with the ca-certificates package."
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    log_error "sudo is required when not running as root."
    exit 1
fi

pem_from_base64() {
    echo "-----BEGIN CERTIFICATE-----"
    echo "$1" | fold -w 64
    echo "-----END CERTIFICATE-----"
}

# The bundle concatenates PEM files; with line breaks removed, a certificate's
# base64 body appears as one contiguous string.
bundle_contains() {
    tr -d '\n' < "$BUNDLE" | grep -qF "$1"
}

# update-ca-certificates warns on every run (a bundle that holds more than one certificate,
# duplicates of a CA installed another way); the warnings mean nothing to a user, so its output
# is shown only when it fails.
run_update_ca() {
    local output
    if ! output=$($SUDO "$UPDATE_CA" 2>&1); then
        log_error "update-ca-certificates failed:"
        echo "$output" >&2
        return 1
    fi
}

# A managed certificate that fails -checkend 0 has expired (or is unreadable); either way it is ours
prune_expired() {
    local existing
    for existing in "$CA_DIR/${PREFIX}"*.crt; do
        [ -e "$existing" ] || continue
        if ! openssl x509 -checkend 0 -noout -in "$existing" >/dev/null 2>&1; then
            $SUDO rm -f "$existing" || return 1
            log_info "Removed expired: $existing"
        fi
    done
}

install_certs() {
    local entry thumbprint file pem
    $SUDO mkdir -p "$CA_DIR" || return 1
    prune_expired || return 1
    for entry in "${CERTS[@]}"; do
        thumbprint="${entry%%:*}"
        file="$CA_DIR/${PREFIX}${thumbprint}.crt"
        pem="$(pem_from_base64 "${entry#*:}")"
        if [ -f "$file" ] && [ "$(cat "$file")" = "$pem" ]; then
            log_info "Unchanged: $file"
        else
            printf '%s\n' "$pem" | $SUDO tee "$file" >/dev/null || return 1
            $SUDO chmod 644 "$file" || return 1
            log_info "Installed: $file"
        fi
    done
    run_update_ca || return 1
}

remove_certs() {
    local existing
    for existing in "$CA_DIR/${PREFIX}"*.crt; do
        [ -e "$existing" ] || continue
        $SUDO rm -f "$existing" || return 1
        log_info "Removed: $existing"
    done
    run_update_ca || return 1
}

# 3. Apply and verify

if [ "$REMOVE_MODE" = true ]; then
    remove_certs || { log_error "Failed to remove the managed CA certificates"; exit 2; }
    if compgen -G "$CA_DIR/${PREFIX}*.crt" >/dev/null; then
        log_error "Managed CA certificates are still present in $CA_DIR"
        exit 3
    fi
    log_info "Managed CA certificates removed."
    exit 0
fi

install_certs || { log_error "Failed to install the CA certificates"; exit 2; }
for entry in "${CERTS[@]}"; do
    bundle_contains "${entry#*:}" || { log_error "Certificate ${entry%%:*} is missing from $BUNDLE"; exit 3; }
done
log_info "CA certificates installed: ${#CERTS[@]}"
exit 0
