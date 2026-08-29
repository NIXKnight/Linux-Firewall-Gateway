# syntax=docker/dockerfile:1.7

FROM --platform=linux/amd64 debian:sid-slim@sha256:17d1843dae9ca66f1617c1e464f40d06059ccefb0c606e8b54687f253af1684e

ARG NFS_UTILS_VERSION="1:2.9.2-1"

ENV DEBIAN_FRONTEND=noninteractive

RUN set -eux; \
    printf '%s\n' '#!/bin/sh' 'exit 101' > /usr/sbin/policy-rc.d; \
    chmod 0755 /usr/sbin/policy-rc.d; \
    apt-get update; \
    apt-get install --yes --no-install-recommends \
        "nfs-kernel-server=${NFS_UTILS_VERSION}" \
        "nfs-common=${NFS_UTILS_VERSION}" \
        procps \
        util-linux; \
    rm -f /usr/sbin/policy-rc.d; \
    if [ -d /etc/systemd ]; then \
        find /etc/systemd -type l \
            \( -lname '*rpcbind*' -o -lname '*rpc-statd*' \) \
            -delete; \
    fi; \
    : > /etc/exports; \
    test -x /usr/sbin/rpc.nfsd; \
    test -x /usr/sbin/nfsdcld; \
    test -x /usr/sbin/rpc.idmapd; \
    test -x /usr/sbin/rpc.mountd; \
    test -x /usr/sbin/exportfs; \
    test -x /usr/bin/mountpoint; \
    rm -rf /var/lib/apt/lists/*

COPY nfs.conf /etc/nfs.conf
COPY idmapd.conf /etc/idmapd.conf
COPY entrypoint.sh /usr/local/sbin/nfs-kernel-entrypoint

RUN chmod 0755 /usr/local/sbin/nfs-kernel-entrypoint

EXPOSE 2049/tcp
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD ["/usr/local/sbin/nfs-kernel-entrypoint", "--health"]

ENTRYPOINT ["/usr/local/sbin/nfs-kernel-entrypoint"]
