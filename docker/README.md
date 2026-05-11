# AerynOS Docker Image

This project builds a Docker image of the AerynOS root filesystem (RootFS) based on `scratch`. It includes the `moss` package manager, the AerynOS base toolset, and several utilities (`fastfetch`, `btop`, `vim`, `starship`, etc.).

## 📋 Prerequisites

- Docker installed (recommended version 20.10+)
- **Buildx** plugin (included with Docker by default)
- Stable network connection (for pulling base images and dependencies)

> **Note**: The build process uses a privileged `RUN --security=insecure` instruction. Therefore you **must** use a Buildx builder with the `docker-container` driver and explicitly grant the insecure entitlement.

## 🚀 Build Instructions

### 1. Create a Buildx builder that supports insecure entitlements

```bash
docker buildx create --name insecure-builder \
  --driver docker-container \
  --buildkitd-flags '--allow-insecure-entitlement security.insecure' \
  --use
  --bootstrap
```

### 2. (Optional) Configure a registry mirror

If your network access to Docker Hub is slow, you can set a registry mirror for the builder (e.g., using DaoCloud):

Create a TOML at `/etc/buildkitd.toml` with the following content:

```toml
debug = true
[registry."docker.io"]
  mirrors = ["docker.m.daocloud.io"]
```

Create a `docker-container` builder that use this BuildKit configuration:

```bash
# remove if created before
docker buildx rm insecure-builder
# create new one with mirror config
docker buildx create --name insecure-builder \
  --driver docker-container \
  --buildkitd-flags '--allow-insecure-entitlement security.insecure' \
  --buildkitd-config /etc/buildkitd.toml \
  --use
  --bootstrap
```

### 3. Build the image

In the project root directory (containing `Dockerfile` and `docker-model.kdl`), run:

```bash
docker buildx build \
  --builder insecure-builder \
  --allow security.insecure \
  --load \
  -t aeryn-base:latest .
```

- `--allow security.insecure`: grants the privilege needed for `RUN --security=insecure` steps.
- `--load`: loads the built image into the local Docker image store.

### 4. Verify the image

```bash
docker images | grep aeryn-base
```

## 🧪 Run the container

### Interactive shell

```bash
docker run -it --rm aeryn-base:latest
```

Once inside the container, you can use the following commands:

```bash
fastfetch          # Display system information
btop               # System monitor
moss list          # List installed packages
vim                # Text editor
starship           # Start the Starship prompt
```

### Run a specific command

```bash
docker run --rm aeryn-base:latest fastfetch
```

## 🛠️ Image contents

Built from `scratch`, the image includes:

- AerynOS base package sets (`pkgset-aeryn-base`, `pkgset-aeryn-utilities`)
- Utilities: `fastfetch`, `btop`, `tree`, `vim`, `starship`
- `moss` package manager 
- Basic Bash environment 
- Timezone set to UTC, locale set to `en_US.UTF-8`

## ⚠️ Troubleshooting

### Q: Build fails with `granting entitlement security.insecure is not allowed`

**A:** You are not using the correct Buildx builder. Make sure you followed **Step 1** to create `insecure-builder` with `--buildkitd-flags '--allow-insecure-entitlement security.insecure'`.

### Q: Timeout while pulling the base image

**A:** Please refer to **Step 2** to configure a registry mirror, or manually pull and retag the image:

```bash
docker pull docker.m.daocloud.io/library/debian:latest
docker tag docker.m.daocloud.io/library/debian:latest debian:latest
```

### Q: `btop` reports `No tty detected!`

**A:** Make sure you run the container with `-it` to allocate an interactive terminal. If it still fails, try `exec /bin/bash -l -i` and then run `btop` again.

## 📄 License

This project is licensed under the MPL-2.0.

## 🤝 Contributing

Issues and pull requests are welcome.
