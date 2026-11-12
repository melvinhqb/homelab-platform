# M1 — Foundation

How the foundation of the lab was built: what was done at each step, what went wrong, and how it was fixed.

Real IPs, user names and hardware identifiers are replaced with placeholders (`10.0.0.x`, `admin`).

| # | Step | Highlights |
| --- | --- | --- |
| 1 | [Host and Proxmox installation](01-host-and-proxmox-install.md) | Wrong ISO architecture, SSD hidden by Intel RST, Wi-Fi vs USB Ethernet |
| 2 | [Proxmox hardening](02-proxmox-hardening.md) | Named admin + 2FA, SSH keys only, an unexpected key slipped in, nothing exposed (IPv4 and IPv6) |
| 3 | [Cloud-init template](03-cloud-init-template.md) | `latest` image missing, dated image + SHA512, a command chain that kept going after a failure |
| 4 | [VMs with Terraform](04-terraform-vms.md) | Least-privilege API token, saved plans, inventory generated from Terraform, IaC checks in CI |
| 5 | [k3s with Ansible](05-ansible-k3s.md) | Hardening role, pinned k3s, join token kept in memory, idempotent runs |
| 6 | [Full rebuild test](06-rebuild-test.md) | Destroy and rebuild in about two minutes; a race between Terraform and Ansible |

Decisions are recorded in the [ADRs](../../adr/), and the procedures in the [runbooks](../../runbooks/).