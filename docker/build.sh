#!/usr/bin/env bash

# 获取当前宿主机的架构，并映射为 Linux 平台
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        HOST_PLATFORM="linux/amd64"
        ;;
    aarch64|arm64)
        HOST_PLATFORM="linux/arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# 设置目标平台（你需要构建的最终镜像架构）
TARGET_PLATFORM="linux/amd64"

echo "Host platform: $HOST_PLATFORM"
echo "Target platform: $TARGET_PLATFORM"

# 执行构建命令
podman build \
  --build-arg BUILDPLATFORM="${HOST_PLATFORM}" \
  --build-arg TARGETPLATFORM="${TARGET_PLATFORM}" \
  --platform "${TARGET_PLATFORM}" \
  -t aerynos-base:latest \
  .
