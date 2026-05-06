#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------
IMAGE_NAME="${IMAGE_NAME:-aeryn-base}"
TARGET_PLATFORM="linux/amd64"          # we always build x86_64 images
ROOTFS_BUILDER_IMAGE="aeryn-rootfs-builder:tmp"
TAR_FILE="./aeryn-rootfs.tar"

# ----------------------------------------------------------------------
# Detect container runtime (podman or docker)
# ----------------------------------------------------------------------
detect_runtime() {
    if command -v podman &>/dev/null; then
        RUNTIME="podman"
    elif command -v docker &>/dev/null; then
        RUNTIME="docker"
    else
        echo "Error: neither Docker nor Podman found. Please install one of them."
        exit 1
    fi
}

# ----------------------------------------------------------------------
# Choose Dockerfile based on host architecture
# ----------------------------------------------------------------------
select_dockerfile() {
    case "$(uname -m)" in
        x86_64)
            DOCKERFILE="Dockerfile.amd64"
            HOST_PLATFORM="linux/amd64"
            echo "Detected x86_64 host, using ${DOCKERFILE}"
            ;;
        aarch64|arm64)
            DOCKERFILE="Dockerfile.arm64"
            HOST_PLATFORM="linux/arm64"
            echo "Detected arm64 host, using ${DOCKERFILE}"
            ;;
        *)
            echo "Unsupported host architecture: $(uname -m)"
            exit 1
            ;;
    esac
}

# ----------------------------------------------------------------------
# Cleanup temporary artifacts
# ----------------------------------------------------------------------
cleanup() {
    echo "Cleaning up temporary resources..."
    ${RUNTIME} rmi -f "${ROOTFS_BUILDER_IMAGE}" &>/dev/null || true
    rm -f "${TAR_FILE}"
}
trap cleanup EXIT

# ----------------------------------------------------------------------
# Main build steps
# ----------------------------------------------------------------------
main() {
    detect_runtime
    select_dockerfile

    echo ">>> 1. Building rootfs-builder image (without moss install)..."
    ${RUNTIME} build \
        --platform "${TARGET_PLATFORM}" \
        --build-arg BUILDPLATFORM="${HOST_PLATFORM}" \
        --build-arg TARGETPLATFORM="${TARGET_PLATFORM}" \
        --target rootfs-builder \
        -t "${ROOTFS_BUILDER_IMAGE}" \
        -f "${DOCKERFILE}" .

    echo ">>> 2. Running moss install in a privileged container and exporting rootfs..."
    exec 3>&1
    ${RUNTIME} run --platform "${TARGET_PLATFORM}" \
        --privileged --rm \
        -v "$(pwd)/install-rootfs.sh:/install-rootfs.sh:ro" \
        "${ROOTFS_BUILDER_IMAGE}" \
        bash -c "/install-rootfs.sh >&2 && tar -cf - -C /output/rootfs ." > "${TAR_FILE}" 2>stderr.log
    # get VERSION from stderr.log
    VERSION=$(grep -oP 'AerynOS_VERSION=\K.*' stderr.log || echo "$(date +%Y%m%d)")
    rm -f stderr.log

    IMAGE_FULLNAME="${IMAGE_NAME}:${VERSION}"
    IMAGE_LATEST="${IMAGE_NAME}:latest"

    echo ">>> 3. Importing final image as ${IMAGE_NAME}..."
    ${RUNTIME} import "${TAR_FILE}" "${IMAGE_FULLNAME}"
    ${RUNTIME} tag "${IMAGE_FULLNAME}" "${IMAGE_LATEST}"

    echo "Build successful! Created images:"
    echo "    ${IMAGE_FULLNAME}"
    echo "    ${IMAGE_LATEST}"
    echo "Run with:"
    echo "    ${RUNTIME} run --platform ${TARGET_PLATFORM} -it ${IMAGE_LATEST} /usr/bin/bash"
}

main "$@"