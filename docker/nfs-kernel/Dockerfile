# syntax=docker/dockerfile:1.7

FROM --platform=linux/amd64 debian:trixie-slim@sha256:abc9cb88a5587630d7f915f47b23b0668fe250fbfc6457aa4d52b534c1bbf73f

ARG NFS_UTILS_VERSION="1:2.8.3-1"

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
