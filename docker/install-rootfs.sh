#!/usr/bin/env bash
set -e

SFSDIR=/output/rootfs
CACHE=/var/moss/cache

mkdir -p ${CACHE} ${SFSDIR}

moss -D ${SFSDIR} --cache ${CACHE} repo add volatile https://build.aerynos.dev/stream/volatile/x86_64/stone.index
moss -D ${SFSDIR} --cache ${CACHE} install -y fastfetch pkgset-aeryn-base pkgset-aeryn-utilities

echo "LANG=en_US.UTF-8" > ${SFSDIR}/etc/locale.conf
ln -sf ../usr/share/zoneinfo/UTC ${SFSDIR}/etc/localtime

if [[ -f ${SFSDIR}/etc/shadow ]]; then
    sed -i 's/^root:[^:]*:/root::/' ${SFSDIR}/etc/shadow
fi

if [[ -f ${SFSDIR}/etc/os-release ]]; then
    source ${SFSDIR}/etc/os-release 2>/dev/null || true
    echo "AerynOS_VERSION=${VERSION_ID:-unknown}" >&2
else
    echo "AerynOS_VERSION=unknown" >&2
fi

rm -rf "${SFSDIR}"/.moss/cache/downloads/*
