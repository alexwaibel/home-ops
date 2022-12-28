source "proxmox" "debian_cloudinit" {
  proxmox_url              = "https://${var.proxmox_ip}:${var.proxmox_port}/api2/json"
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  node                     = var.proxmox_node
  iso_url                  = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.6.0-amd64-netinst.iso"
  iso_storage_pool         = var.proxmox_iso_storage_pool
  iso_checksum             = "sha512:224cd98011b9184e49f858a46096c6ff4894adff8945ce89b194541afdfd93b73b4666b0705234bd4dff42c0a914fdb6037dd0982efb5813e8a553d8e92e6f51"
  insecure_skip_tls_verify = true

  cloud_init              = true
  cloud_init_storage_pool = "local-zfs"
  disks {
    disk_size         = "200G"
    storage_pool      = "local-zfs"
    storage_pool_type = "zfspool"
  }
  memory = 2048
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    vlan_tag = "20"
  }
  onboot           = true
  qemu_agent       = true
  scsi_controller  = "virtio-scsi-pci"
  ssh_username     = "debian"
  ssh_password     = "packer"
  ssh_wait_timeout = "10000s"
  template_name    = "debian-cloudinit"
  unmount_iso      = true
  vm_name          = "provisioning-debian-template"
  vm_id            = 9000

  boot_command = [
    "<esc><wait>",
    "auto",
    "<spacebar>",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg",
    "<enter>"
  ]
  boot_wait = "10s"
  # Needed for WSL
  http_port_max = 8336
  http_port_min = 8336
  http_content = {
    "/preseed.cfg" = templatefile("${path.root}../../../packer/templates/debian-preseed.pkrtpl.hcl", { domain = var.domain })
  }
}

build {
  sources = ["source.proxmox.debian_cloudinit"]
}
