# ADR-0008: px takes the upstream proxy from Windows on every request

**Status**: Accepted
**Date**: 2026-11-10
**Related**: [SC-087](../../backlog/sc-087.md)
**Supersedes**: [ADR-0005](0005-px-starts-at-logon-from-the-last-config.md)

## Context

[ADR 0005](0005-px-starts-at-logon-from-the-last-config.md) lets px start at logon with the `px.ini` of the last `start`. That `px.ini` pinned the upstream proxy that `start` had looked up once. ADR 0005 accepted the cost: when the upstream changes (another site, abroad, VPN on or off), px runs with a stale `px.ini` until the user runs `start` again on the company network.

A second, separate problem gives another reason. On a machine with home Wi-Fi plus VPN, px's own PAC engine takes the first IP of the host name, which can be the home address, and the PAC answers that with `DIRECT`. This has nothing to do with a stale `px.ini`. The item SC-087 reports it from the comments of the sister setup claude-setup; this repository has not verified it.

According to the same comments, px without `server` and `pac` reads the Windows proxy settings and asks Windows (`WinHttpGetProxyForUrl`) for the proxy on every request, like the browser. Windows evaluates the PAC with the machine's real addresses and returns the real proxy, which carries the Kerberos SPN.

## Decision

- `start` writes no upstream into `px.ini` and no `pac`. px asks Windows on every request.
- `-ProxyHost` is the only way to pin an upstream; `start` then writes it as `server`.
- `start` looks up nothing: no PAC evaluation, no Kerberos-ticket guess, no prompt. It needs neither the company network nor the VPN.
- `proxyreload = 60` and `foreground = 0` are built-in `[settings]` defaults, so px rereads the Windows proxy settings every 60 seconds and `px-user.ini` may override both.
- `pac` is a tool-managed key: `px-user.ini` cannot pin a PAC, because the upstream choice stays with the tool (`pac` is in `PxManagedSettingKeys` in `px-proxy.ps1`).
- The logon start from the last `px.ini` stays as [ADR 0005](0005-px-starts-at-logon-from-the-last-config.md) decided it. Only what `px.ini` holds changes.

## Alternatives considered

- **Pin the upstream at `start`** (the behaviour of ADR 0005). It was rejected because the pinned upstream goes stale when the network changes, and the user must run `start` again.
- **px's own PAC engine (`pac =`).** It was rejected because it takes the first IP of the host name, which can be the home address on a machine with home Wi-Fi plus VPN (see Context).
- **A scheduled task that runs `start` when the VPN connects.** ADR 0005 already rejected it for its build and test cost. Asking Windows per request follows the network without it.

## Consequences

- px depends on the Windows proxy settings being right. When they are missing or wrong, or the PAC answers `DIRECT` for a host that needs the proxy, the user pins the upstream with `-ProxyHost`.
- Which upstream px used for a request is visible only in its log (`log = 3`).
- `-ProxyHost` brings back the trade-off of ADR 0005: a pinned upstream goes stale when the network changes.
- The unverified expectations of ADR 0005 about authenticating after the VPN comes up stay open; the real-machine check of SC-087 covers on site and home Wi-Fi plus VPN.

[← Back to Architecture](../README.md)
