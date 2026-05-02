# 构建参数
ARG BUILDPLATFORM
ARG TARGETPLATFORM

# ==============================================
# 阶段 1：交叉编译 moss 和 boulder (在宿主原生架构上进行)
# ==============================================
FROM --platform=${BUILDPLATFORM} debian:latest AS builder

# 安装系统依赖 + 交叉编译工具链 + x86_64 目标系统库
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential curl bzip2 git gcc make python3 ca-certificates \
    pkg-config libssl-dev gcc-x86-64-linux-gnu \
    libc6-dev-amd64-cross \
    && rm -rf /var/lib/apt/lists/*

# 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# 添加 x86_64 编译目标
RUN rustup target add x86_64-unknown-linux-gnu

# 配置 Cargo 使用交叉链接器，并允许交叉编译
RUN mkdir -p /root/.cargo && \
    echo '[target.x86_64-unknown-linux-gnu]' > /root/.cargo/config.toml && \
    echo 'linker = "x86_64-linux-gnu-gcc"' >> /root/.cargo/config.toml

# 设置环境变量允许 pkg-config 交叉编译
ENV PKG_CONFIG_ALLOW_CROSS=1

WORKDIR /tmp/aeryn-build
RUN git clone https://github.com/AerynOS/os-tools.git

# 编译 boulder (x86_64) - 修正构建命令
RUN cd os-tools && \
    cargo build --release -p boulder --target x86_64-unknown-linux-gnu && \
    cp target/x86_64-unknown-linux-gnu/release/boulder /usr/local/bin/boulder

# 编译 moss (x86_64) - 修正构建命令
RUN cd os-tools && \
    cargo build --release -p moss --target x86_64-unknown-linux-gnu && \
    cp target/x86_64-unknown-linux-gnu/release/moss /usr/local/bin/moss

# 验证产物架构
RUN ls -la /usr/local/bin/moss /usr/local/bin/boulder

# ==============================================
# 阶段 2：生成 AerynOS 根文件系统 (目标架构：amd64)
# ==============================================
FROM --platform=${TARGETPLATFORM} debian:latest AS rootfs-builder

COPY --from=builder /usr/local/bin/moss /usr/local/bin/moss
COPY --from=builder /usr/local/bin/boulder /usr/local/bin/boulder
RUN chmod +x /usr/local/bin/moss /usr/local/bin/boulder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates uidmap curl bubblewrap systemd-container \
    && rm -rf /var/lib/apt/lists/*

RUN echo "root:100000:65536" > /etc/subuid && \
    echo "root:100000:65536" > /etc/subgid

ENV RUST_BACKTRACE=1
ENV SFSDIR=/output/rootfs
ENV CACHE=/var/moss/cache
ENV MOSS="moss -D ${SFSDIR} --cache ${CACHE}"
ENV CHROOT="systemd-nspawn --as-pid2 --private-users=identity --user=0 --quiet"
RUN mkdir -p ${CACHE} ${SFSDIR}/{etc,proc,run,sys,usr,var,var/local}

RUN ${MOSS} repo add volatile https://build.aerynos.dev/stream/volatile/x86_64/stone.index
# Fixit: Error: install: install: client: postblit: container: nix: EINVAL: Invalid argument
RUN ${MOSS} install -y fastfetch pkgset-aeryn-base pkgset-aeryn-utilities || true
#RUN ${CHROOT} -D "${SFSDIR}" systemd-firstboot --force --delete-root-password --locale=en_US.UTF-8 --timezone=UTC --root-shell=/usr/bin/bash

# Remove downloaded .stones to lower size of generated image
RUN rm -rf "${SFSDIR}"/.moss/cache/downloads/*

#RUN chroot ${SFSDIR} /bin/sh -c "useradd -m -s /bin/bash aeryn 2>/dev/null || true" && \
#    echo "root:root" | chroot ${SFSDIR} chpasswd 2>/dev/null || true

# ==============================================
# 阶段 3：最终纯净镜像
# ==============================================
FROM scratch
COPY --from=rootfs-builder /output/rootfs /
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
CMD ["/usr/bin/bash"]
