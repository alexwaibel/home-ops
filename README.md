# ⛵ Home Ops

![Alertmanager](https://img.shields.io/endpoint?url=https%3A%2F%2Fhealthchecks.io%2Fb%2F2%2Ff884a193-fc8d-4da8-ace9-4cf1265c5c25.shields)

This is the repo for my home infrastructure including a kubernetes cluster. My cluster runs on [Talos Linux](https://www.talos.dev/) and is managed with [Flux](https://github.com/fluxcd/flux2) and the rest of my machines run on [NixOS](https://nixos.org/).

## Directories

```sh
📁 docs               # documentation
📁 kubernetes         # kubernetes cluster
📁 nix                # nix configurations
```

## 🔧 Hardware

| Device                  | Count | OS Disk   | Data Disk  | RAM  | OS       | Purpose                |
|-------------------------|-------|-----------|------------|------|----------|------------------------|
| Protectli VP2410        | 1     | 1TB SSD   | -          | 16GB | OPNSense | Router                 |
| TP-Link SG2016P         | 1     | -         | -          | -    | -        | 1Gb PoE Switch         |
| Intel NUC11PAHi7        | 3     | 500GB SSD | 1TB NVMe   | 32GB | Talos    | Kubernetes Controllers |
| Custom Tower            | 1     | -         | 4x12TB HDD | 32GB | Debian   | NFS                    |
| ADJ PC-100A             | -     | -         | -          | -    | -        | PDU                    |
| CyberPower OR500LCDRM1U | -     | -         | -          | -    | -        | UPS                    |

## 🤝 Thanks

A huge thank you for all the maintainers of the dependencies used by this project as well as onedr0p for the awesome [cluster template](https://github.com/onedr0p/cluster-template) which was used to initially create this repo. If you'd like to get started with your own cluster be sure to check it out.
