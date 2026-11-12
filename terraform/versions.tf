terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }

  # Local state for now (ignored by Git).
  # It will be migrated to an S3-compatible backend (MinIO) later.
}
