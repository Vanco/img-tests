#!/usr/bin/env bash
set -e

SFSDIR=/output/rootfs
CACHE=/var/moss/cache

mkdir -p ${CACHE} ${SFSDIR}

moss -D ${SFSDIR} --cache ${CACHE} repo add volatile https://build.aerynos.dev/stream/volatile/x86_64/stone.index
moss -D ${SFSDIR} --cache ${CACHE} install -y fastfetch pkgset-aeryn-base pkgset-aeryn-utilities
systemd-nspawn --as-pid2 --private-users=identity --user=0 --quiet -D ${SFSDIR} \
    systemd-firstboot --force --delete-root-password --locale=en_US.UTF-8 --timezone=UTC --root-shell=/usr/bin/bash

rm -rf "${SFSDIR}"/.moss/cache/downloads/*

source ${SFSDIR}/etc/os-release 2>/dev/null || true
echo "AerynOS_VERSION=${VERSION_ID:-unknown}" >&2