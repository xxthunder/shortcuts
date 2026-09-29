#!/bin/bash

# structurizr-local.sh
# Starts Structurizr local (the structurizr/structurizr image) on the architecture model in docs/architecture.
# Runs in the foreground; Ctrl+C stops and removes the container. Uses docker if available, otherwise podman.
# Exit Codes:
# 0: Viewer stopped
# 1: Prereq failure (no container runtime)
# 4: Argument error
# other: exit code of the container runtime

USAGE="Usage: $0 [--port=<port>]"
# Fully qualified: podman resolves a short name only when its registries.conf lists search registries
IMAGE="docker.io/structurizr/structurizr"
PORT=8080

for arg in "$@"; do
  case $arg in
    --port=*)
      PORT="${arg#*=}"
      ;;
    *)
      echo "Error: Unknown argument: $arg" >&2
      echo "$USAGE" >&2
      exit 4
      ;;
  esac
done

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "Error: --port must be a number between 1 and 65535." >&2
    echo "$USAGE" >&2
    exit 4
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/../../docs/architecture" && pwd)"

if command -v docker >/dev/null 2>&1; then
    RUNTIME=docker
    # Run as the calling user, so the files Structurizr writes into the repository stay editable
    RUN_AS=(--user "$(id -u):$(id -g)")
elif command -v podman >/dev/null 2>&1; then
    RUNTIME=podman
    # The image runs as uid 65532, which rootless podman maps to a subordinate uid that cannot
    # write the mounted directory; keep-id maps the calling user into the container unchanged
    RUN_AS=(--userns=keep-id --user "$(id -u):$(id -g)")
else
    echo "Error: neither docker nor podman found. Install one with wsl-manager (setup-docker or setup-podman)." >&2
    exit 1
fi

TTY=()
[ -t 0 ] && TTY=(-it)

echo "Structurizr local on http://localhost:$PORT (Ctrl+C to stop), model: $WORKSPACE_DIR"
exec "$RUNTIME" run "${TTY[@]}" --rm "${RUN_AS[@]}" -p "$PORT:8080" -v "$WORKSPACE_DIR:/usr/local/structurizr" "$IMAGE" local
