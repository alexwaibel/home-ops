# ⛵ Home Ops
![Alertmanager](https://img.shields.io/endpoint?url=https%3A%2F%2Fhealthchecks.io%2Fb%2F2%2Ff884a193-fc8d-4da8-ace9-4cf1265c5c25.shields)

This is the repo for my home infrastructure including a kubernetes cluster. My cluster runs on [Talos Linux](https://www.talos.dev/) and is managed with [Flux](https://github.com/fluxcd/flux2).

## ✨ Components
- [cert-manager](https://github.com/cert-manager/cert-manager): Automated SSL certificates for services
- [cilium](https://github.com/cilium/cilium): Internal networking for Kubernetes
- [cloudflared](https://github.com/cloudflare/cloudflared): Secure access to certain ingresses using [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/)
- [external-dns](https://github.com/kubernetes-sigs/external-dns): DNS record sync between ingress and DNS provider
- [external-secrets](https://github.com/external-secrets/external-secrets): Managed Kubernetes secrets with [Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/)
- [nginx-ingress](https://github.com/kubernetes/ingress-nginx): Kubernetes ingress controller using NGINX as a reverse proxy and load balancer
- [openebs](https://github.com/openebs/openebs): Managed local path block storage for persistant storage
- [reloader](https://github.com/stakater/Reloader): Automated rolling upgrades for pods when secrets and configmaps are changed
- [renovate](https://github.com/renovatebot/renovate): Automated PRs for dependency upgrades including diffs using [flux-local](https://github.com/allenporter/flux-local)
- [rook](https://www.cloudflare.com/products/tunnel/): Distributed block storage using Ceph for persistant storage
- [sops](https://github.com/getsops/sops): Managed Kubernetes secrets which are encrypted and committed to Git
- [spegel](https://github.com/spegel-org/spegel): Stateless cluster local OCI registry mirror
- [volsync](https://github.com/backube/volsync): Backup and recovery of persistant volume claims to NAS and cloud storage

## 🔧 Hardware

| Device                  | Count | OS Disk   | Data Disk  | RAM  | OS       | Purpose                |
|-------------------------|-------|-----------|------------|------|----------|------------------------|
| Protectli VP2410        | 1     | 1TB SSD   | -          | 16GB | OPNSense | Router                 |
| TP-Link SG2016P         | 1     | -         | -          | -    | -        | 1Gb PoE Switch         |
| Intel NUC11PAHi7        | 3     | 500GB SSD | 1TB NVMe   | 32GB | Talos    | Kubernetes Controllers |
| Custom Tower            | 1     | -         | 4x12TB HDD | 32GB | Debian   | NFS                    |
| ADJ PC-100A             | -     | -         | -          | -    | -        | PDU                    |
| CyberPower OR500LCDRM1U | -     | -         | -          | -    | -        | UPS                    |

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

First clone the repo to your local workstation and `cd` into it.

You have two different options for setting up your local workstation.

- First option is using a `devcontainer` which requires you to have Docker and VSCode installed. This method is the fastest to get going because all the required CLI tools are provided for you.
- The second option is setting up the CLI tools directly on your workstation.

#### Devcontainer method

1. Start Docker and open your repository in VSCode. There will be a pop-up asking you to use the `devcontainer`, click the button to start using it.

2. Continue on to 🔧 [**Stage 3**](#-stage-3-bootstrap-configuration)

#### Non-devcontainer method

1. Install the most recent version of [task](https://taskfile.dev/), see the [installation docs](https://taskfile.dev/installation/) for other supported platforms.

    ```sh
    # Homebrew
    brew install go-task
    # or, Arch
    pacman -S --noconfirm go-task && ln -sf /usr/bin/go-task /usr/local/bin/task
    ```

2. Install the most recent version of [direnv](https://direnv.net/), see the [installation docs](https://direnv.net/docs/installation.html) for other supported platforms.

    ```sh
    # Homebrew
    brew install direnv
    # or, Arch
    pacman -S --noconfirm direnv
    ```

    📍 _After `direnv` is installed be sure to **[hook it into your preferred shell](https://direnv.net/docs/hook.html)** and then run `task workstation:direnv`_

3. Install the additional **required** CLI tools

   📍 _**Not using Homebrew or ArchLinux?** Try using the generic Linux task below, if that fails check out the [Brewfile](.taskfiles/Workstation/Brewfile)/[Archfile](.taskfiles/Workstation/Archfile) for what CLI tools needed and install them._

    ```sh
    # Homebrew
    task workstation:brew
    # or, Arch with yay/paru
    task workstation:arch
    # or, Generic Linux (YMMV, this pulls binaires in to ./bin)
    task workstation:generic-linux
    ```

4. Setup a Python virtual environment by running the following task command.

    📍 _This commands requires Python 3.11+ to be installed._

    ```sh
    task workstation:venv
    ```

5. Continue on to ⛵ [**Stage 2**](#-stage-3-install-kubernetes)

### ⛵ Stage 2: Install Kubernetes

#### Talos

1. Deploy your cluster and bootstrap it. This generates secrets, generates the config files for your nodes and applies them. It bootstraps the cluster afterwards, fetches the kubeconfig file and installs Cilium and kubelet-csr-approver. It finishes with some health checks.

    ```sh
    task talos:bootstrap
    ```

> [!NOTE]  
> If you already have a running cluster and are only setting up a new development machine you can grab the config files from your password database, place them in the appropriate locations, and Continue on to 🎤 [**Verification Steps**](#-verification-steps)
> Place `kubectl` and `age.key` in the workspace root. Place `talosconfig` in `<workspace-root>/kubernetes/bootstrap/talos/clusterconfig/talosconfig`

#### Cluster validation

1. The `kubeconfig` for interacting with your cluster should have been created in the root of your repository.

2. Verify the nodes are online

    📍 _If this command **fails** you likely haven't configured `direnv` as mentioned previously in the guide._

    ```sh
    kubectl get nodes -o wide
    # NAME           STATUS   ROLES                       AGE     VERSION
    # k8s-0          Ready    control-plane,etcd,master   1h      v1.29.1
    # k8s-1          Ready    worker                      1h      v1.29.1
    ```

3. Prepare the disks for rook

    ```
    task bootstrap:rook nodes=nuc1,nuc2,nuc3 disk=/dev/nvme0n1
    ```
    - You can find the disk name with `talosctl disks`

4. Continue on to 🔹 [**Stage 3**](#-stage-3-install-flux-in-your-cluster)

### 🔹 Stage 3: Install Flux in your cluster

1. Verify Flux can be installed

    ```sh
    flux check --pre
    # ► checking prerequisites
    # ✔ kubectl 1.27.3 >=1.18.0-0
    # ✔ Kubernetes 1.27.3+k3s1 >=1.16.0-0
    # ✔ prerequisites checks passed
    ```

2. Install Flux and sync the cluster to the Git repository
> [!WARNING]
> Make sure to increment the cnpg backup name first. See [this commit](https://github.com/alexwaibel/home-ops/commit/ff8c06ed4da086f1da538f922ddf9cf1448dd934) for an example.

    ```sh
    task flux:github-deploy-key
    task flux:bootstrap
    # namespace/flux-system configured
    # customresourcedefinition.apiextensions.k8s.io/alerts.notification.toolkit.fluxcd.io created
    # ...
    ```

1. Verify Flux components are running in the cluster

    ```sh
    kubectl -n flux-system get pods -o wide
    # NAME                                       READY   STATUS    RESTARTS   AGE
    # helm-controller-5bbd94c75-89sb4            1/1     Running   0          1h
    # kustomize-controller-7b67b6b77d-nqc67      1/1     Running   0          1h
    # notification-controller-7c46575844-k4bvr   1/1     Running   0          1h
    # source-controller-7d6875bcb4-zqw9f         1/1     Running   0          1h
    ```

### 🎤 Verification Steps

_Mic check, 1, 2_ - In a few moments applications should be lighting up like Christmas in July 🎄

1. Output all the common resources in your cluster.

    📍 _Feel free to use the provided [kubernetes tasks](.taskfiles/Kubernetes/Taskfile.yaml) for validation of cluster resources or continue to get familiar with the `kubectl` and `flux` CLI tools._

    ```sh
    task kubernetes:resources
    ```

2. ⚠️ It might take `cert-manager` awhile to generate certificates, this is normal so be patient.

3. 🏆 **Congratulations** if all goes smooth you will have a Kubernetes cluster managed by Flux and your Git repository is driving the state of your cluster.

## 📣 Cloudflare post installation

#### 🌐 Public DNS

The `external-dns` application created in the `networking` namespace will handle creating public DNS records. By default, `echo-server` and the `flux-webhook` are the only subdomains reachable from the public internet. In order to make additional applications public you must set set the correct ingress class name and ingress annotations like in the HelmRelease for `echo-server`.

#### 🏠 Home DNS

`k8s_gateway` will provide DNS resolution to external Kubernetes resources (i.e. points of entry to the cluster) from any device that uses your home DNS server. For this to work, your home DNS server must be configured to forward DNS queries for `${bootstrap_cloudflare.domain}` to `${bootstrap_cloudflare.gateway_vip}` instead of the upstream DNS server(s) it normally uses. This is a form of **split DNS** (aka split-horizon DNS / conditional forwarding).

> [!TIP]
> Below is how to configure a Pi-hole for split DNS. Other platforms should be similar.
> 1. Apply this file on the Pihole server while substituting the variables
> ```sh
> # /etc/dnsmasq.d/99-k8s-gateway-forward.conf
> server=/${bootstrap_cloudflare.domain}/${bootstrap_cloudflare.gateway_vip}
> ```
> 2. Restart dnsmasq on the server.
> 3. Query an internal-only subdomain from your workstation (any `internal` class ingresses): `dig @${home-dns-server-ip} echo-server-internal.${bootstrap_cloudflare.domain}`. It should resolve to `${bootstrap_cloudflare.ingress_vip}`.

If you're having trouble with DNS be sure to check out these two GitHub discussions: [Internal DNS](https://github.com/onedr0p/cluster-template/discussions/719) and [Pod DNS resolution broken](https://github.com/onedr0p/cluster-template/discussions/635).

... Nothing working? That is expected, this is DNS after all!

## 💥 Nuke

There might be a situation where you want to destroy your Kubernetes cluster. This will completely clean the OS of all traces of the Kubernetes distribution you chose and then reboot the nodes.

```sh
# Talos: Reset your nodes back to maintenance mode and reboot
task talos:nuke
```

## 🐛 Debugging

Below is a general guide on trying to debug an issue with an resource or application. For example, if a workload/resource is not showing up or a pod has started but in a `CrashLoopBackOff` or `Pending` state.

1. Start by checking all Flux Kustomizations & Git Repository & OCI Repository and verify they are healthy.

    ```sh
    flux get sources oci -A
    flux get sources git -A
    flux get ks -A
    ```

2. Then check all the Flux Helm Releases and verify they are healthy.

    ```sh
    flux get hr -A
    ```

3. Then check the if the pod is present.

    ```sh
    kubectl -n <namespace> get pods -o wide
    ```

4. Then check the logs of the pod if its there.

    ```sh
    kubectl -n <namespace> logs <pod-name> -f
    # or
    stern -n <namespace> <fuzzy-name>
    ```

5. If a resource exists try to describe it to see what problems it might have.

    ```sh
    kubectl -n <namespace> describe <resource> <name>
    ```

6. Check the namespace events

    ```sh
    kubectl -n <namespace> get events --sort-by='.metadata.creationTimestamp'
    ```

Resolving problems that you have could take some tweaking of your YAML manifests in order to get things working, other times it could be a external factor like permissions on NFS. If you are unable to figure out your problem see the help section below.

## ⬆️ Upgrading Talos and Kubernetes

### Manual

```sh
# Upgrade Talos to a newer version
# : This needs to be run once on every node
task talos:upgrade node=? image=?
# e.g.
# task talos:upgrade node=192.168.42.10 image=factory.talos.dev/installer/${schematic_id}:v1.7.4
```

```sh
# Upgrade Kubernetes to a newer version
# : This only needs to be run once against a controller node
task talos:upgrade-k8s node=? to=?
# e.g.
# task talos:upgrade-k8s controller=192.168.42.10 to=1.30.1
```

## 🤝 Thanks

A huge thank you for all the maintainers of the dependencies used by this project as well as onedr0p for the awesome [cluster template](https://github.com/onedr0p/cluster-template) which was used to initially create this repo. If you'd like to get started with your own cluster be sure to check it out.
