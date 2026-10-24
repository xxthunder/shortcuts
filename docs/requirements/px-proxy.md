# px-proxy requirements

What [px-proxy](../runbooks/px-proxy.md) does now. A requirement changes when the tool's behaviour changes; the backlog items that changed it link to it.

```{req} px's files live in the user profile
:id: REQ_PX_FILES

px-proxy keeps px's files in `%USERPROFILE%\.config\px`: `px.ini`, which it generates and rewrites on every `start`, and `px-user.ini`, the user's overrides, which it never overwrites.
```

```{req} The upstream proxy is resolved in a fixed order
:id: REQ_PX_UPSTREAM

`start` resolves the upstream proxy in this order: an explicit host; the PAC's proxy unless it reports `DIRECT`; the host of an `HTTP/<host>` Kerberos service ticket with port 8080. When none resolves, it asks for the host in an interactive session and fails otherwise.
```

```{req} remove leaves only the user's overrides
:id: REQ_PX_REMOVE

`remove` stops px, deletes the logon start, uninstalls px only if px-proxy installed it, deletes `px.ini` and the logs, and keeps `px-user.ini`.
```
