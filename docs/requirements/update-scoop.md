# update-scoop requirements

What [update-scoop](../runbooks/scoop-update.md) does now. A requirement changes when the tool's behaviour changes, in the commit that closes the backlog item that changed it; no item links to it.

## Start

```{req} update-scoop needs Scoop
:id: REQ_SCOOP_PRESENT

Without a `scoop` command it says "Scoop is not installed" and ends without touching anything.
```

```{req} Scoop is refreshed once at startup
:id: REQ_SCOOP_REFRESH_START

`scoop update` runs once before the first list; a failure is shown and the helper goes on.
```

## Menu

```{req} the menu lists the apps that have updates
:id: REQ_SCOOP_LIST

Numbered, each with its installed and latest version, read from `scoop status` in both its object and its text output. With none, it says "All apps are up to date!".
```

```{req} the user picks apps by number, all, refresh or quit
:id: REQ_SCOOP_SELECT

Numbers separated by commas update those apps; `A` updates all, `R` refreshes, `Q` quits; letters in either case. With no updatable apps, only `R` and `Q` are offered. An invalid number or text is warned about and skipped, and the valid numbers of the same input still count. Nothing valid gives "No apps selected for update." and the menu again.
```

```{req} selected apps are updated one by one, each with its own result
:id: REQ_SCOOP_UPDATE

`scoop update <app>` per app, success or failure per app. Then it waits for a key, so the output can be read before the list is redrawn. A host without an interactive console does not fail.
```

~~~{req} `R` refreshes Scoop and checks again
:id: REQ_SCOOP_REFRESH
~~~

## Resilience

~~~{req} only `Q` ends the session
:id: REQ_SCOOP_LOOP

A failing Scoop command or an error in one round is shown, and the menu comes back.
~~~

## Console

```{req} update-scoop runs under Windows PowerShell 5.1 in a classic console
:id: REQ_SCOOP_CONSOLE
:implemented_in: tools/scoop/update-scoop.bat

`update-scoop.bat` opens it detached, in `conhost.exe` under `powershell.exe`, with the user profile loaded for the proxy. This is what lets it update `pwsh` and Windows Terminal. ADR-0001 constrains it.
```

## In CI and tests

```{req} without a console user it updates everything once
:id: REQ_SCOOP_CI

In CI and tests it makes one update-all pass, with no prompt and no pause, and returns.
```
