#!/bin/sh
set -eu

STATE_DIR=/var/lib/nfs
THREADS_FILE=/proc/fs/nfsd/threads
MOUNTD_PID=
IDMAPD_PID=
NFSDCLD_PID=

stop_server() {
    exportfs -uav >/dev/null 2>&1 || :
    rpc.nfsd 0 >/dev/null 2>&1 || :
    if [ -n "${MOUNTD_PID}" ]; then
        kill "${MOUNTD_PID}" >/dev/null 2>&1 || :
        wait "${MOUNTD_PID}" >/dev/null 2>&1 || :
        MOUNTD_PID=
    fi
    if [ -n "${IDMAPD_PID}" ]; then
        kill "${IDMAPD_PID}" >/dev/null 2>&1 || :
        wait "${IDMAPD_PID}" >/dev/null 2>&1 || :
        IDMAPD_PID=
    fi
    if [ -n "${NFSDCLD_PID}" ]; then
        kill "${NFSDCLD_PID}" >/dev/null 2>&1 || :
        wait "${NFSDCLD_PID}" >/dev/null 2>&1 || :
        NFSDCLD_PID=
    fi
    umount "${STATE_DIR}/rpc_pipefs" >/dev/null 2>&1 || :
}

on_signal() {
    trap - INT TERM 0
    stop_server
    exit 0
}

if [ "${1:-}" = "--health" ]; then
    test -r "${THREADS_FILE}"
    test "$(cat "${THREADS_FILE}")" -gt 0
    pgrep -x rpc.mountd >/dev/null
    pgrep -x rpc.idmapd >/dev/null
    pgrep -x nfsdcld >/dev/null
    test -r "${STATE_DIR}/nfsdcld/main.sqlite"
    exportfs -s >/dev/null
    exit 0
fi

test -x /usr/sbin/rpc.mountd
test -x /usr/sbin/rpc.nfsd
test -x /usr/sbin/rpc.idmapd
test -x /usr/sbin/nfsdcld
test -x /usr/sbin/exportfs
test -r /etc/nfs.conf
test -r /etc/exports
test -r /etc/idmapd.conf
test -d /proc/fs/nfsd

mkdir -p \
    "${STATE_DIR}" \
    "${STATE_DIR}/nfsdcld" \
    "${STATE_DIR}/v4recovery" \
    "${STATE_DIR}/rpc_pipefs"

mountpoint -q /proc/fs/nfsd || mount -t nfsd nfsd /proc/fs/nfsd
mountpoint -q "${STATE_DIR}/rpc_pipefs" || mount -t rpc_pipefs rpc_pipefs "${STATE_DIR}/rpc_pipefs"

trap on_signal INT TERM
trap stop_server 0

rpc.mountd -F -L -N 2 -N 3 -u -s "${STATE_DIR}" &
MOUNTD_PID=$!
sleep 1
kill -0 "${MOUNTD_PID}" >/dev/null 2>&1

rpc.idmapd -S -f -p "${STATE_DIR}/rpc_pipefs" &
IDMAPD_PID=$!
sleep 1
kill -0 "${IDMAPD_PID}" >/dev/null 2>&1

nfsdcld -F \
    -p "${STATE_DIR}/rpc_pipefs" \
    -s "${STATE_DIR}/nfsdcld" &
NFSDCLD_PID=$!
sleep 1
kill -0 "${NFSDCLD_PID}" >/dev/null 2>&1

rpc.nfsd 8
exportfs -rav

test -r "${THREADS_FILE}"
test "$(cat "${THREADS_FILE}")" -gt 0

while :; do
    test "$(cat "${THREADS_FILE}")" -gt 0
    kill -0 "${MOUNTD_PID}" >/dev/null 2>&1
    kill -0 "${IDMAPD_PID}" >/dev/null 2>&1
    kill -0 "${NFSDCLD_PID}" >/dev/null 2>&1
    sleep 10
done
