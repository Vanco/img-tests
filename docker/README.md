# AerynOS Docker Base Image

Build [AerynOS](https://aerynos.com) base Docker images from scratch using `moss`, the native package manager, in a fully containerized workflow. The project produces a minimal, versioned, and ready-to-use `aeryn-base` image that can be run on any x86_64 container runtime.

## Overview

This repository provides an automated, multi-stage build process that generates a pristine AerynOS root filesystem and imports it directly as a Docker image (`FROM scratch`). The process is orchestrated by `build.sh` and uses two Dockerfiles to handle both native compilation on `x86_64` hosts and cross-compilation from `arm64` (Apple Silicon) machines.

**Key features**
- **Fully containerized** – `moss` and `boulder` are compiled inside containers; no host tools required (except Docker/Podman).
- **Version tagging** – image tags are automatically derived from the AerynOS `VERSION_ID` (e.g., `aeryn-base:2026.05`).
- **Multi-architecture build** – `Dockerfile.amd64` for native builds, `Dockerfile.arm64` for cross-compilation on Apple Silicon.
- **Privileged installation** – `moss install` runs in a temporary privileged container, bypassing limitations of `docker build`.
- **Clean final image** – the final image is a `scratch` layer containing only the AerynOS root filesystem.

## Repository structure

```
├── build.sh                # Build orchestrator (detects platform, runs build & import)
├── install-rootfs.sh       # Moss installation script (executed inside privileged container)
├── Dockerfile.amd64        # Single-stage native build (x86_64 host)
├── Dockerfile.arm64        # Two-stage cross-compilation (arm64 host)
└── README.md
```

## Prerequisites

- **Docker** (or **Podman**) installed on a Linux x86_64 host (native) or Windows WSL2.
- For Apple Silicon (M1/M2/M3) the build process can _compile_ the tools, but `moss install` currently fails due to QEMU limitations (see [Known issues](#known-issues)).
- Sufficient disk space (the builder image may require several gigabytes).

## Quick start

1. Clone this repository and enter the directory:
   ```bash
   git clone https://github.com/AerynOS/img-tests.git
   cd img-tests/docker
   ```

2. Make the scripts executable:
   ```bash
   chmod +x build.sh install-rootfs.sh
   ```

3. Run the build:
   ```bash
   ./build.sh
   ```

4. After successful completion, run the image:
   ```bash
   docker run --platform linux/amd64 -it aeryn-base:latest /usr/bin/bash
   ```

The build script automatically selects the correct Dockerfile based on the host architecture and passes the necessary build arguments.

## How it works

1. **Build stage** (`Dockerfile.amd64` or `Dockerfile.arm64`):
   - On x86_64 hosts: single stage using `just get-started` to compile and install `moss`/`boulder` along with required data files.
   - On arm64 hosts: two-stage build – first cross‑compiles x86_64 binaries, then copies them into a clean x86_64 runtime environment.
   - Both variants set up user namespace mappings (`/etc/subuid`, `/etc/subgid`) required by `bubblewrap`.

2. **Installation stage** (`install-rootfs.sh`):
   - Runs inside a **privileged** container to allow `bubblewrap` (used by `moss` post‑install scripts).
   - Adds the `volatile` repository and installs the base package sets (`pkgset-aeryn-base`, `pkgset-aeryn-utilities`).
   - Applies basic system configuration (locale, timezone, passwordless root).
   - Outputs the detected AerynOS version to stderr for version tagging.

3. **Image creation** (`build.sh`):
   - The root filesystem is streamed as a tar archive from the privileged container and imported directly into Docker (`docker import`).
   - The image is tagged with the extracted version (`aeryn-base:<VERSION_ID>`) and with `latest`.

## Build results and testing

### ✅ Successful builds – Linux (native / WSL2)

The full pipeline runs reliably on **native x86_64 Linux** and **WSL2** (Windows Subsystem for Linux). The resulting image:

- Contains a complete AerynOS system with `bash`, core utilities, systemd, and `moss` package manager.
- Allows password‑less root login.
- Has UTC timezone and `en_US.UTF-8` locale preconfigured.
- Preserves the `.moss` package database, so additional software can be installed inside running containers.

Example test:

```bash
$ docker run --platform linux/amd64 -it aeryn-base:latest /usr/bin/bash
root@3d3805f731b8:/# uname -m
x86_64
root@3d3805f731b8:/# cat /etc/os-release
NAME="AerynOS"
VERSION_ID="2026.05"
...
```

### ❌ macOS (Apple Silicon) – partial success

On Apple Silicon with Docker Desktop (Rosetta enabled), the compilation stages complete successfully, but `moss install` fails during the `postblit` phase:

```
Error: install: install: client: postblit: container: exited with failure:
mount /output/rootfs/.moss/root/isolation/etc: ENOSYS: Function not implemented
```

**Root cause**: The QEMU user‑space emulation used on macOS does not implement the full set of mount system calls required by `bubblewrap` inside a user namespace. This limitation exists even with `--privileged` containers.

**Workaround**: Build the image on a native Linux / WSL2 host and push it to a container registry, then pull and use it on macOS:

```bash
# On Linux builder
docker tag aeryn-base:latest your-registry/aeryn-base:latest
docker push your-registry/aeryn-base:latest

# On macOS
docker pull your-registry/aeryn-base:latest
docker run --platform linux/amd64 -it your-registry/aeryn-base:latest /usr/bin/bash
```

## Known issues

- **macOS QEMU limits** – `postblit` isolation requires mount capabilities not available in QEMU user-mode. Native Linux (or WSL2) is required for a full local build.
- **`docker build` privilege** – `moss install` cannot run inside a Dockerfile `RUN` instruction because `bubblewrap` needs `CAP_SYS_ADMIN`. The workaround is the privileged `docker run` step used in `build.sh`.
- **File system case sensitivity** – Building on macOS directly with bind‑mounted host directories can cause problems because APFS is case‑insensitive by default. The project avoids this by streaming the root filesystem directly from the container.

## Future work

- [ ] Integrate CI/CD (e.g., GitHub Actions) to automatically build and push new `aeryn-base` images when the `os-tools` repository or the package repositories are updated.
- [ ] Provide pre‑built images on GitHub Container Registry or Docker Hub for easy consumption.
- [ ] Explore further reduction of the final image size (e.g., excluding unnecessary documentation or locales, while maintaining functionality).
- [ ] Add optional build arguments to select specific package sets (e.g., minimal vs. dev).
