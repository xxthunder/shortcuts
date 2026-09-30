[← Back to Architecture](../README.md)

# ADR 0002: wsl-manager changes only what it has marked as its own in a distribution

**Status**: Accepted (2026-09-28)
**Context item**: [SC-060](../../backlog/sc-060.md)

## Context

Several wsl-manager commands write configuration into a WSL distribution: `setup-proxy` (proxy and CA-trust exports, apt, Docker and Podman client settings), `setup-podman` (the environment for rootless Podman) and, with SC-060, `setup-ca` (corporate root certificates). Some of it goes into files wsl-manager creates; some goes into files it shares with the distribution's packages, the corporate IT and the user, such as shell startup files.

The commands also run again and take their configuration out again: `setup-proxy` rewrites its settings and has a Remove mode, `setup-podman` replaces its block on every run, and `setup-ca` replaces certificates that are no longer selected and has `-Remove`. A re-run or a removal that deletes more than wsl-manager wrote destroys configuration that belongs to someone else; one that deletes less leaves stale settings behind. A command therefore has to tell its own content apart from everything else in the distribution.

The commands mostly did this the same way without it being written down. SC-060 is the third to follow it, so the rule is recorded here for the next one.

## Decision

Inside a distribution, wsl-manager changes only what it has marked as its own, and a re-run or a removal touches only that:

- **Files wsl-manager owns** carry the prefix `wsl-manager-` in their name, or live in a `wsl-manager` directory.
- **Lines in a shared file** sit in a block between `# BEGIN wsl-manager <feature>` and `# END wsl-manager <feature>`. A re-run replaces the block, a removal deletes it; the rest of the file stays as it is.
- **Nothing without the mark is touched**, even when it looks like what wsl-manager would have written: it belongs to someone else.

Which files and blocks a command owns is stated in its script under `lib/wsl/scripts/`.

## Alternatives considered

None were weighed. The rule grew out of `setup-proxy` and `setup-podman` and is recorded as it stands, so that a new command follows it on purpose rather than by copying.

## Consequences

- Every new command that writes into a distribution marks its files or blocks and removes only what it marked.
- The prefix `wsl-manager-` and the marker texts are a contract with every distribution already set up. Renaming them orphans the existing files and blocks: re-runs would no longer recognise them and removals would leave them behind.
- Removing a block relies on its END marker. If someone deletes the END line of a block by hand, the removal deletes everything from the BEGIN line to the end of the file.
- `setup-proxy` does not follow the rule for three of its targets: `/etc/apt/apt.conf.d/99proxy`, `~/.docker/config.json` and `~/.config/containers/containers.conf` are written whole and deleted on Remove, so anything else kept there, such as Docker registry credentials, is lost. Bringing them in line is open work; this ADR does not change them.

[← Back to Architecture](../README.md)
