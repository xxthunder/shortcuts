# ADR-0007: release is an orphan branch that CI builds from an allow-list

**Status**: Accepted
**Date**: 2026-11-05
**Related**: [SC-084](../../backlog/sc-084.md)

## Context

A downstream fork vendors this repository with `git subtree` (squashed) and starts px-proxy, WSL Manager and the Scoop update helper from it. When the subtree takes `develop` as a whole, tests, CI, agent configuration, docs and tools that the fork never starts all land in its tree, and its users and reviewers have to tell them apart. A reviewer of the fork asked for a branch that holds only what users need.

The fork runs no unit tests of the vendored code, only a UAT. Testing stays here.

## Decision

- **An orphan branch `release`**, which shares no history with `develop`. Each update is one commit that names the `develop` commit it was built from.
- **CI builds it on every push to `develop`, after the tests of the same push passed.** It is never edited by hand.
- **An allow-list decides what goes in.** The list is `bin/release/paths.txt`, and the build copies exactly those paths, leaving out test files. The paths stay as on `develop`.
- **The release job checks the built tree before it commits.** It loads the libraries from the tree and checks every path a script builds from its own location, and an integration test runs the same check on every pull request.
- **The fork tracks the tip of `release`** with `git subtree pull --squash`, not tags.

## Alternatives considered

- **A subtree of `develop` as a whole.** This is how the fork worked before. It was rejected because everything the fork does not use lands in its tree (see Context).
- **A branch whose history follows `develop`**, built for example with `git subtree split` or a history filter. It was rejected because the fork pulls with `--squash`, so the history of `develop` would never reach it anyway. An orphan branch is the simplest thing that works.
- **A deny-list** of what to leave out. It was rejected because a new test, CI or docs file would reach `release` unless someone remembered to exclude it. With an allow-list, a file reaches `release` only when someone lists it.
- **Moving files into a layout of their own on `release`.** It was rejected because the fork's launchers and scripts call files by path, so `release` keeps the layout of `develop` and only leaves files out.
- **Tags or versioned releases.** They were rejected because `git subtree pull` is already an explicit step in the fork, so the fork chooses when it takes an update. Tags would add a manual step here for nothing.
- **Starting the tools in the release job** to prove the tree works. It was rejected because none of the three tools can be started harmlessly in CI: the Scoop update helper is interactive, and px-proxy needs a running px. The job loads the libraries instead.

## Consequences

- A new file that users need reaches `release` only after someone adds it to `bin/release/paths.txt`. The check in the release job and the integration test catch a missing file that a script loads by path, but not one that only a user would miss.
- `release` takes every green push to `develop`. Any vetting of an update happens in the fork's UAT when the fork pulls, not here.
- The history of `release` says nothing on its own. What changed between two release commits is read on `develop`, from the source commits they name.
- The release job needs write access to the repository for its push, and `release` must stay free of rules that would block it.

[← Back to Architecture](../README.md)
