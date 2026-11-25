# Talos Configuration

[topf](https://postfinance.github.io/topf/main/migration-from-talhelper/) uses
`topf.yaml` and the existing SOPS-encrypted `talsecret.sops.yaml`. `secretsPath`
is relative to `topf.yaml`; set `SOPS_AGE_KEY_FILE` to the repository's `age.key`.

Talos and Kubernetes upgrades are done by Tuppr
(`kubernetes/apps/system-upgrade/tuppr`). Renovate bumps those alongside
`talosVersion`/`kubernetesVersion` in `topf.yaml`, which only control rendering.
Apply machine config changes only once nodes run the matching Talos version.

Machine configs are never rendered to disk: `topf` builds them in memory from
the secrets bundle. To preview all nodes from the repository root:

```sh
task talos:diff
```

A dry-run exits with status 2 when changes are detected; review the diff before applying.
`task talos:apply-node IP=192.168.20.21 DRY_RUN=true` previews a single node.

## talosctl access

Client certificates can't be revoked short of rotating the Talos CA, so only
short-lived ones are kept on disk. `scripts/talosconfig.sh` derives them via the
admin config from the secrets bundle, which only exists in a private temp dir.

- `task talos:config` mints an `os:reader` config (24h) at `$TALOSCONFIG`.
- `task talos:admin-config` mints an `os:admin` config (1h) under
  `$XDG_RUNTIME_DIR/home-ops/`; export `TALOSCONFIG` to use it.

Override the lifetime with `TTL=…`.
