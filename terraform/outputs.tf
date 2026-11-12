output "vms" {
  description = "Role and IP address of each VM"
  value = {
    for name, vm in var.vms : name => {
      role = vm.role
      ip   = vm.ip
    }
  }
}
