[← Back to README](../../README.md)

# Architecture

Architecture documentation for the Shortcuts project.

## Model

The architecture is one [C4 model](https://c4model.com/) written in [Structurizr DSL](https://docs.structurizr.com/dsl): [workspace.dsl](workspace.dsl). Every diagram is a view onto that model, so an element or a relationship is defined once and changed in one place (SC-062).

The model follows two rules:

- **A container is a unit that runs on its own**: the installer, WSL Manager, the Bash scripts that run inside a WSL distribution, the Scoop update helper, the proxy tools, the hotkeys, the tool installers under `tools/`, and the launcher catalog (`links/`) as a data store. Libraries under `lib/` are components of the containers that dot-source them.
- **Components are modelled for WSL Manager**, with one view per user goal rather than a single diagram of everything.

`tools/pslib/wsl` holds obsolete wrappers for an old entry point and is not modelled.

### Views

| View | Shows |
|---|---|
| `SystemContext` | Shortcuts, the developer and the external systems it works with |
| `Containers` | The units of Shortcuts that run on their own and how they are started |
| `WslManager-Overview` | All components of WSL Manager |
| `WslManager-ManageDistributions` | User goal: install, start, stop, clone, update and remove a distribution |
| `WslManager-PrepareDistribution` | User goal: prepare a distribution for dev containers |
| `WslManager-ConfigureWsl` | User goal: configure WSL as a whole |
| `DistributionScripts` | The Bash scripts WSL Manager runs inside a distribution |

### Viewing the model

Start Structurizr local; it shows the views in the browser. Ctrl+C stops it.

- **Windows**: `tools\structurizr\structurizr-local.bat`, or `.\tools\structurizr\structurizr-local.ps1 -Distro <name> -Port <port>`. It runs the viewer in a WSL distribution (the default one unless `-Distro` is given) with docker or podman, set up with WSL Manager (`setup-docker` or `setup-podman`), and opens http://localhost:8080 once it answers.
- **Linux or a WSL shell**: `tools/structurizr/structurizr-local.sh [--port=<port>]`, then open http://localhost:8080.

### Changing the model

- Edit `workspace.dsl` and refresh the browser to see the change.
- The views have no automatic layout: arrange the elements in the viewer and save the view. A new element starts at the top left of every view that includes it and has to be placed there. The views are not arranged yet, so for now every element starts there.
- Structurizr local writes the model and its layout to `workspace.json` when it loads a changed `workspace.dsl` and when a layout is saved in the viewer; commit it together with `workspace.dsl`. Its runtime files in `.structurizr/` are ignored.
- Every start of Structurizr local also rewrites the `lastModifiedDate` in `workspace.json`. When the model and the layouts did not change, discard that change (`git checkout -- docs/architecture/workspace.json`) instead of committing it.
- `tools/structurizr/workspace.Tests.ps1` fails when a module or script in `lib/wsl` is not named in the model, so a new module has to be modelled before the build passes.

## Architecture Decision Records (ADR)

Records of significant architectural decisions, their context, and consequences.

- [ADR 0001: Scoop and utils libraries stay Windows PowerShell 5.1-compatible](adr/0001-lib-powershell-5.1-compatibility.md)
- [ADR 0002: wsl-manager changes only what it has marked as its own in a distribution](adr/0002-wsl-manager-changes-only-what-it-marked.md)
- [ADR 0003: wsl-manager keeps WSL's binfmt_misc protection on and does not rely on systemd-binfmt.service](adr/0003-wsl-manager-keeps-wsl-binfmt-protection.md)
- [ADR 0004: wsl-manager confirmations follow the consequence of the step](adr/0004-wsl-manager-confirmations-follow-the-consequence.md)

[← Back to README](../../README.md)
