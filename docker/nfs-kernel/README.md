# nixknight/nfs-kernel

This image supplies the userland control tools for the Talos kernel NFS server. The Talos `siderolabs/nfsd` extension supplies the version-matched `nfsd.ko` module; this image does not load kernel modules.

## Contract

- Base image: Debian trixie-slim, pinned to the amd64 OCI manifest digest in the Dockerfile.
- NFS-utils: Debian trixie `1:2.8.3-1`, installed with init-script startup blocked during the build.
- Runtime: privileged container with `hostNetwork: true` and access to `/proc/fs/nfsd`.
- Server processes: `rpc.nfsd` and `exportfs` only. The entrypoint does not launch `rpcbind`, `rpc.mountd`, or `rpc.statd`.
- Protocol: NFSv4.1 and NFSv4.2 over TCP port 2049. NFSv2, NFSv3, NFSv4.0, and UDP are disabled in `/etc/nfs.conf`.
- Persistent state: mount the server PVC at `/var/lib/nfs`. Preserve `etab`, `nfsdcltrack`, and the NFSv4 recovery directory across restarts.
- Export configuration: mount the environment-specific `/etc/exports` file into the container. The image does not contain site-specific client addresses or export paths.

## Entrypoint behavior

The entrypoint fails closed when `/proc/fs/nfsd`, `rpc.nfsd`, `exportfs`, or `/etc/exports` is unavailable. It creates persistent state directories, mounts the kernel NFS control filesystem inside the privileged container, starts the configured NFSD threads, loads exports, and remains alive while checking the thread count. SIGTERM unexports and stops the kernel server before exit.

The health probe is read-only: it requires a positive NFSD thread count and a readable export table. It does not start services.

## Build and static checks

```sh
shellcheck entrypoint.sh
docker build --platform linux/amd64 -t nixknight/nfs-kernel:local .
docker run --rm --entrypoint /bin/sh nixknight/nfs-kernel:local -c 'command -v rpc.nfsd && command -v exportfs && ! pgrep -x rpcbind && ! pgrep -x rpc.mountd && ! pgrep -x rpc.statd'
```

A live runtime test must run only after the matching Talos extension is installed and the Operator authorizes a privileged test. The test must verify listeners, exports, ownership squashing, locking, restart recovery, and absence of UDP/RPC auxiliary listeners.
