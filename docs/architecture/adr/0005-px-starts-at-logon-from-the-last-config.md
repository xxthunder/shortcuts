[← Back to Architecture](../README.md)

# ADR 0005: px starts at logon from the last config and never looks up the proxy then

**Status**: Accepted (2026-10-19)
**Context item**: [SC-067](../../backlog/sc-067.md)

## Context

px runs only after `px-proxy start`. That command looks up the upstream proxy (PAC evaluation, then a klist fallback, then a prompt), rewrites `px.ini` and restarts px. SC-040 chose to have no autostart. After a reboot the author often forgot `start`, and the first session that needed the proxy failed.

Running `start` itself at logon does not work. The author's laptop usually starts outside the company network, and the VPN is connected after logon. At that moment neither the PAC nor the klist lookup can reach the company network, so a lookup at logon fails, prompts, or writes a wrong `px.ini`.

The lookup is also not needed at every logon. For the author, the PAC has handed out the same upstream proxy for years, as long as they work in Germany. The `px.ini` that the last `start` wrote therefore stays valid across reboots.

## Decision

- `start` registers px to start at logon, after it has launched px. The entry is a shortcut in the user's Startup folder. The generic `Register-Autostart` and `Unregister-Autostart` in `lib/utils/utils.ps1` own the entry; px-proxy passes only its name, executable, config and data folder.
- The logon entry starts pxw directly with the `px.ini` from the last `start`. Do not add a proxy lookup, a rewrite of `px.ini` or a pwsh step to the logon start.
- The `stop` command and `remove` delete the entry. The restart inside `start` keeps it.
- When the upstream proxy changes, the user runs `start` by hand. This refreshes `px.ini` and the entry.

## Alternatives considered

- **Run the full `start` at logon.** It was rejected because the lookup needs the company network, which is not there at logon (see Context).
- **A value under the `Run` registry key.** A Run value is a command line with no working directory. px writes its log (`log = 3`) into its working directory, which `start` sets to the px data folder; a shortcut can set that folder, a Run value cannot. The repository also already uses the Startup folder, in `bin/install.ps1` for AutoHotkey.
- **A scheduled task that runs a full `start` when the VPN connects.** It would also follow a changing proxy. It was not chosen because it costs more to build and test, and the proxy host has been stable for the author. It is the option to revisit if the host starts to change.

## Consequences

- When the upstream proxy changes, for example outside Germany, px starts at logon with an outdated `px.ini`, and requests fail until the user runs `start`. This cost is accepted.
- The decision depends on px, started before the VPN, authenticating once the VPN is up. The expectation is that px connects upstream per request and that Windows obtains the Kerberos ticket on first use. This was not verified when the decision was made; the UAT of SC-067 checks it. If it fails, this ADR is revisited.
- `start` launches pxw with a hidden window, and a shortcut cannot hide its window. If the resolved pxw is a console program, a window shows at logon.
- `stop` now affects the next logon as well as the current session. After a `stop`, px stays off across reboots until the next `start`.
- Unit tests must never reach the real Startup folder. The px-proxy tests redirect `Get-AutostartPath`, which every logon start path goes through, once for the whole file; the utils tests redirect it per block; and the script entry-point test skips when the real entry exists.
- This reverses the "No autostart" scope decision of SC-040.

[← Back to Architecture](../README.md)
