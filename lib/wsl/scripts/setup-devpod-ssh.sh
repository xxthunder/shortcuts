#!/bin/bash

# setup-devpod-ssh.sh
# Syncs SSH config between Windows host and WSL distribution:
# - Copies SSH keys and known_hosts from Windows into WSL with correct permissions
# - Syncs non-DevPod SSH config from Windows host into WSL
# - Syncs DevPod SSH config from WSL to Windows, adapting ProxyCommand
#   entries for Windows-side access
# - Creates timestamped backups before modifying any config file
# This script is idempotent - safe to run multiple times.
# Exit Codes:
# 0: Success
# 1: No SSH keys found to copy
# 2: Config sync failed
# 4: Argument error

USAGE="Usage: $0 --ssh-target-dir=<path> --distro-name=<name>"

# 1. Argument parsing

SSH_TARGET_DIR=""
DISTRO_NAME=""

for i in "$@"; do
  case $i in
    --ssh-target-dir=*)
      SSH_TARGET_DIR="${i#*=}"
      ;;
    --distro-name=*)
      DISTRO_NAME="${i#*=}"
      ;;
    *)
      ;;
  esac
done

if [ -z "$SSH_TARGET_DIR" ] || [ -z "$DISTRO_NAME" ]; then
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

# 2. Copy SSH keys from Windows .ssh dir into WSL ~/.ssh/

log_info "Syncing SSH config: copying keys from '$SSH_TARGET_DIR' into ~/.ssh/ ..."

mkdir -p ~/.ssh
chmod 700 ~/.ssh

KEY_COUNT=0

# Copy private keys (id_* without .pub extension)
for keyfile in "$SSH_TARGET_DIR"/id_*; do
    [ -f "$keyfile" ] || continue
    filename=$(basename "$keyfile")
    cp "$keyfile" ~/.ssh/"$filename"
    if [[ "$filename" == *.pub ]]; then
        chmod 644 ~/.ssh/"$filename"
    else
        chmod 600 ~/.ssh/"$filename"
    fi
    KEY_COUNT=$((KEY_COUNT + 1))
done

