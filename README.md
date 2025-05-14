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

| Device                       | Count | OS Disk   | Data Disk  | RAM  | OS       | Purpose                |
|------------------------------|-------|-----------|------------|------|----------|------------------------|
| Protectli VP2410             | 1     | 1TB SSD   | -          | 16GB | OPNSense | Router                 |
| TP-Link SG2016P              | 1     | -         | -          | -    | -        | 1Gb PoE Switch         |
| PiKVM V4 Plus + PiKVM Switch | 1     | 32GB SD   | -          | 4GB  | PiKVM    | KVM                    |
| Intel NUC11PAHi7             | 3     | 500GB SSD | 1TB NVMe   | 32GB | Talos    | Kubernetes Controllers |
| Custom NAS                   | 1     | 1TB NVMe  | 4x12TB HDD | 32GB | NixOS    | NFS                    |
| ADJ PC-100A                  | -     | -         | -          | -    | -        | PDU                    |
| CyberPower OR500LCDRM1U      | -     | -         | -          | -    | -        | UPS                    |

## ☁️ Cloud Dependencies

I try to self-host as much of my infrastructure as possible, but there are some instances where I opt to rely on cloud services. I do this primarily for scenarios such as secrets management and uptime alerting that need to be available whether or not the cluster is online. All backups to public cloud storage are encrypted.

| Service                                    | Use                                                               | Cost           |
|--------------------------------------------|-------------------------------------------------------------------|----------------|
| [Backblaze B2](https://www.backblaze.com/) | Backups                                                           | ~$100/yr       |
| [Bitwarden](https://bitwarden.com/)        | Secrets with [External Secrets](https://external-secrets.io/)     | $10/yr         |
| [Cloudflare](https://www.cloudflare.com/)  | Domain and tunnel                                                 | ~$30/yr        |
| [GCP](https://cloud.google.com/)           | Voice interactions with Home Assistant over Google Assistant      | Free           |
| [GitHub](https://github.com/)              | Hosting this repository and continuous integration/deployments    | Free           |
| [Google Drive](https://drive.google.com/)  | OPNsense backups                                                  | Free           |
| [Healthchecks](https://healthchecks.io/)   | Monitoring internet connectivity and external facing applications | Free           |
| [Migadu](https://migadu.com/)              | Email hosting                                                     | ~$20/yr        |
| [Pushover](https://pushover.net/)          | Kubernetes Alerts and application notifications                   | $5 OTP         |
|                                            |                                                                   | Total: ~$15/mo |

## 🤝 Thanks

A huge thank you for all the maintainers of the dependencies used by this project as well as onedr0p for the awesome [cluster template](https://github.com/onedr0p/cluster-template) which was used to initially create this repo. If you'd like to get started with your own cluster be sure to check it out.
