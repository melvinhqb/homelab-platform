# 6. Full rebuild test

## Goal

Prove the promise of the milestone: destroy everything and rebuild a working cluster from code, with no manual step.

## Procedure

```bash
source terraform/.env
terraform -chdir=terraform destroy
time terraform -chdir=terraform apply
make known-hosts-reset && make inventory && time make ansible
kubectl get nodes
```

These are the commands of the first test run, typed one after the other. Since then, `make destroy && make rebuild` chains the same steps in one command and also waits until every node is `Ready` (see the [README](../../../README.md#rebuild-the-cluster)).

## Problems and fixes

### A destroy that destroyed nothing

- **Symptom.** `terraform destroy` reported "No changes" and the next steps ran on the old VMs.
- **Cause.** It was run from the repository root, where there is no configuration and no state.
- **Fix.** Always use `terraform -chdir=terraform`, as the README and the Makefile do.

### Terraform waiting for an agent that did not exist yet

- **Risk.** With the guest agent enabled in Terraform but installed only by Ansible, new VMs would boot without it. The provider would then wait for it up to its 15-minute timeout.
- **Fix.** Baked `qemu-guest-agent` into the template with `virt-customize` (on a copy of the verified image, with `/etc/machine-id` truncated so each clone gets its own ID). The agent now answers at first boot, and Proxmox shows each VM's IP right away.

### A race between Terraform and Ansible

- **Symptom.** On the first rebuild, the playbook failed on one node: `connect to host ... port 22: Connection timed out`. Running it again worked.
- **Cause.** Terraform returns as soon as the VMs are started. Ansible started three seconds later, while cloud-init was still setting up the network, user and SSH key on one of them.
- **Fix.** The first play now starts with `wait_for_connection` (up to 5 minutes) and only then gathers facts.

## Results

| Step | Duration |
| --- | --- |
| `terraform destroy` | about 8 s |
| `terraform apply` (2 VMs) | about 25 s |
| `make ansible` (base hardening and k3s) | about 25 s once SSH is ready |

Both nodes come back `Ready`, with a fresh age, on the pinned k3s version.

### One-command rebuild

The same test was then run with the Makefile targets only:

```bash
make destroy && make rebuild
```

The only input was the two `yes` confirmations, one for `destroy` and one for `apply`. Everything else ran on its own:

- `terraform destroy`: both VMs removed in about 8 s.
- `terraform apply`: both VMs created from the template in about 22 s.
- `make known-hosts-reset`: the old host keys were removed, so SSH trusted the new VMs on first contact.
- The playbook: `wait_for_connection` succeeded at once, with no race this time, and the run ended with `failed=0` on both nodes.
- `kubectl wait`: both nodes `Ready`.

```
NAME           STATUS   ROLES           AGE   VERSION        INTERNAL-IP   OS-IMAGE                       CONTAINER-RUNTIME
k3s-agent-1    Ready    <none>          6s    v1.34.9+k3s1   10.0.0.21     Debian GNU/Linux 13 (trixie)   containerd://2.2.5-k3s2
k3s-server-1   Ready    control-plane   18s   v1.34.9+k3s1   10.0.0.11     Debian GNU/Linux 13 (trixie)   containerd://2.2.5-k3s2
```

IPs replaced with the placeholders of `hosts.yml.example`. The first exit criterion of the milestone is met with a single command.

## Lessons

- Only a real destroy-and-rebuild finds this kind of issue: it never shows up when re-running against machines that already exist.
- "Started" is not "ready": automation chained after provisioning has to wait for the service it needs.
- Rebuilt VMs get new SSH host keys. `accept-new` plus `make known-hosts-reset` handles this without turning host key checking off.