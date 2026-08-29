# nixknight/nfs-kernel

This image supplies the userland control tools for the Talos kernel NFS server. The Talos `siderolabs/nfsd` extension supplies the version-matched `nfsd.ko` module; this image does not load kernel modules.

## Contract

- Base image: Debian sid-slim, pinned to the amd64 OCI manifest digest in the Dockerfile.
- NFS-utils: Debian sid `1:2.9.2-1`, installed with init-script startup blocked during the build; this version supplies mountd's `--no-netlink` compatibility switch.
- Runtime: privileged container with `hostNetwork: true` and access to `/proc/fs/nfsd`.
- Server processes: `rpc.mountd`, `rpc.idmapd`, `nfsdcld`, `rpc.nfsd`, and `exportfs` only. Mountd is a server-only kernel authorization helper; the entrypoint does not launch `rpcbind` or `rpc.statd`.
- Protocol: NFSv4.1 and NFSv4.2 over TCP port 2049. NFSv2, NFSv3, NFSv4.0, UDP, and NFSv2/v3 MOUNT protocol operations are disabled.
- ID mapping: `rpc.idmapd` uses the explicit NFSv4 domain `h.nixknight.pk` and maps fallback identities to Debian's `nobody:nogroup` through `/etc/idmapd.conf`; clients must use the same domain for stable name/UID mapping.
- Persistent state: mount the server PVC at `/var/lib/nfs`. Preserve the `nfsdcld` database under `/var/lib/nfs/nfsdcld` and the NFSv4 recovery directory across restarts.
- Export configuration: mount the environment-specific `/etc/exports` file into the container. The image does not contain site-specific client addresses or export paths.

## Entrypoint behavior

The entrypoint fails closed when `/proc/fs/nfsd`, `rpc.mountd`, `rpc.idmapd`, `nfsdcld`, `rpc.nfsd`, `exportfs`, or `/etc/exports` is unavailable. It creates persistent state directories, mounts the kernel NFS control filesystem and `rpc_pipefs` inside the privileged container, starts server-only `rpc.mountd` for kernel export authorization using its legacy `/proc/net/rpc` cache path, starts `rpc.idmapd` for NFSv4 ID-mapping upcalls, starts `nfsdcld` for kernel client-recovery upcalls, starts the configured NFSD threads, loads exports, and remains alive while checking all helper daemons. The `--no-netlink -N 2 -N 3 -u` mountd boundary avoids the incompatible generic-netlink path while preventing NFSv2/v3 and UDP mount operations; its RPC listener socket is expected. SIGTERM unexports, stops the kernel server, and stops all helpers before exit.

The health probe is read-only: it requires a positive NFSD thread count, live `rpc.mountd`, `rpc.idmapd`, and `nfsdcld` processes, the persistent recovery database, the configured `h.nixknight.pk` ID-mapping domain, and a readable export table. It does not reject mountd's expected RPC listener socket or start services.

## Build and static checks

```sh
shellcheck entrypoint.sh
docker build --platform linux/amd64 -t nixknight/nfs-kernel:local .
docker run --rm --entrypoint /bin/sh nixknight/nfs-kernel:local -c 'command -v rpc.mountd && rpc.mountd --help 2>&1 | grep -F -- "--no-netlink" && command -v rpc.idmapd && command -v nfsdcld && command -v rpc.nfsd && command -v exportfs && grep -Fxq "Domain = h.nixknight.pk" /etc/idmapd.conf && grep -Fxq "Nobody-Group = nogroup" /etc/idmapd.conf && ! pgrep -x rpcbind && ! pgrep -x rpc.statd'
```

A live runtime test must run only after the matching Talos extension is installed and the Operator authorizes a privileged test. The test must verify listeners, exports, ownership squashing, locking, restart recovery, and absence of UDP/RPC auxiliary listeners.
