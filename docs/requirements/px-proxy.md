# px-proxy requirements

What [px-proxy](../runbooks/px-proxy.md) does now. A requirement changes when the tool's behaviour changes, in the commit that closes the backlog item that changed it; no item links to it.

## Endpoint and files

```{req} px listens on 127.0.0.1:3128 only
:id: REQ_PX_ENDPOINT

The generated `px.ini` always sets `listen = 127.0.0.1` and `port = 3128`; `server`, `pac`, `listen`, `port` and `auth` are dropped from px-user.ini, so nothing there can change them.
```

```{req} px's files live in the user profile
:id: REQ_PX_FILES

px-proxy keeps px's files in `%USERPROFILE%\.config\px`: `px.ini`, which it generates and rewrites on every `start`, and `px-user.ini`, the user's overrides, which it never overwrites.
```

## Commands

```{req} install installs px only when it is missing
:id: REQ_PX_INSTALL

`install` creates the data directory and seeds the px-user.ini template; when no `px` command resolves, it installs px with Scoop and writes a marker that px-proxy installed it. It writes no `px.ini`.
```

```{req} start rewrites the config and runs exactly one px
:id: REQ_PX_START

`start` is the default action. Without a px executable it fails before writing anything; otherwise it rewrites `px.ini`, stops a running px, and starts the windowless `pxw` with that `px.ini`, in the data directory.
```

```{req} stop ends px and its logon start
:id: REQ_PX_STOP

`stop` asks px to quit and force-kills px and pxw that still run after that; with no px running it changes nothing. Either way it deletes the logon start.
```

```{req} remove leaves only the user's overrides
:id: REQ_PX_REMOVE

`remove` stops px, deletes the logon start, uninstalls px only if px-proxy installed it, deletes `px.ini` and the logs, and keeps `px-user.ini`.
```

```{req} test checks the endpoint over HTTPS and names the failure
:id: REQ_PX_TEST

`test` sends an HTTPS request to `https://www.google.com` through the endpoint, with a 20-second timeout. It reports the HTTP status on success, and on failure names the cause: authentication to the upstream (407), the TLS revocation check, a certificate, or another error. A failure ends the run with exit code 1.
```

## Upstream

```{req} px takes the upstream proxy from Windows unless a host is given
:id: REQ_PX_UPSTREAM

Without an explicit host, `start` writes no upstream into `px.ini`, so px asks Windows for the upstream proxy on every request and rereads the Windows proxy settings every `proxyreload` seconds. With an explicit host, `start` writes it as `server`. `start` looks up nothing and never prompts.
```

## Start at logon

```{req} a successful start makes px start at logon
:id: REQ_PX_LOGON

Only after px was launched, `start` registers a logon start that runs `pxw` with the same `px.ini`, without a lookup. A failed `start` leaves an existing entry alone, and the restart inside `start` keeps it.
```

## Settings

```{req} px-user.ini overrides the defaults in its [settings] block
:id: REQ_PX_SETTINGS

The `[settings]` of `px.ini` are the defaults `log = 0`, `workers = 1`, `threads = 32`, `idle = 300`, `socktimeout = 300.0`, `proxyreload = 60` and `foreground = 0`, with px-user.ini's `[settings]` merged on top. Other sections, comments and inline comments in px-user.ini are ignored.
```

```{req} px-user.ini starts as a template that changes nothing
:id: REQ_PX_USER_TEMPLATE

`install` and `start` write px-user.ini only when it is missing: every overridable key, commented out, at its default.
```

## Running the tool

```{req} the exit code says whether the action succeeded
:id: REQ_PX_EXIT

0 on success; on failure an error that names the action, and 1.
```

```{req} the window stays open until a key is pressed
:id: REQ_PX_WAIT_KEY

By default px-proxy waits for a key before it exits, after a failure too, so a window opened from Keypirinha stays readable. `-WaitForKey:$false` turns it off; in CI and tests it never waits, and a host without an interactive console does not fail.
```
