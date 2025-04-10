# NAS

## Hardware
- Motherboard: [Topton Mini ITX NAS Motherboard](https://www.aliexpress.us/item/3256807243287509.html)
- CPU: [Intel N150](https://www.intel.com/content/www/us/en/products/sku/241636/intel-processor-n150-6m-cache-up-to-3-60-ghz/specifications.html)
- Boot Drive: [Crucial P3 1TB M.2 SSD](https://www.crucial.com/ssd/p3/ct1000p3ssd8)
- Hard Drives: 4x12 TB WD HDD
- PSU: [Corsair SF450 Gold](https://www.corsair.com/us/en/p/psu/cp-9020104-na/sf-series-sf450-450-watt-80-plus-gold-certified-high-performance-sfx-psu-cp-9020104-na)
- Chassis: [Sliger CX3702 Short-depth 10 Bay NAS](https://sliger.com/products/rackmount/storage/cx3702/)

## Setup
On the new target machine
1. Boot into nixos minimal using the latest [`nixos-installer-x86_64-linux.iso`](https://github.com/nix-community/nixos-images)
    - Note the IP and root password shown on the screen

On your local workstation (must be running Nix)
1. `nix-shell -p bitwarden-cli go-task`
1. `bw login`
1. `task nix:nas-install ip={TARGET_IP}`
1. Enter your bitwarden master password when prompted
1. Enter the Nix installer root password when prompted
1. Wait for the install to complete.
1. On reboot, enter the encryption password. You must manually enter this every time the NAS reboots