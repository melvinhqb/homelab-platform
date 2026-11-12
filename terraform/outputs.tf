output "vms" {
  description = "Role and IP address of each VM"
  value = {
    for name, vm in var.vms : name => {
      role = vm.role
      ip   = vm.ip
    }
  }
}

# Ansible inventory generated from the same source of truth as the VMs.
# It holds the real IPs and user name, so the result is git-ignored.
# Usage (from the repo root): make inventory
output "ansible_inventory" {
  description = "Ansible inventory (YAML) for the k3s cluster"
  value = yamlencode({
    all = {
      vars = {
        ansible_user = var.vm_user
      }
      children = {
        k3s_cluster = {
          children = {
            server = {
              hosts = {
                for name, vm in var.vms : name => { ansible_host = vm.ip }
                if vm.role == "server"
              }
            }
            agent = {
              hosts = {
                for name, vm in var.vms : name => { ansible_host = vm.ip }
                if vm.role == "agent"
              }
            }
          }
        }
      }
    }
  })
}
