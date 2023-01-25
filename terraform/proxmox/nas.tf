resource "proxmox_vm_qemu" "nas" {
  name        = "nas"
  desc        = "Debian NAS"
  target_node = var.proxmox_node
  vmid        = 800

  clone   = "debian-cloudinit"
  os_type = "cloud-init"
  boot    = "c"

  agent     = 1
  ipconfig0 = "ip=${var.nas_ip_address}/24,gw=192.168.20.1"
  sshkeys   = file(var.ssh_public_key)

  cores  = 2
  memory = 8192

  network {
    bridge    = "vmbr0"
    firewall  = false
    link_down = false
    macaddr   = "C6:3D:90:63:41:A6"
    model     = "virtio"
    tag       = 20
  }

  usb {
    host = "10c4:8a2a"
  }

  usb {
    host = "1a86:7523"
  }

  usb {
    host = "534d:2109"
  }

  usb {
    host = "10c4:ea60"
  }
}