# Copy any .pub files that don't match id_* pattern (standalone public keys)
for pubfile in "$SSH_TARGET_DIR"/*.pub; do
    [ -f "$pubfile" ] || continue
    filename=$(basename "$pubfile")
    # Skip if already copied via id_* glob
    [ -f ~/.ssh/"$filename" ] && continue
    cp "$pubfile" ~/.ssh/"$filename"
    chmod 644 ~/.ssh/"$filename"
    KEY_COUNT=$((KEY_COUNT + 1))
done

if [ "$KEY_COUNT" -eq 0 ]; then
    log_error "No SSH keys found in '$SSH_TARGET_DIR'"
    exit 1
fi

log_info "Copied $KEY_COUNT SSH key file(s) with correct permissions."

# 2b. Copy known_hosts from Windows into WSL

for khfile in "$SSH_TARGET_DIR"/known_hosts*; do
    [ -f "$khfile" ] || continue
    filename=$(basename "$khfile")
    cp "$khfile" ~/.ssh/"$filename"
    chmod 644 ~/.ssh/"$filename"
    log_info "Copied '$filename' into WSL."
done

# Shared helpers

WSL_SSH_CONFIG="$HOME/.ssh/config"
WIN_SSH_CONFIG="$SSH_TARGET_DIR/config"
TIMESTAMP=$(date +%Y-%m-%dT%H%M%S)

backup_config() {
    local file="$1"
    local label="$2"
    if [ -f "$file" ]; then
        local backup="${file}.${TIMESTAMP}.bak"
        cp "$file" "$backup"
        log_info "Backed up $label config to '$(basename "$backup")'"
    fi
}

# Extract non-DevPod entries from a config file
extract_non_devpod_entries() {
    local file="$1"
    local in_block=0
    local content=""

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^#\ DevPod\ Start\ (.+)$ ]]; then
            in_block=1
            continue
        fi
        if [ "$in_block" -eq 1 ]; then
            if [[ "$line" =~ ^#\ DevPod\ End\ (.+)$ ]]; then
                in_block=0
            fi
            continue
        fi
        content+="$line"$'\n'
    done < "$file"

    # Remove trailing blank lines
    printf '%s' "$content" | sed -e :a -e '/^[[:space:]]*$/{ $d; N; ba; }'
}

# Extract DevPod blocks from a config file (verbatim, no adaptation)
extract_devpod_blocks() {
    local file="$1"
    local in_block=0
    local content=""

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^#\ DevPod\ Start\ (.+)$ ]]; then
            in_block=1
            content+="$line"$'\n'
            continue
        fi
        if [ "$in_block" -eq 1 ]; then
            content+="$line"$'\n'
            if [[ "$line" =~ ^#\ DevPod\ End\ (.+)$ ]]; then
                in_block=0
            fi
        fi
    done < "$file"

    printf '%s' "$content"
}

# Adapt DevPod ProxyCommand for Windows host (route through wsl.exe)
adapt_devpod_blocks_for_windows() {
    local blocks="$1"
    [ -z "$blocks" ] && return

    local adapted=""
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^([[:space:]]+)ProxyCommand[[:space:]]+(.+)$ ]]; then
            local indent="${BASH_REMATCH[1]}"
            local original_cmd="${BASH_REMATCH[2]}"
            adapted+="${indent}ProxyCommand wsl.exe -d ${DISTRO_NAME} -- ${original_cmd}"$'\n'
        else
            adapted+="$line"$'\n'
        fi
    done <<< "$blocks"

    printf '%s' "$adapted"
}

# Write config file from parts, joining non-empty sections with blank line
write_config() {
    local target_file="$1"
    shift
    local combined=""

    for part in "$@"; do
        [ -z "$part" ] && continue
        if [ -n "$combined" ]; then
            combined+=$'\n\n'"$part"
        else
            combined="$part"
        fi
    done

    if [ -n "$combined" ]; then
        printf '%s\n' "$combined" > "$target_file"
    else
        > "$target_file"
    fi
}

# 3. Sync non-DevPod SSH config from Windows host into WSL

if [ -f "$WIN_SSH_CONFIG" ]; then
    WIN_NON_DEVPOD=$(extract_non_devpod_entries "$WIN_SSH_CONFIG")

    if [ -n "$WIN_NON_DEVPOD" ]; then
        log_info "Syncing non-DevPod SSH config from Windows host into WSL ..."

        # Preserve existing DevPod blocks in WSL config (if any)
        WSL_DEVPOD_BLOCKS=""
        if [ -f "$WSL_SSH_CONFIG" ]; then
            backup_config "$WSL_SSH_CONFIG" "WSL"
            WSL_DEVPOD_BLOCKS=$(extract_devpod_blocks "$WSL_SSH_CONFIG")
        fi

        write_config "$WSL_SSH_CONFIG" "$WIN_NON_DEVPOD" "$WSL_DEVPOD_BLOCKS" || {
            log_error "Failed to write SSH config to '$WSL_SSH_CONFIG'"
            exit 2
        }
        chmod 600 "$WSL_SSH_CONFIG"

        log_info "Non-DevPod SSH config synced into WSL."
    fi
else
    log_info "No Windows SSH config found at '$WIN_SSH_CONFIG' - skipping host-to-WSL sync."
fi

# 4. Sync DevPod SSH config blocks from WSL to Windows (with adapted ProxyCommand)

if [ ! -f "$WSL_SSH_CONFIG" ]; then
    log_info "No WSL SSH config found - skipping DevPod sync to Windows."
    exit 0
fi

WSL_DEVPOD_BLOCKS=$(extract_devpod_blocks "$WSL_SSH_CONFIG")

if [ -z "$WSL_DEVPOD_BLOCKS" ]; then
    log_info "No DevPod entries found in WSL SSH config - skipping DevPod sync to Windows."
    exit 0
fi

log_info "Adapting DevPod SSH config entries for Windows host ..."

ADAPTED_BLOCKS=$(adapt_devpod_blocks_for_windows "$WSL_DEVPOD_BLOCKS")

# Preserve non-DevPod entries in Windows config
WIN_NON_DEVPOD=""
if [ -f "$WIN_SSH_CONFIG" ]; then
    backup_config "$WIN_SSH_CONFIG" "Windows"
    WIN_NON_DEVPOD=$(extract_non_devpod_entries "$WIN_SSH_CONFIG")
fi

write_config "$WIN_SSH_CONFIG" "$WIN_NON_DEVPOD" "$ADAPTED_BLOCKS" || {
    log_error "Failed to write SSH config to '$WIN_SSH_CONFIG'"
    exit 2
}

log_info "SSH config sync completed successfully."
exit 0
