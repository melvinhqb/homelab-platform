# ADR 0001: Proxmox VE as hypervisor and k3s as Kubernetes distribution

- **Status**: Accepted
- **Date**: 2026-11-12

## Context

The lab needs a platform that can be destroyed and rebuilt from code, on a single old laptop: Intel Core i5-8265U (4 cores, 8 threads), 8 GB of RAM, 512 GB NVMe SSD, Ethernet through a USB adapter.

Requirements:

- Run several isolated machines, to get a real multi-node Kubernetes cluster.
- Create those machines from code (Terraform), through an API.
- Stay close to what companies run, to make the lab relevant.
- Leave as much RAM as possible to the workloads: 8 GB is the main constraint.
- No licence cost.

Memory budget: the two VMs get 6 GB (2 GB for the k3s server, 4 GB for the agent), which leaves about 2 GB for the hypervisor itself. Proxmox VE alone already uses roughly 1 to 1.5 GB, so there is little headroom.

A public cloud free tier was tried first, but its free instances were not available ("out of capacity").

## Decision

### Hypervisor: Proxmox VE

Proxmox VE is installed directly on the laptop.

- It is free, based on Debian, and runs KVM virtual machines.
- It has a full REST API and a maintained Terraform provider (`bpg/proxmox`).
- It supports cloud-init templates, which turn VM creation into a fast, repeatable clone.
- It is widely used in homelabs, small businesses and labs, and its concepts (VMs, storage, bridges, templates, API tokens) carry over to VMware or OpenStack.

### Kubernetes: k3s

k3s runs on two VMs: one server, one agent.

- It is a certified Kubernetes distribution, so manifests, Helm charts and `kubectl` work as on any cluster.
- It ships as a single binary and needs far less memory than a kubeadm cluster, which matters with 8 GB on the host.
- It bundles what a small cluster needs (containerd, Flannel, CoreDNS, Traefik, local-path storage, metrics-server).
- Its version can be pinned, and installation is easy to automate with Ansible.

## Alternatives considered

| Option | Why it was not chosen |
| --- | --- |
| Public cloud (Oracle free tier, AWS, GCP) | Free capacity not available; ongoing cost and dependency on credits. Kept as an option for a later module. |
| Docker or Kubernetes directly on the host OS | No VM layer: nothing for Terraform to provision, and a single machine as the only node. |
| kind or minikube | Multi-node is possible, but the nodes are containers or local VMs on one machine: there is no real OS, network or provisioning layer to manage as code. Meant for development, not for running a platform. |
| VirtualBox or VMware Workstation | Desktop hypervisors: weaker API, poorer Terraform support, not meant to run as a server. |
| kubeadm (upstream Kubernetes) | More components to run and more memory used; too heavy for 8 GB. |
| MicroK8s, k0s | Valid lightweight options. k3s was chosen for its documentation, its adoption in homelabs and edge setups, and its simple Ansible automation. |
| Talos Linux | A strong fit for "rebuild from code": an immutable OS managed only through its API. But it replaces the general-purpose OS and Ansible with its own tooling (`talosctl`, no SSH), so OS hardening and configuration management, which this lab also aims to practise, would be out of scope. Worth revisiting later. |

## Consequences

- **Positive**: the whole stack (VMs, cluster) is created from code and can be rebuilt; the skills apply to production environments; the RAM footprint stays low. The laptop battery also acts as a small UPS during short power cuts.
- **Negative**:
  - A single physical host means no real high availability.
  - With a single server, k3s stores the cluster state in SQLite instead of etcd: the control plane is a single point of failure, unlike a production cluster with three etcd-backed servers.
  - A laptop is not server hardware: automatic power-on is not verified, cooling is limited, the network goes through a USB adapter, and a battery that stays plugged in all the time can wear out or swell. Suspend on lid close must be disabled.
- **Follow-up**:
  - With 8 GB, every pod needs memory limits, and the RAM usage will be measured during the observability milestone.
  - k3s installs Traefik and ServiceLB by default. Exposure is planned through Cloudflare Tunnel, so they may be disabled when that milestone is reached.
  - Upgrading to 12 GB would allow a third VM, declared with one more entry in Terraform.