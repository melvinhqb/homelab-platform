variable "proxmox_node" {
  description = "Name of the Proxmox node"
  type        = string
  default     = "pve"
}

variable "template_id" {
  description = "VM ID of the cloud-init template to clone"
  type        = number
  default     = 9000
}

variable "datastore" {
  description = "Storage used for VM disks and cloud-init drives"
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge the VMs are attached to"
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "Default gateway of the LAN (also used as DNS server)"
  type        = string
}

variable "network_prefix" {
  description = "CIDR prefix length of the LAN"
  type        = number
  default     = 24
}

variable "vm_user" {
  description = "User created by cloud-init in every VM"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key authorized for vm_user"
  type        = string
}

variable "vms" {
  description = "VMs of the k3s cluster, keyed by hostname"
  type = map(object({
    vm_id     = number
    ip        = string
    cores     = number
    memory_mb = number
    disk_gb   = number
    role      = string
  }))
}
