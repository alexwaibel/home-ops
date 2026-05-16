# home-ops Agent Context

## Repository purpose

Home infrastructure repo for a Talos Kubernetes cluster managed by Flux, plus NixOS machine configuration.

## GitOps layout conventions

- `kubernetes/apps/` contains namespace groups, each with `kustomization.yaml` and per-app `ks.yaml`.
- `kubernetes/components/` contains reusable Kustomize components such as `sops` and `alerts`.
- `kubernetes/flux/cluster/ks.yaml` is the Flux entrypoint.

## AI access and safety

- Use read-only kubeconfig for AI sessions:
  - `scripts/generate-copilot-kubeconfig.sh`
  - ServiceAccount: `agentic/copilot-readonly`
- Never use admin kubeconfig for AI sessions.
- Never mutate the cluster from AI sessions unless explicitly requested by a human.
- Never expose Secret values.

## Preferred AI ergonomics

- Bootstrap AI setup with:
  - `task agent:setup -- --install-tools`
- Start Flux MCP in read-only mode:
  - `task agent:mcp-serve`
- Render/validate manifests offline before live checks:
  - `task kubernetes:render`

## Secrets policy

Use SOPS-encrypted files (`*.sops.yaml`) and ExternalSecret/SecretStore manifests as source of truth.
