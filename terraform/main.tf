resource "proxmox_virtual_environment_vm" "k3s" {
  for_each = var.vms

  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vm_id
  tags      = ["k3s", each.value.role, "terraform"]

  clone {
    vm_id = var.template_id
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  disk {
    datastore_id = var.datastore
    interface    = "scsi0"
    size         = each.value.disk_gb
  }

  network_device {
    bridge = var.bridge
  }

  serial_device {}

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.datastore

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network_prefix}"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.gateway]
    }

    user_account {
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }
  }
}
