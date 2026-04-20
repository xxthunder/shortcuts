#!/bin/bash

# setup-proxy-negotiate.sh
# Negotiate (Kerberos) proxy mode — STUB (SC-036a).
# Full implementation ships incrementally in SC-036b (bootstrap install),
# SC-036c (Kerberos + px activation), SC-036d (switch to localhost),
# and SC-036e (mode-aware teardown).
#
# Accepts the same base arguments as setup-proxy.sh so the PowerShell
# dispatcher can target either script with the same arg shape.
#
# Exit codes:
#   0  : Success (not reachable yet)
#   4  : Argument error
#   10 : Not yet implemented

USAGE="Usage: $0 --proxy-url=<url> --no-proxy=<hosts> --username=<user>
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

echo "Negotiate (Kerberos) proxy mode is not yet implemented." >&2
echo "Ships incrementally in SC-036b, SC-036c, SC-036d, SC-036e." >&2
exit 10
