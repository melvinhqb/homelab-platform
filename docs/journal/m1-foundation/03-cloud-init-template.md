# 3. Cloud-init template

## Goal

Build one VM template that every VM is cloned from, so creating a VM takes seconds instead of a manual OS install.

## What was done

- Debian 13 cloud image, **dated release** (`debian-13-generic-amd64-20261111-2659`), checked with the published `SHA512SUMS`.
- VM 9000 created with a VirtIO SCSI disk, a cloud-init drive, a serial console and the QEMU guest agent channel, then converted to a template.
- A test clone validated the whole chain: hostname, static IP, user with SSH key, disk grown from 3 GB at first boot, passwordless `sudo`.
- Later, the **QEMU guest agent was baked into the image** with `virt-customize` (see [step 6](06-rebuild-test.md) for why).

The full procedure is in the [runbook](../../runbooks/template-cloud-init.md).

## Problems and fixes

### The `latest` image returned 404

- **Symptom.** `wget .../trixie/latest/debian-13-genericcloud-amd64.qcow2` failed with **404 Not Found**.
- **Investigation.** Listed what really existed with `curl` + `grep` instead of guessing URLs. The newest dated folder only had the `generic` image, not `genericcloud`.
- **Fix.** Used the dated `generic` image. It also ships cloud-init and works the same for VMs, with a few more hardware drivers.

### A command chain that kept going after a failure

- **Symptom.** The template commands were pasted as one block. After the `wget` failed, the next commands still ran and created VM 9000 **without a system disk** (`no such logical volume`, `invalid bootorder`).
- **Fix.** Destroyed the broken VM (`qm destroy 9000 --purge`) and rebuilt it step by step, with the configuration commands chained by `&&` and a `qm config` check before `qm template`.

## Lessons

- **Never `latest`.** A dated image always gives the same result, like a pinned Docker tag or a Terraform lock file. Updating it becomes an explicit change.
- **Verify integrity** of every downloaded image.
- **Stop at the first error**: one command at a time, `&&` chains, or `set -e` in scripts.
- **Check before freezing**: a template is meant to stay unchanged.

## Result

Template 9000 produces ready-to-use VMs in a few seconds, configured entirely by cloud-init.