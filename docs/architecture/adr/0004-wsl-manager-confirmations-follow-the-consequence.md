[← Back to Architecture](../README.md)

# ADR 0004: wsl-manager confirmations follow the consequence of the step

**Status**: Accepted (2026-10-01)
**Context item**: [SC-060](../../backlog/sc-060.md)

## Context

wsl-manager asks before several steps, and two helpers produce the prompt:

- `Get-UserConfirmation` in `lib/utils/utils.ps1`: a plain prompt whose Enter default the caller chooses, `[Y/n]` or `[y/N]`.
- `Confirm-DestructiveAction` in `lib/wsl/commands.ps1`: a Spectre prompt that always shows `[y/N]`, so Enter means No.

The choice between them was not written down. SC-060 first used `Confirm-DestructiveAction` for the install confirmation of `setup-ca`, because it already rendered the `[y/N]` prompt the design asked for. The UAT on 2026-10-01 failed on it: installing root certificates only adds files wsl-manager owns and can be repeated, yet Enter cancelled it. The author's question was why that is a destructive action. It is not; the helper had been picked for the shape of its prompt, not for what the step does.

## Decision

A confirmation's Enter default follows the consequence of the step:

- **A step that only adds what wsl-manager owns** ([ADR 0002](0002-wsl-manager-changes-only-what-it-marked.md)) and can be repeated without harm asks `[Y/n]` through `Get-UserConfirmation -defaultValueForUser $true`. Enter means yes.
- **A step that takes something away** asks `[y/N]` through `Confirm-DestructiveAction`. Enter means no. Taking away includes deleting data, stopping running processes, an update that cannot be undone, and removing trust that other work depends on, even when a later run can restore it.

Where a step sits is decided when it is built and stated in its backlog item.

The rule covers only the Enter default of a prompt that is shown. A CLI call with explicit arguments and the CI/test environment do not prompt; that stays as each command defines it.

## Alternatives considered

- **A new neutral helper for the `[Y/n]` case**, next to `Confirm-DestructiveAction`. It was proposed during the SC-060 fix and dropped once the author pointed out that `Get-UserConfirmation` in the library already does this, and `setup-proxy` already uses it.

No other alternative was weighed.

## Consequences

- Every new prompt is classified as adding or taking away. A borderline case is decided and recorded in its item: `setup-ca` Remove deletes only wsl-manager's own certificates and an install restores them, but every HTTPS request through the TLS inspection fails until then, so it asks `[y/N]`.
- The two kinds of prompt look different: `Get-UserConfirmation` uses `Read-Host`, `Confirm-DestructiveAction` uses Spectre. The difference in look is accepted.
- `Get-UserConfirmation` returns `$valueForCi`, by default `$false`, in CI/test. A command that reaches it in CI must either pass the value it needs or not prompt there.
- `setup-proxy` does not follow the rule for one prompt: when the PAC file resolves to DIRECT, "Remove proxy config?" removes the proxy configuration with Enter as yes. Bringing it in line is open work; this ADR does not change it.

[← Back to Architecture](../README.md)
