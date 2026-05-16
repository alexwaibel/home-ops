# Copilot instructions for `home-ops`

## Repo purpose

- Home infrastructure repo for a Talos Kubernetes cluster managed by Flux, plus NixOS machine configs.
- Prefer GitOps inspection from manifests before querying the live cluster.

## Directory layout

- `kubernetes/apps/` — app and platform workloads grouped by namespace, each with `ks.yaml` and an `app/` (or `cluster/`) directory.
- `kubernetes/components/` — reusable Kustomize components (notably `sops`, `alerts`, `volsync`).
- `kubernetes/flux/cluster/` — Flux entrypoint Kustomization(s).
- `scripts/` — operational shell scripts.
- `docs/` — cluster docs and bootstrap/dependency notes.
- `nix/` — NixOS and dev shell configuration.

## Flux conventions used here

- Top-level namespace groups under `kubernetes/apps/*/kustomization.yaml` include:
    - `../../components/sops`
    - `../../components/alerts`
- Per-app Flux objects are in `kubernetes/apps/<group>/<app>/ks.yaml`.
- App manifests live in `kubernetes/apps/<group>/<app>/app/` (or `/cluster/` for workload resources).
- Flux source is `GitRepository/flux-system`; app `Kustomization.spec.path` points to repo-relative manifest paths.

## Secrets and sensitive data rules

- Secret management uses SOPS-encrypted files (`*.sops.yaml`) and External Secrets (`external-secrets.io`).
- Never commit plaintext credentials, tokens, keys, or decrypted secret files.
- Never attempt to read decrypted `Secret` objects from the cluster.
- Use ExternalSecret/SecretStore definitions and SOPS manifests in Git as source of truth.

## Read-only kubeconfig workflow for AI agents

- Do **not** use the admin kubeconfig for Copilot/`ghc`.
- Use the scoped ServiceAccount (`agentic/copilot-readonly`) and generate a short-lived kubeconfig:

```sh
scripts/generate-copilot-kubeconfig.sh
export KUBECONFIG="$HOME/.kube/copilot-config"
```

- Run the setup once from your normal kubeconfig context. The generated kubeconfig refreshes short-lived tokens automatically with a local exec credential helper.

- Optional overrides:

```sh
scripts/generate-copilot-kubeconfig.sh -d 8h -o ~/.kube/copilot-config
```

## Preferred local/offline inspection commands

- Flux local tests/diff/render (matching CI path):

```sh
docker run --rm -v "$PWD:/github/workspace" ghcr.io/allenporter/flux-local:v8.2.0 \
  test --enable-helm --all-namespaces --path /github/workspace/kubernetes/flux/cluster -v
```

```sh
docker run --rm -v "$PWD:/github/workspace" ghcr.io/allenporter/flux-local:v8.2.0 \
  diff kustomization --path /github/workspace/kubernetes/flux/cluster \
  --path-orig /github/workspace/kubernetes/flux/cluster --all-namespaces
```

```sh
task kubernetes:render
```

- Additional read-only render/validation:
    - `kustomize build ...`
    - `helm template ...`
    - `kubeconform --strict --ignore-missing-schemas ...`
    - `flux diff ...` / `flux tree ...` / `flux trace ...`

## Change conventions

- Keep YAML style consistent with nearby files (2-space indent, explicit lists, same schema comments where used).
- For new apps/resources:
    - add `<app>/ks.yaml`
    - add `<app>/app/kustomization.yaml`
    - wire `./<app>/ks.yaml` into `kubernetes/apps/<group>/kustomization.yaml`.
- Helm-based apps generally pair `helmrelease.yaml` with `ocirepository.yaml`.

## Commands to avoid

- Any mutating cluster commands: `kubectl apply/delete/edit/patch/replace/create/scale/rollout/...`.
- Any interactive pod access or tunneling: `kubectl exec`, `kubectl attach`, `kubectl cp`, `kubectl port-forward`, `kubectl proxy`, `kubectl debug`.
- Any command that can exfiltrate data: arbitrary `curl`, `wget`, `nc`, `ssh`, `scp`.
