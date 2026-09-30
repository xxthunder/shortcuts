[← Back to Architecture](../README.md)

# ADR 0003: wsl-manager keeps WSL's binfmt_misc protection on and does not rely on systemd-binfmt.service

**Status**: Accepted (2026-09-30)
**Context item**: [SC-063](../../backlog/sc-063.md)

## Context

`binfmt_misc`, where the WSLInterop entry for running Windows executables lives, is one kernel-global registry shared by all distributions in the WSL VM. When a systemd distribution shuts down, systemd writes `-1` to `/proc/sys/fs/binfmt_misc/status` and so clears WSLInterop for every other running distribution ([WSL issue #13885](https://github.com/microsoft/WSL/issues/13885)).

WSL 3.0 protects against this with a read-only bind mount over `status` in each distribution ([WSL PR #40621](https://github.com/microsoft/WSL/pull/40621)); the `[boot] protectBinfmt` key in `/etc/wsl.conf` switches it and defaults to `true`. The side effect: `systemd-binfmt` flushes all rules through `status` before it applies `binfmt.d`, the flush fails with `EROFS`, and systemd reports the failure as its exit status. On WSL 3.0 `systemd-binfmt.service` is therefore `failed` after every boot and on every restart, although it registers the `binfmt.d` rules. The WSL team calls the failure benign ([WSL issue #41226](https://github.com/microsoft/WSL/issues/41226)).

`setup-docker` restarted the unit and checked that it was `active`, so it failed on every distribution on WSL 3.0 until SC-063.

## Decision

wsl-manager leaves WSL's `binfmt_misc` protection on: it never writes `protectBinfmt` into a distribution.

Nothing in wsl-manager depends on `systemd-binfmt.service` being `active`, neither in the scripts it runs in a distribution nor in its tests. It applies its own `binfmt.d` rule without the flush of all rules (see step 8.6 of `lib/wsl/scripts/install-docker.sh`), and it treats the kernel entry `/proc/sys/fs/binfmt_misc/WSLInterop` as the state to check.

## Alternatives considered

- **Set `protectBinfmt=false`**: the unit would be `active` again, but one distribution's shutdown would once more wipe WSLInterop in every other running distribution.
- **Keep the CI runner on WSL 2.x**: CI would be green, but the failure that users on WSL 3.0 hit would stay hidden.

## Consequences

- On WSL 3.0 `systemctl is-active systemd-binfmt` shows `failed` in every systemd distribution, including those wsl-manager has set up. `docs/wsl-manager.md` explains this in its troubleshooting steps, so users do not read it as a broken setup.
- A new check of Windows interop must look at the kernel entry, not at the unit.
- If WSL drops the protection, or systemd stops treating the failed flush as an error (systemd `main` still does as of 2026-09-30), the unit state becomes meaningful again. Revisit this ADR then; the kernel check stays correct either way.

[← Back to Architecture](../README.md)
