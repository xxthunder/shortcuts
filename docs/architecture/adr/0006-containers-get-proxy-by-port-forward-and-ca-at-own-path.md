# ADR-0006: Containers get the proxy by a port forward and the CA at a path of their own

**Status**: Accepted
**Date**: 2026-11-04
**Related**: [SC-079](../../backlog/sc-079.md)

## Context

In a distribution with `networkingMode=mirrored`, px listens on the Windows loopback (`127.0.0.1:3128`). The distribution reaches it. A rootless Podman container does not: Podman hands it `http_proxy=http://127.0.0.1:3128`, and inside the container `127.0.0.1` is the container's own loopback. pasta's address for the host does not reach the Windows loopback either.

Behind the TLS-inspecting proxy, a container also needs the proxy's CA. An image trusts its own bundle, not the one `setup-ca` extends in the distribution.

The containers on the author's machine are DevPod workspaces, Molecule tests, throwaway test containers and Structurizr. A devcontainer should not need to know the proxy or the CA: they are a property of the machine, and `setup-proxy` and `setup-ca` already own them in the distribution.

## Decision

- **Network**: containers keep their own network. When the proxy URL's host is a loopback address, `setup-proxy` writes a Podman drop-in that makes pasta forward the container's `127.0.0.1:<port>` to the distribution's loopback. The port comes from the proxy URL. With a proxy elsewhere, the drop-in is deleted. The proxy variables Podman already hands in then work unchanged.
- **CA**: `setup-ca` writes a Podman drop-in that mounts the distribution's bundle read-only into every container at `/etc/wsl-manager/ca-certificates.crt`, a path of its own, and points `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS` and `PIP_CERT` at it.
- Each script owns its own drop-in file and deletes it on `--remove`, as [ADR 0002](0002-wsl-manager-changes-only-what-it-marked.md) asks. Every list in a drop-in adds to the user's own lists in `containers.conf` instead of replacing them. The file names and their exact content are in `lib/wsl/scripts/setup-proxy.sh` and `lib/wsl/scripts/setup-ca.sh`.

## Alternatives considered

- **Host networking for containers** (`netns = "host"`). A container would reach the Windows loopback directly. It was rejected because `-p` mappings stop meaning anything, and Molecule instances that run the same service on the same port collide.
- **Mounting the bundle over the image's own `/etc/ssl/certs/ca-certificates.crt`.** Tools that read only the system bundle, apt included, would have trusted the proxy without a variable; this was the first decision of SC-079. It was dropped because `update-ca-certificates` replaces that file with `mv`, which fails with "Device or resource busy" on a mounted file. Podman applies `[containers] volumes` to `podman build` as well, so it broke both running containers and every image build that installs `ca-certificates`.
- **Changing the image or the project.** It was rejected because proxy and CA belong to the machine, not to a devcontainer (see Context).

## Consequences

- A tool that reads only the system bundle and ignores the variables does not trust the proxy in a container; apt over HTTPS is one. It gets its own item when it is needed.
- `podman build` gets the mount and the proxy forward, but not `[containers] env`. A `RUN` step that needs the CA has to set `SSL_CERT_FILE` itself.
- A proxy on loopback without a port in its URL gets no forward.
- Docker Engine and the JVM's trust store are not covered.

[← Back to Architecture](../README.md)
