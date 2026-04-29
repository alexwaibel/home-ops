# ⛵ Kubernetes

My cluster runs on [Talos Linux](https://www.talos.dev/) and is managed with [Flux](https://github.com/fluxcd/flux2).

## ✨ Components

- [cert-manager](https://github.com/cert-manager/cert-manager): Automated SSL certificates for services
- [cilium](https://github.com/cilium/cilium): Internal networking for Kubernetes
- [cloudflare-tunnel](https://www.cloudflare.com/products/tunnel/): Secure access to external gateway
- [envoy](https://www.envoyproxy.io/): API gateway
- [external-dns](https://github.com/kubernetes-sigs/external-dns): DNS record sync between ingress and DNS provider
- [external-secrets](https://github.com/external-secrets/external-secrets): Managed Kubernetes secrets with [Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/)
- [openebs](https://github.com/openebs/openebs): Managed local path block storage for persistent storage
- [reloader](https://github.com/stakater/Reloader): Automated rolling upgrades for pods when secrets and configmaps are changed
- [renovate](https://github.com/renovatebot/renovate): Automated PRs for dependency upgrades including diffs using [flux-local](https://github.com/allenporter/flux-local)
- [rook](https://rook.io/): Distributed block storage using Ceph for persistent storage
- [sops](https://github.com/getsops/sops): Managed Kubernetes secrets which are encrypted and committed to Git
- [spegel](https://github.com/spegel-org/spegel): Stateless cluster local OCI registry mirror
- [volsync](https://github.com/backube/volsync): Backup and recovery of persistent volume claims to NAS and cloud storage

## Directories

My cluster config can be found in the [kubernetes](../kubernetes/) directory.

```sh
📁 kubernetes
├── 📁 apps           # applications
├── 📁 components     # re-usable kustomize components
└── 📁 flux           # flux system configuration
```

## 💻 Machine Preparation

### Talos

1. Download the latest stable release of Talos from their [GitHub releases](https://github.com/siderolabs/talos/releases). You will want to grab the `metal-amd64-secureboot.iso` image [linked here](https://www.talos.dev/v1.6/talos-guides/install/bare-metal-platforms/secureboot/#secureboot-with-sidero-labs-images).

2. Take note of the OS drive serial numbers you will need them later on.

3. Go to your BOIS and enable secure boot setup mode

4. Flash the iso or raw file to a USB drive and boot to Talos on your nodes with it. Select the option to "Enroll Secure Boot keys".

5. Boot from your Talos USB once again.

6. Continue on to 🚀 [**Getting Started**](#-getting-started)

## 🚀 Getting Started

Once you have installed Talos on your nodes, there are a few stages to getting a Flux-managed cluster up and running.

> [!NOTE]
> For all stages below the commands **MUST** be ran on your personal workstation within your repository directory

### 🌱 Stage 1: Setup your local workstation

1. Clone the repo to your local workstation and `cd` into it.

2. **Install** the [Mise CLI](https://mise.jdx.dev/getting-started.html#installing-mise-cli) on your workstation.

3. **Activate** Mise in your shell by following the [activation guide](https://mise.jdx.dev/getting-started.html#activate-mise).

4. Use `mise` to install the **required** CLI tools:

    ```sh
    mise trust
    mise install
    ```

   📍 _**Having trouble installing the tools?** Try unsetting the `GITHUB_TOKEN` env var and then run these commands again_

   📍 _**Having trouble compiling Python?** Try running `mise settings python.compile=0` and then run these commands again_

5. Logout of GitHub Container Registry (GHCR) as this may cause authorization problems when using the public registry:

    ```sh
    docker logout ghcr.io
    helm registry logout ghcr.io
    ```

6. Continue on to ⛵ [**Stage 2**](#-stage-2-install-kubernetes)

### ⛵ Stage 2: Install Kubernetes

#### Talos

> [!WARNING]
> It might take a while for the cluster to be setup (10+ minutes is normal). During which time you will see a variety of error messages like: "couldn't get current server API group list," "error: no matching resources found", etc. 'Ready' will remain "False" as no CNI is deployed yet. **This is a normal.** If this step gets interrupted, e.g. by pressing <kbd>Ctrl</kbd> + <kbd>C</kbd>, you likely will need to [reset the cluster](#-reset) before trying again

1. Install talos

    ```sh
    task bootstrap:talos
    ```

2. Install cilium, coredns, spegel, flux and sync the cluster to the repository state:

    ```sh
    task bootstrap:apps
    ```

3. Watch the rollout of your cluster happen:

    ```sh
    kubectl get pods --all-namespaces --watch
    ```

> [!NOTE]
> If you already have a running cluster and are only setting up a new development machine you can grab the config files from your password database, place them in the appropriate locations, and Continue on to 🎤 [**Verification Steps**](#-verification-steps)
> Place `kubeconfig` and `age.key` in the workspace root. Place `talosconfig` in `<workspace-root>/talos/clusterconfig/talosconfig`

#### Cluster validation

1. Check the status of Cilium:

    ```sh
    cilium status
    ```

2. Check the status of Flux and if the Flux resources are up-to-date and in a ready state:

   📍 _Run `task reconcile` to force Flux to sync your Git repository state_

    ```sh
    flux check
    flux get sources git flux-system
    flux get ks -A
    flux get hr -A
    ```

3. Check TCP connectivity to both the internal and external gateways:

   📍 _The variables are only placeholders, replace them with your actual values_

    ```sh
    nmap -Pn -n -p 443 ${cluster_gateway_addr} ${cloudflare_gateway_addr} -vv
    ```

4. Check you can resolve DNS for `echo`, this should resolve to `${cloudflare_gateway_addr}`:

   📍 _The variables are only placeholders, replace them with your actual values_

    ```sh
    dig @${cluster_dns_gateway_addr} echo.${cloudflare_domain}
    ```

5. Check the status of your wildcard `Certificate`:

    ```sh
    kubectl -n network describe certificates
    ```

## 📣 Cloudflare post installation

#### 🌐 Public DNS

The `external-dns` application created in the `networking` namespace will handle creating public DNS records. By default, `echo-server` and the `flux-webhook` are the only subdomains reachable from the public internet. In order to make additional applications public you must set set the correct ingress class name and ingress annotations like in the HelmRelease for `echo-server`.

#### 🏠 Home DNS

`k8s-gateway` will provide DNS resolution to external Kubernetes resources (i.e. points of entry to the cluster) from any device that uses your home DNS server. For this to work, your home DNS server needs to have a conditional forward set up for your domain to the `k8s-gateway` load balancer IP.

> [!TIP]
> Below is how to configure a Pi-hole for split DNS. Other platforms should be similar.
> 1. Apply this file on the Pi-hole server while substituting the variables
> ```sh
> # /etc/dnsmasq.d/99-k8s-gateway-forward.conf
> server=/<your-domain>/<k8s-gateway-lb-ip>
> ```
> 2. Restart dnsmasq on the server.
> 3. Query an internal-only subdomain from your workstation (any `internal` class routes): `dig @<home-dns-server-ip> echo-server-internal.<your-domain>`. It should resolve to your internal gateway IP.

If you're having trouble with DNS be sure to check out these two GitHub discussions: [Internal DNS](https://github.com/onedr0p/cluster-template/discussions/719) and [Pod DNS resolution broken](https://github.com/onedr0p/cluster-template/discussions/635).

... Nothing working? That is expected, this is DNS after all!

## 💥 Reset

> [!CAUTION]
> **Resetting** the cluster **multiple times in a short period of time** could lead to being **rate limited by DockerHub or Let's Encrypt**.

There might be a situation where you want to destroy your Kubernetes cluster. The following command will reset your nodes back to maintenance mode.

```sh
task talos:reset
```

## 🐛 Debugging

Below is a general guide on trying to debug an issue with an resource or application. For example, if a workload/resource is not showing up or a pod has started but in a `CrashLoopBackOff` or `Pending` state. These steps do not include a way to fix the problem as the problem could be one of many different things.

1. Check if the Flux resources are up-to-date and in a ready state:

   📍 _Run `task reconcile` to force Flux to sync your Git repository state_

    ```sh
    flux get sources git -A
    flux get ks -A
    flux get hr -A
    ```

2. Do you see the pod of the workload you are debugging:

    ```sh
    kubectl -n <namespace> get pods -o wide
    ```

3. Check the logs of the pod if its there:

    ```sh
    kubectl -n <namespace> logs <pod-name> -f
    ```

4. If a resource exists try to describe it to see what problems it might have:

    ```sh
    kubectl -n <namespace> describe <resource> <name>
    ```

5. Check the namespace events:

    ```sh
    kubectl -n <namespace> get events --sort-by='.metadata.creationTimestamp'
    ```

Resolving problems that you have could take some tweaking of your YAML manifests in order to get things working, other times it could be a external factor like permissions on a NFS server.

### ⬆️ Updating Talos and Kubernetes versions

#### Using Renovate
You should be able to accept renovate PRs to update Talos and Kubernetes via Tuppr. If you encounter issues with this you can try to manually update using the steps below.

#### Manually
> [!TIP]
> Ensure the `talosVersion` and `kubernetesVersion` in `talenv.yaml` are up-to-date with the version you wish to upgrade to.

```sh
# Upgrade node to a newer Talos version
task talos:upgrade-node IP=?
# e.g. task talos:upgrade-node IP=10.10.10.10
```

```sh
# Upgrade cluster to a newer Kubernetes version
task talos:upgrade-k8s
# e.g. task talos:upgrade-k8s
```

## 🤝 Thanks

A huge thank you for all the maintainers of the dependencies used by this project as well as onedr0p for the awesome [cluster template](https://github.com/onedr0p/cluster-template) which was used to initially create this repo. If you'd like to get started with your own cluster be sure to check it out.
