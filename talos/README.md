# Talos Configuration

[topf](https://postfinance.github.io/topf/main/migration-from-talhelper/) uses
`topf.yaml` and the existing SOPS-encrypted `talsecret.sops.yaml`. `secretsPath`
is relative to `topf.yaml`; set `SOPS_AGE_KEY_FILE` to the repository's `age.key`.

Talos and Kubernetes upgrades are done by Tuppr
(`kubernetes/apps/system-upgrade/tuppr`). Renovate bumps those alongside
`talosVersion`/`kubernetesVersion` in `topf.yaml`, which only control rendering.
Apply machine config changes only once nodes run the matching Talos version.

Kubelet stays on legacy `machine.kubelet` because `KubeletConfig` cannot express
the OpenEBS `extraMounts`. Workload isolation is off because NFS and OpenEBS
mounts are unverified under it.

Run `task talos:generate-config` to render into the ignored `clusterconfig/`
directory. To preview all nodes from the repository root:

```sh
task talos:diff
```

A dry-run exits with status 2 when changes are detected; review the diff before applying.
`task talos:apply-node IP=192.168.20.21 DRY_RUN=true` previews a single node.
