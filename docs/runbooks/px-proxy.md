[← Back to README](../../README.md)

# px Proxy Runbook

## Overview

`px-proxy` runs [px](https://github.com/genotrance/px) as a local authenticating proxy on `http://127.0.0.1:3128`. px authenticates to your corporate upstream proxy using your current Windows logon session (SSPI: NTLM or Negotiate/Kerberos) and exposes a plain, credential-free local endpoint. Point native Windows CLI tools (git, pip, node, curl, Claude Code) and WSL distros at that endpoint and they reach the internet without storing any password.

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

Run from Keypirinha (type `px-proxy`) or from a terminal:

```powershell
.\tools\proxy\px-proxy.ps1 <action>
```

| Action    | What it does |
|-----------|--------------|
| `install` | Installs px via Scoop (only if not already present) and creates the px data directory. Does **not** resolve the proxy or write config. |
| `start`   | Resolves the upstream proxy fresh, (re)writes the px config, and always (re)starts px. Exactly one `pxw.exe` instance results. |
| `stop`    | Stops any running px cleanly. |
| `test`    | Sends an HTTPS request through `127.0.0.1:3128` and reports a clear diagnostic. |
| `remove`  | Stops px, uninstalls it (only if this tool installed it), and deletes the config and log files. |

`start` is the default action when none is given.

### Manual upstream override

If auto-discovery cannot resolve the proxy (PAC returns DIRECT and no Kerberos SPN is present), pass the host explicitly:

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

`setup-proxy` also points tools that ship their own certificate store (uv, Node, pip, Go) at the system trust store, so they accept the corporate TLS-inspection certificate instead of failing with `UnknownIssuer`. This assumes the corporate root CA is already trusted system-wide (`curl`/`wget` working through px confirms it).

---

## How discovery works

1. **`-ProxyHost` override** (if provided) wins.
2. **PAC evaluation**: reuses `setProxy.ps1`'s `Get-ProxyFromPac`, which runs the PAC's `FindProxyForURL` via `GetSystemWebProxy().GetProxy()` and returns the **real upstream proxy** (the host carrying the Kerberos SPN), not the PAC-distribution host.
3. **Kerberos SPN fallback**: parses an `HTTP/<host>` service ticket from `klist` and appends the default port `8080`.
4. **Manual prompt**: interactive sessions only.

> **Root-cause note:** px must target the real proxy host (the one carrying the Kerberos SPN). Pointing px at the PAC-distribution / AutoConfigURL host yields no SPN, SSPI falls back to NTLM, and the proxy rejects it.

---

## Files and logs

- **Data directory:** `%USERPROFILE%\.config\px`
- **Config:** `%USERPROFILE%\.config\px\px.ini` (regenerated on every `start`)
- **Log:** `%USERPROFILE%\.config\px\debug-*.log` (`[settings] log = 3` writes a unique log in px's working directory, which `start` sets to the data dir; `remove` deletes these)

---

## Troubleshooting

### `407 Proxy Authentication Required`

px could not authenticate to the upstream proxy. Confirm the resolved proxy host carries a Kerberos SPN:

```powershell
klist
```

Look for a `Server: HTTP/<host>` ticket. A working Kerberos exchange sends a large `Proxy-Authorization: Negotiate` token (thousands of bytes) and gets `200 Connection established`; an NTLM fallback sends a ~40-byte token and keeps getting `407`. If px is pointed at the wrong host, override it with `-ProxyHost`.

### TLS revocation check failed (`curl --ssl-no-revoke` scenario)

Behind TLS inspection, Schannel's hard revocation check can fail when the revocation endpoint of the inspected certificate is unreachable. This is often benign. `px-proxy test` surfaces it as a distinct diagnostic. Ensure the corporate root CA is trusted; for `curl`, `--ssl-no-revoke` bypasses the check.

### TLS / certificate errors

Import the corporate root CA into the Windows trust store (and, for WSL, into the distro's CA bundle).

### Nothing works / connection refused

Confirm px is running and reachable:

```powershell
.\tools\proxy\px-proxy.ps1 test
```

Then read the px log at `%USERPROFILE%\.config\px\debug-*.log`. Re-run `start` to regenerate the config and restart px.

---

[← Back to README](../../README.md)
