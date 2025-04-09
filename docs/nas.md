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
1. Boot into nixos minimal iso
1. Set a password with `passwd`
1. Determine machine's IP with `ip addr`
1. Confirm you can ssh into the machine with `ssh -v nixos@{TARGET_IP}`

On your local workstation
1. `git clone https://github.com/alexwaibel/home-ops.git`
1. `cd home-ops`
1. `nix run github:nix-community/nixos-anywhere -- --flake './nix#nix-nas' --generate-hardware-config nixos-facter facter.json --target-host nixos@{TARGET_IP}`
