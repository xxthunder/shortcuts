[← Back to README](../../README.md)

# Architecture

Architecture documentation for the Shortcuts project.

## Diagrams

- [WSL Manager - C4 Architecture](wsl-manager-c4.md): Context, Container, and Component views of the WSL Manager.

## Architecture Decision Records (ADR)

Records of significant architectural decisions, their context, and consequences.

- [ADR 0001: Scoop and utils libraries stay Windows PowerShell 5.1-compatible](adr/0001-lib-powershell-5.1-compatibility.md)
- [ADR 0002: wsl-manager changes only what it has marked as its own in a distribution](adr/0002-wsl-manager-changes-only-what-it-marked.md)
- [ADR 0003: wsl-manager keeps WSL's binfmt_misc protection on and does not rely on systemd-binfmt.service](adr/0003-wsl-manager-keeps-wsl-binfmt-protection.md)
- [ADR 0004: wsl-manager confirmations follow the consequence of the step](adr/0004-wsl-manager-confirmations-follow-the-consequence.md)

[← Back to README](../../README.md)
