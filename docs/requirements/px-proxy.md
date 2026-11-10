# px-proxy requirements

What [px-proxy](../runbooks/px-proxy.md) does now. A requirement changes when the tool's behaviour changes, in the commit that closes the backlog item that changed it; no item links to it.

```{req} px's files live in the user profile
:id: REQ_PX_FILES

px-proxy keeps px's files in `%USERPROFILE%\.config\px`: `px.ini`, which it generates and rewrites on every `start`, and `px-user.ini`, the user's overrides, which it never overwrites.
```

```{req} px takes the upstream proxy from Windows unless a host is given
:id: REQ_PX_UPSTREAM

Without an explicit host, `start` writes no upstream into `px.ini`, so px asks Windows for the upstream proxy on every request and rereads the Windows proxy settings every `proxyreload` seconds. With an explicit host, `start` writes it as `server`. `start` looks up nothing and never prompts.
```

```{req} remove leaves only the user's overrides
:id: REQ_PX_REMOVE

`remove` stops px, deletes the logon start, uninstalls px only if px-proxy installed it, deletes `px.ini` and the logs, and keeps `px-user.ini`.
```
