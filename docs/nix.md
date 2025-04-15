# Nix

I use NixOS for my non-kubernetes machines, allowing me to easily rebuild them if needed.

## Machines

### NAS

Used for large file storage. Drives are running ZFS in two mirror vdevs which provides redundancy at the cost of usable storage size

#### Hardware

- Motherboard: [Topton N150 Mini ITX NAS Motherboard](https://www.aliexpress.us/item/3256807243287509.html)
- CPU: [Intel N150](https://www.intel.com/content/www/us/en/products/sku/241636/intel-processor-n150-6m-cache-up-to-3-60-ghz/specifications.html)
- Boot Drive: [Crucial P3 1TB M.2 SSD](https://www.crucial.com/ssd/p3/ct1000p3ssd8)
- Hard Drives: 4x12 TB Western Digital WD120EDAZ-11F3RA0
- PSU: [Corsair SF450 Gold](https://www.corsair.com/us/en/p/psu/cp-9020104-na/sf-series-sf450-450-watt-80-plus-gold-certified-high-performance-sfx-psu-cp-9020104-na)
- Chassis: [Sliger CX3702 Short-depth 10 Bay NAS](https://sliger.com/products/rackmount/storage/cx3702/)

### Media Center

Used for a few random services I don't have a good alternative for:
- [hyperion.ng](https://github.com/hyperion-project/hyperion.ng) since it needs access to the USB capture card attached to the TV
- [BlueBubbles](https://bluebubbles.app/) since it needs to run a full macOS VM.

#### Hardware

- [Beelink MINI S12 N100](https://www.bee-link.com/products/beelink-mini-s12-pro-n100)

## Setup

On the new target machine
1. Boot into nixos minimal using the latest [`nixos-installer-x86_64-linux.iso`](https://github.com/nix-community/nixos-images)
    - Note the IP and root password shown on the screen

On your local workstation (must be running Nix)
1. `nix-shell -p bitwarden-cli go-task`
1. `bw login`
1. `task nix:nas-install ip={TARGET_IP}` or `task nix:media-center-install ip={TARGET_IP}` depending which machine you're provisioning
1. Enter your bitwarden master password when prompted
1. Enter the Nix installer root password when prompted
1. Wait for the install to complete.
1. On reboot, enter the encryption password. You must manually enter this (via PiKVM on NAS and SSH on media center) every time the machine reboots

> [!IMPORTANT]  
> Something is wrong with copying hostKeys to initrd. To resolve this:
> 1. `ssh root@{TARGET_IP} "ssh-keygen -t ed25519 -N \"\" -f /etc/secrets/initrd/ssh_host_ed25519_key"` to create a new key
> 1. Uncomment `boot.initrd.secrets`
> 1. `task nix:deploy-config ip={TARGET_IP} hostname={TARGET_HOSTNAME}` to reload the config and copy the new key to initrd

## Deploying Changes

Whenever changes are made to the nix config for a machine, you can apply the new config remotely

```sh
task nix:deploy-config ip={TARGET_IP} hostname={TARGET_HOSTNAME}
```
