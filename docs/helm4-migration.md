# Helm 3 → 4 Migration Notes

This repo upgraded from Helm 3.19.x to Helm 4.1.x. Key things to be aware of:

## Impact on this repo

**Low risk for Flux-managed clusters.** Flux's helm-controller performs the actual
Helm operations server-side — the `helm` binary in `.mise.toml` is primarily used
for local debugging (`helm template`, `helm diff`, etc.). The helm-controller will
need to be on a version that supports Helm 4 SDK, but the flux2 v2.8.5 bump
covers this.

## Key breaking changes in Helm 4

1. **Server-Side Apply (SSA) is now supported** — Helm 4 uses SSA and kstatus for
   resource watching. This may surface previously-hidden issues in chart hooks or
   readiness probes during `helm install --wait`.

2. **Plugin system redesigned** — If you use any Helm plugins locally (e.g.
   `helm-diff`, `helm-secrets`), verify they have Helm 4-compatible versions.

3. **OCI registries are the primary model** — The `HELM_EXPERIMENTAL_OCI` flag is
   removed. OCI is the default. This repo already uses OCI references in
   HelmReleases, so no changes needed.

4. **Some CLI flags removed** — Deprecated flags like `--generate-name` are gone.
   Update any local scripts that use removed flags.

5. **Chart v2 API still supported** — Existing charts (apiVersion: v2) continue to
   work. No chart changes needed.

## References

- [Helm v4.0.0 Release Notes](https://github.com/helm/helm/releases/tag/v4.0.0)
- [Helm v4 Breaking Changes Discussion](https://dev.to/vainkop/helm-v4-is-here-what-actually-breaks-when-you-upgrade-3jdg)
