# 4. VMs with Terraform

## Goal

Create the cluster VMs from code, with no manual step in the Proxmox UI.

## What was done

- **Dedicated identity.** A `terraform@pve` user with a custom `Terraform` role (VM, datastore and SDN privileges only) and an API token. The secret is passed through environment variables, loaded from a git-ignored `.env` file (`chmod 600`), and never written in the code.
- **Tooling on the workstation.** Terraform runs on the workstation, not on the hypervisor, which stays minimal.
- **Code.** Provider `bpg/proxmox` pinned and locked (`.terraform.lock.hcl`). One `proxmox_virtual_environment_vm` resource with `for_each` over a `vms` map: `k3s-server-1` (2 vCPU, 2 GB, 40 GB) and `k3s-agent-1` (4 vCPU, 4 GB, 120 GB). Real values live in a git-ignored `terraform.tfvars`, with a committed `.example`.
- **Workflow.** While building the VMs: `plan` reviewed, then `plan -out=tfplan` and `apply tfplan`, so what is applied is exactly what was reviewed. For rebuilds, `make rebuild` runs `terraform apply` directly: it prints the plan and waits for `yes` before changing anything (`AUTO_APPROVE=1` skips the prompt).
- **Single source of truth.** An `ansible_inventory` output builds the Ansible inventory from the same `vms` map (`make inventory`). The generated file is git-ignored because it holds real IPs.
- **CI.** On every pull request: `terraform fmt`, `validate`, `tflint` and a Checkov scan, with `contents: read` permissions and no secrets. Dependabot keeps the actions and the provider up to date.

## Problems and fixes

### `403 Permission check failed (VM.GuestAgent.Audit)`

- **Symptom.** Once the QEMU guest agent was enabled, Terraform warned that it could not read the VMs' network interfaces.
- **Cause.** Proxmox 9 requires `VM.GuestAgent.Audit` to query the guest agent, and the role did not have it.
- **Fix.** Added exactly that privilege, nothing more: `pveum role modify Terraform --append 1 --privs VM.GuestAgent.Audit`.

### A linter script that returned an error page

- **Symptom.** `curl ... install_linux.sh | bash` printed `bash: 404:: command not found`.
- **Cause.** The script URL had moved. `curl` saved GitHub's error page and `bash` tried to run it.
- **Fix.** Installed `tflint` from its release archive with `curl -f`, after checking it against `checksums.txt`.

### A linter config that was silently ignored

- **Cause.** The file was named `tflint.hcl`. tflint only reads `.tflint.hcl` and fell back to its defaults without warning.
- **Fix.** Renamed it to `.tflint.hcl`.

## Lessons

- One identity per tool, with the smallest role that works, and privileges added only when an error proves they are needed.
- No secret in the code or in Git history: environment variables and git-ignored local files.
- Avoid `curl | bash`: download, verify the checksum, then install.
- A CI that only checks code needs no credentials, and its permissions should be read-only.

## Result

`terraform apply` creates both VMs from the template in about 25 seconds, and the Ansible inventory is generated from the same data.