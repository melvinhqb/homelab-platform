# Credentials are never written here. Export them before running Terraform:
#   export PROXMOX_VE_ENDPOINT="https://<proxmox-ip>:8006/"
#   export PROXMOX_VE_API_TOKEN="terraform@pve!provider=<secret>"
provider "proxmox" {
  # The Proxmox host still uses its self-signed certificate.
  insecure = true

  # A few provider operations go through SSH on the node.
  # It uses your local ssh-agent and the root key already authorized on Proxmox.
  ssh {
    agent    = true
    username = "root"
  }
}
