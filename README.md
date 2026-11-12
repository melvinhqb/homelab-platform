# homelab-platform

A self-hosted DevSecOps platform, fully described as code.

## Goal

Build from scratch a platform that deploys an application in an **automated**, **secure** and **observable** way. Everything is code: the whole platform can be destroyed and rebuilt with a single command.

This repository holds the **infrastructure and deployments**. The application it runs, [VulnWatch](https://github.com/<your-account>/vulnwatch), lives in its own repository: a vulnerability monitoring service that analyzes project SBOMs and flags components affected by CVEs.

## Stack

- **Hypervisor**: Proxmox VE on a physical server
- **Provisioning**: Terraform (Proxmox VMs, Cloudflare DNS)
- **Configuration**: Ansible (hardening, k3s installation)
- **Orchestration**: k3s
- **Delivery**: GitOps with ArgoCD, Helm and Kustomize
- **Observability**: Prometheus, Grafana, Loki, Alertmanager
- **Security**: SOPS, Kyverno, Trivy, cert-manager, IaC scanning in CI
- **Exposure**: Cloudflare Tunnel, no open ports

## Roadmap

| Milestone | Scope | Status |
| --- | --- | --- |
| M1 — Foundation | Proxmox, VMs with Terraform, k3s with Ansible | In progress |
| M2 — Local app | VulnWatch MVP | To do |
| M3 — Supply chain | Image scanning, SBOM, signing | To do |
| M4 — GitOps | Staging and production deployments with ArgoCD | To do |
| M5 — Observability | Metrics, logs, alerting | To do |
| M6 — Platform security | Policies, encrypted secrets, TLS | To do |
| M7 — Reliability | Tested backups, runbooks, postmortems | To do |

## Repository layout

```
terraform/      Proxmox VMs, Cloudflare DNS
ansible/        VM hardening, k3s installation
platform/       ArgoCD, monitoring, security, databases
apps/           application deployments (staging, production)
docs/
├── adr/        architecture decision records
├── runbooks/   operational procedures
└── postmortems/ real incidents and lessons learned
```
