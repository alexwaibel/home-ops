variable "proxmox_ip" {
  type        = string
  description = "The IP of the proxmox server."
}

variable "proxmox_port" {
  type        = string
  description = "The port used by the proxmox management interface."
  default     = "8006"
}

variable "proxmox_username" {
  type        = string
  description = "The user used to connect to proxmox."
}

variable "proxmox_password" {
  type        = string
  description = "The password for the proxmox user."
  sensitive   = true
}

variable "proxmox_node" {
  type        = string
  description = "The name of the proxmox node."
}

variable "proxmox_disk_storage_pool" {
  type        = string
  description = "The name of the proxmox storage pool to store disks in."
  default     = "local-zfs"
}

variable "ssh_public_key" {
  description = "The location of the SSH public key."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "nas_ip_address" {
  type        = string
  description = "The IP of the NAS host."
}
