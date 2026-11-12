# 5. k3s with Ansible

## Goal

Configure the VMs created by Terraform and turn them into a working Kubernetes cluster.

## What was done

- **`base` role** (all nodes): package upgrades, automatic security updates, `qemu-guest-agent`, and SSH hardening (no passwords, no root login). The SSH configuration is validated with `sshd -t` before it is applied.
- **`k3s_server` role**: installs k3s **v1.34.9+k3s1** (pinned, never `latest`) with the official script, which checks the binary's SHA256. Reads the join token **in memory only**, with `no_log`, and copies the kubeconfig to the workstation, outside the repository.
- **`k3s_agent` role**: joins the server with that token.
- **`ansible.cfg`**: `StrictHostKeyChecking=accept-new`, which trusts a new host but still refuses a host whose key **changed**.
- **CI**: `ansible-lint` on every pull request, passing the strictest `production` profile.

## Problems and fixes

### The guest agent: a chicken-and-egg problem

- **Issue.** Terraform waits for the QEMU guest agent when it is enabled, but the agent was only installed later, by Ansible.
- **First step.** The agent was disabled in Terraform, installed by Ansible, then enabled in Terraform.
- **Final fix.** The agent was baked into the template itself (see [step 6](06-rebuild-test.md)), so it answers from the very first boot.

### A role running another role's tasks

- **Symptom.** `object of type 'HostVarsVars' has no attribute 'k3s_server_token'`, raised by an "Install the k3s agent" task running on the server.
- **Cause.** The task files of the two roles had been swapped when they were copied into place: both are named `main.yml`.
- **Fix.** Put each file back in its role. The error's **origin** (file and line) pointed straight at the problem.

## Lessons

- Runtime secrets (the join token) stay in memory and out of logs.
- Idempotent tasks (`creates:`, declarative modules) make an interrupted playbook safe to run again. A second run on a configured cluster reports `changed=0` everywhere.
- Host firewall rules are left for later on purpose: badly set, they easily break Kubernetes networking (Flannel, ports 6443 and 10250).

## Result

`make ansible` turns two blank VMs into a k3s cluster, and `kubectl get nodes` from the workstation shows both nodes `Ready`.