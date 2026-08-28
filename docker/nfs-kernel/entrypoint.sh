#!/bin/sh
set -eu

STATE_DIR=/var/lib/nfs
THREADS_FILE=/proc/fs/nfsd/threads
NFSDCLD_PID=

stop_server() {
    exportfs -uav >/dev/null 2>&1 || :
    rpc.nfsd 0 >/dev/null 2>&1 || :
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
    pgrep -x nfsdcld >/dev/null
    test -r "${STATE_DIR}/nfsdcld/main.sqlite"
    exportfs -s >/dev/null
    exit 0
fi

test -x /usr/sbin/rpc.nfsd
test -x /usr/sbin/nfsdcld
test -x /usr/sbin/exportfs
test -r /etc/nfs.conf
test -r /etc/exports
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
    kill -0 "${NFSDCLD_PID}" >/dev/null 2>&1
    sleep 10
done
