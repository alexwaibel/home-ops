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

## Install NixOS

On the new target machine
1. Boot into nixos minimal using the latest [`nixos-installer-x86_64-linux.iso`](https://github.com/nix-community/nixos-images)
    - Note the IP and root password shown on the screen

On your local workstation (must be running Nix)
1. `nix-shell -p bitwarden-cli go-task`
1. `bw login`
1. `task nix:nas-install ip={TARGET_IP}` or `task nix:media-center-install ip={TARGET_IP}` depending which machine you're provisioning
1. Enter your bitwarden master password when prompted
1. Enter the Nix installer root password when prompted
1. Wait for the install to complete
1. On reboot, enter the encryption password manually. This must be done whenever the machine is rebooted
    - Via PiKVM for machines in the rack
    - SSH for things like `media-center` that are outside the rack
      ```shell
      ssh -p 2222 root@{TARGET_IP}
      ```

> [!IMPORTANT]  
> Something is wrong with copying hostKeys to initrd. To resolve this:
> 1. `ssh root@{TARGET_IP} "ssh-keygen -t ed25519 -N \"\" -f /etc/secrets/initrd/ssh_host_ed25519_key"` to create a new key
> 1. Uncomment `boot.initrd.secrets`
> 1. `task nix:rebuild ip={TARGET_IP} hostname={TARGET_HOSTNAME}` to reload the config and copy the new key to initrd

## Post Install

### Deploying Changes

Whenever changes are made to the nix config for a machine, you can apply the new config remotely

```sh
task nix:rebuild ip={TARGET_IP} hostname={TARGET_HOSTNAME}
```

### Media Center Machine Setup

#### Hyperion
1. Ensure USB devices for HDMI capture card and LED lights are plugged in
1. Download Hyperion config from Bitwarden
1. Navigate to `{MACHINE_IP}:8090`
1. In the Hyperion interface go to "General" and import the config
1. Set a password for the UI when prompted

#### BlueBubbles
1. Use `ssh root@{TARGET_IP} "passwd alex"` to set the alex user password then reboot the machine
1. SSH into the machine
1. `qemu-img create -f qcow2 maindisk.qcow2 128G`
1.  Do some first time setup
    ```
    docker run \
    -i \
    --name bluebubbles-setup \
    --dns=1.1.1.1 \
    --device /dev/kvm \
    -p 50922:10022 \
    -p 5999:5999 \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v $PWD/maindisk.qcow2:/image \
    -e GENERATE_UNIQUE=true \
    -e MASTER_PLIST_URL='https://raw.githubusercontent.com/sickcodes/osx-serial-generator/master/config-custom.plist' \
    -e SHORTNAME=ventura \
    -e IMAGE_PATH="/image" \
    -e "DISPLAY=${DISPLAY:-:0.0}" \
    -e EXTRA="-display none -vnc 0.0.0.0:99,password=on" \
    sickcodes/docker-osx:latest
    ```
1. In the terminal type `change vnc password` to set a VNC password
1. Log in to the machine, go to "Applications" > "Run Program" and type `vncviewer localhost:5999`
1. Select "Disk Utility"
1. Pick the larger of the `QEMU HARRDDISK Media` and select "Erase"
1. Fill in any drive name and click "Erase"
1. Close out and select "reinstall macOS"
1. Once booted up, send an iMessage to yourself to ensure everything works
1. `docker cp bluebubbles-setup:/home/arch/OSX-KVM/OpenCore/OpenCore.qcow2 ./bootdisk.qcow2`
1. `docker ps` then `docker stop {CONTAINER_ID}` and `docker rm {CONTAINER_ID}`
1. `sudo mv maindisk.qcow2 /home/bluebubbles/maindisk.qcow2 && sudo mv bootdisk.qcow2 /home/bluebubbles/bootdisk.qcow2`
1. Create a tunnel for the VNC connection with `ssh -N root@{TARGET_IP} -L  5999:127.0.0.1:5999`
1. Use a VNC client to connect to `localhost:5999` and download and install BlueBubbles.
    - Enable auto login in macos
    - In BlueBubbles settings, enable "Startup with MacOS"

### NAS Machine Setup

#### Data
1. Restore either a cloud backup with Kopia, or a local backup with rclone. Place data in the `/data` directory
1. `sudo chmod 770 /data`
1. `sudo chown -R alex:users /data`
