# Talos Configuration

[topf](https://postfinance.github.io/topf/main/migration-from-talhelper/) uses
`topf.yaml` and the existing SOPS-encrypted `talsecret.sops.yaml`. `secretsPath`
is relative to `topf.yaml`; set `SOPS_AGE_KEY_FILE` to the repository's `age.key`.

Keep the cluster and per-node Talos pins aligned for offline rendering.
Renovate updates these pins and the annotated Kubernetes version in `topf.yaml`.

Run `task talos:generate-config` to render into the ignored `clusterconfig/`
directory. To preview all nodes from the repository root:

```sh
task talos:diff
```

A dry-run exits with status 2 when changes are detected; review the diff before applying.
`task talos:apply-node IP=192.168.20.21 DRY_RUN=true` previews a single node.
