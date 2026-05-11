# ============================================================
# Single stage: compile moss/boulder natively on amd64
# and prepare the rootfs builder environment
# ============================================================
FROM debian:latest AS rootfs-builder

# Combine build dependencies + runtime dependencies for moss
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential curl git pkg-config libssl-dev ca-certificates \
    bubblewrap uidmap systemd-container xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Use Alibaba Cloud mirror for Rustup (speeds up toolchain downloads)
ENV RUSTUP_DIST_SERVER="https://mirrors.aliyun.com/rustup"
ENV RUSTUP_UPDATE_ROOT="https://mirrors.aliyun.com/rustup/rustup"

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Use Alibaba Cloud mirror for Cargo (speeds up crate downloads)
RUN mkdir -p /root/.cargo && \
   echo '[source.crates-io]' > /root/.cargo/config.toml && \
   echo 'replace-with = "aliyun"' >> /root/.cargo/config.toml && \
   echo '' >> /root/.cargo/config.toml && \
   echo '[source.aliyun]' >> /root/.cargo/config.toml && \
   echo 'registry = "sparse+https://mirrors.aliyun.com/crates.io-index/"' >> /root/.cargo/config.toml && \
   echo '' >> /root/.cargo/config.toml

# Install just via Cargo
RUN cargo install just

# Configure subordinate UID/GID mapping for bubblewrap
# (following upstream recommendation: start at 1000000, range size 65536)
RUN echo "root:1000000:65536" > /etc/subuid && \
    echo "root:1000000:65536" > /etc/subgid

# Clone os-tools and perform full build & installation with just
WORKDIR /tmp/aeryn-build
RUN git clone https://github.com/AerynOS/os-tools.git
WORKDIR /tmp/aeryn-build/os-tools
RUN just get-started

# Ensure ~/.local/bin is in PATH (moss and boulder are installed there)
ENV PATH="/root/.local/bin:${PATH}"

# Set up directories for moss installation
#moss -D /output/rootfs install -y fastfetch pkgset-aeryn-base pkgset-aeryn-utilities tree vim btop starship && \
#
WORKDIR /output/rootfs
COPY system-model.kdl /tmp/system-model.kdl
RUN --security=insecure \
    moss -D /output/rootfs repo add volatile https://build.aerynos.dev/stream/volatile/x86_64/stone.index && \
    moss -D /output/rootfs sync -u --import /tmp/system-model.kdl -y && \
    mkdir -p /output/rootfs/home /output/rootfs/root && \
    rm -rf /output/rootfs/.moss/cache/downloads/*

CMD [ "/bin/bash" ]

FROM scratch

ENV PATH="/usr/local/bin:/usr/bin:/bin:/sbin"

COPY --from=rootfs-builder /output/rootfs /

RUN <<EOF
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    if [[ ! -f /etc/passwd ]]; then
        echo "root:x:0:0:root:/root:/bin/bash" > /etc/passwd
    fi
    if [[ ! -f /etc/group ]]; then
        echo "root:x:0:" > /etc/group
    fi
    if [[ -f /etc/shadow ]]; then
        sed -i 's/^root:[^:]*:/root::/' /etc/shadow
    fi
    #echo 'export PS1="\\u@\\h:\\w\\$ "' > /root/.bashrc
    #echo 'export PS1="\\u@\\h:\\w\\$ "' > /etc/bashrc
EOF

WORKDIR /root
CMD [ "/bin/bash", "-l", "-i" ]
