[← Back to README](../../README.md)

# px Proxy Runbook

## Overview

`px-proxy` runs [px](https://github.com/genotrance/px) as a local authenticating proxy on `http://127.0.0.1:3128`. px authenticates to your corporate upstream proxy using your current Windows logon session, then exposes a plain, credential-free local endpoint. Point native Windows CLI tools (git, pip, node, curl, Claude Code) and WSL distros at that endpoint and they reach the internet without storing any password.

Logging in with your existing Windows session is handled by the Security Support Provider Interface (SSPI, the Windows facility that lets a program prove who you are from your sign-in without ever asking for a password). It does this over one of two protocols: Kerberos (the modern, ticket-based one) or NT LAN Manager (NTLM, the older challenge-response one); px picks whichever your proxy accepts. You do not need to know which: the terms only matter when reading logs or troubleshooting below.

**Why this exists:** `setProxy.ps1` wires the corporate proxy into `[System.Net.WebRequest]::DefaultWebProxy`, which only covers .NET. Native CLI tools cannot perform SSPI themselves and get `407 Proxy Authentication Required` when pointed straight at the corporate proxy. px closes that gap.

**When to use it:** you are behind a Kerberos/NTLM corporate proxy and need native tools (and/or WSL) to reach the internet without embedding credentials.

---

## Prerequisites

You probably have everything already:

- Your usual corporate Windows sign-in. px uses it to log in to the proxy for you, so you never type a password.
- [Scoop](https://scoop.sh) installed. `px-proxy install` gets px from it.
- The corporate root certificate trusted in Windows, so HTTPS sites work. px does not touch any certificates itself.

---

## Usage

**From Keypirinha:** search for `px-proxy`. Keypirinha's file catalog only indexes `.url`, `.lnk`, `.cmd`, `.bat`, and `.exe` files (not `.ps1`), so it finds and runs `tools\proxy\px-proxy.bat`, the `.bat` wrapper around the script (see the PowerShell Script Wrapper Convention in `AGENTS.md`) — never the `.ps1` file directly. Press **Tab** to open the argument line and type the action (for example `start`). Without Tab, Keypirinha just launches the wrapper with no action, which runs the default (`start`).

**From a terminal:**

```powershell
.\tools\proxy\px-proxy.ps1 <action>
```

| Action    | What it does |
|-----------|--------------|
| `install` | Installs px via Scoop (only if not already present), creates the px data directory, and seeds a `px-user.ini` settings template. Does **not** resolve the proxy or write config. |
| `start`   | Resolves the upstream proxy fresh, (re)writes the px config (merging your `px-user.ini` overrides), and always (re)starts px. Exactly one `pxw.exe` instance results. |
| `stop`    | Stops any running px cleanly. |
| `test`    | Sends an HTTPS request through `127.0.0.1:3128` and reports a clear diagnostic. |
| `remove`  | Stops px, uninstalls it (only if this tool installed it), and deletes `px.ini` and the log files. Your `px-user.ini` is preserved. |

`start` is the default action when none is given.

> **px does not start itself.** There is currently no persistent installation, scheduled task, or other automation that launches px for you — after every reboot or logon, run `start` yourself (from Keypirinha or a terminal) before you need proxied tools.
>
> **If your network requires a VPN** (for example, working from a home office), connect the VPN **first**, then run `start`. Both proxy discovery (PAC evaluation) and the Kerberos ticket lookup need the corporate network to be reachable; starting px before the VPN is up resolves against the wrong, unreachable path.

### Manual upstream override

If auto-discovery cannot resolve the proxy (the network's Proxy Auto-Config (PAC, the script your company publishes to tell clients which proxy to use) returns `DIRECT`, meaning "go direct, no proxy", and no Kerberos ticket for the proxy is present), pass the host explicitly:

```powershell
.\tools\proxy\px-proxy.ps1 start -ProxyHost "proxy.corp.example:8080"
```

### Pointing tools at px

Once px is running, `setProxy.ps1` **auto-detects** it (a TCP probe on the px endpoint) and targets it automatically, no switch needed:

```powershell
.\tools\proxy\setProxy.ps1
```

Force the behavior either way:

```powershell
.\tools\proxy\setProxy.ps1 -UsePx   # always use px, even if the probe fails
.\tools\proxy\setProxy.ps1 -NoPx    # ignore px, force the corporate-proxy path
```

`setProxy.ps1` sets `HTTP_PROXY`/`HTTPS_PROXY` (and `DefaultWebProxy`) for the current session only; open a new shell and re-run it if needed.

### Using px from WSL

WSL reaches px on `127.0.0.1:3128` because wsl-manager sets `networkingMode=mirrored`. Two one-time setup steps make WSL tools use it automatically:

1. `configure-wsl` (wsl-manager) writes `autoProxy=false` to `.wslconfig`. This matters: Windows' `autoProxy` otherwise injects the **corporate** proxy into every WSL shell, which needs a login WSL can't do (`407`). Turning it off lets WSL use px instead.
2. `setup-proxy` (wsl-manager, choose the local px proxy) writes the px endpoint where both bash and zsh read it on startup (`/etc/profile.d`, plus `/etc/zsh/zshenv` for zsh), so every shell inherits it.

After that, tools just work with no `-x` and no password:

```bash
curl https://www.google.com          # succeeds through px
env | grep -i proxy                  # http_proxy=http://127.0.0.1:3128
```

To check px directly, bypassing the environment, add `-x http://127.0.0.1:3128`.

`setup-proxy` also points tools that ship their own certificate store (uv, Node, pip, Go) at the system trust store, so they accept the corporate Transport Layer Security (TLS, the encryption behind HTTPS) inspection certificate instead of failing with `UnknownIssuer`. This assumes the corporate root certificate authority (CA) is already trusted system-wide (`curl`/`wget` working through px confirms it).

---

## How discovery works

1. **`-ProxyHost` override** (if provided) wins.
2. **PAC evaluation**: reuses `setProxy.ps1`'s `Get-ProxyFromPac`, which runs the PAC's `FindProxyForURL` via `GetSystemWebProxy().GetProxy()` and returns the **real upstream proxy** (the host carrying the Kerberos Service Principal Name (SPN), the identity Kerberos hands out a ticket against), not the PAC-distribution host.
3. **Kerberos SPN fallback**: parses an `HTTP/<host>` service ticket from `klist` and appends the default port `8080`.
4. **Manual prompt**: interactive sessions only.

> **Root-cause note:** px must target the real proxy host (the one carrying the Kerberos SPN). Pointing px at the PAC-distribution / AutoConfigURL host yields no SPN, SSPI falls back to NTLM, and the proxy rejects it.

---

## Files and logs

- **Data directory:** `%USERPROFILE%\.config\px`
- **Generated config:** `%USERPROFILE%\.config\px\px.ini` (regenerated on every `start`; do not hand-edit, your changes are overwritten)
- **User settings:** `%USERPROFILE%\.config\px\px-user.ini` (your overrides; never overwritten by the tool and preserved on `remove`; see [Customizing settings](#customizing-settings))
- **Log:** `%USERPROFILE%\.config\px\debug-*.log` (off by default; set `log = 3` in `px-user.ini` to write a unique log in px's working directory, which `start` sets to the data dir; `remove` deletes these)

---

## Customizing settings

`px.ini` is regenerated on every `start`, so it is not the place for your own changes. Put overrides in `%USERPROFILE%\.config\px\px-user.ini` instead: the tool merges them over its defaults and never overwrites the file. `install` (and the first `start`) seed a commented template listing every key.

Only the `[settings]` block is read; the `[proxy]` block (`server`, `listen`, `port`) stays tool-managed, so nothing here can move the `127.0.0.1:3128` endpoint or the resolved upstream. Overridable keys and their defaults:

| Key | Default | Purpose |
|-----|---------|---------|
| `log` | `0` | Log level. `0` = off; `3` = verbose `debug-*.log` for troubleshooting. |
| `workers` | `1` | Connection worker processes. |
| `threads` | `32` | Threads per worker. |
| `idle` | `300` | Seconds an idle upstream connection is kept. |
| `socktimeout` | `300.0` | Socket timeout (seconds) for long-running requests. |

Example `px-user.ini` that turns logging on and enlarges the pool:

```ini
[settings]
log = 3
workers = 12
```

Run `start` to apply. Delete `px-user.ini` (or a single line) to return to defaults.

---

## Troubleshooting

### `407 Proxy Authentication Required`

px could not authenticate to the upstream proxy. Confirm the resolved proxy host carries a Kerberos SPN:

```powershell
klist
```

Look for a `Server: HTTP/<host>` ticket. A working Kerberos exchange sends a large `Proxy-Authorization: Negotiate` token (thousands of bytes) and gets `200 Connection established`; an NTLM fallback sends a ~40-byte token and keeps getting `407`. If px is pointed at the wrong host, override it with `-ProxyHost`.

### TLS revocation check failed (`curl --ssl-no-revoke` scenario)

Behind TLS inspection, Schannel (Windows' built-in secure-connection layer) runs a hard revocation check that can fail when the inspected certificate's revocation server is unreachable. This is often benign. `px-proxy test` surfaces it as a distinct diagnostic. Ensure the corporate root CA is trusted; for `curl`, `--ssl-no-revoke` bypasses the check.

### TLS / certificate errors

Import the corporate root CA into the Windows trust store (and, for WSL, into the distro's CA bundle).

### Nothing works / connection refused

Confirm px is running and reachable:

```powershell
.\tools\proxy\px-proxy.ps1 test
```

Logging is off by default; set `log = 3` in `px-user.ini` (see [Customizing settings](#customizing-settings)) and re-run `start`, then read the px log at `%USERPROFILE%\.config\px\debug-*.log`. Re-running `start` also regenerates the config and restarts px.

---

[← Back to README](../../README.md)
