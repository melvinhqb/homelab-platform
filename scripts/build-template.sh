#!/usr/bin/env bash
# Build the Debian cloud-init template used by Terraform to clone the k3s VMs.
# Automates the "Build the template" steps of docs/runbooks/template-cloud-init.md.
#
# Run it as root on the Proxmox node. From your workstation, without copying it:
#   ssh root@<proxmox-host> 'bash -s' < scripts/build-template.sh
# Override a default by passing variables before `bash`:
#   ssh root@<proxmox-host> 'VMID=9001 bash -s' < scripts/build-template.sh
set -euo pipefail

# --- Settings (keep them in sync with terraform/variables.tf) ---------------
RELEASE="${RELEASE:-20261111-2659}"            # dated Debian release, never "latest"
VMID="${VMID:-9000}"                            # = template_id
NAME="${NAME:-debian13-cloudinit}"
STORAGE="${STORAGE:-local-lvm}"                 # = datastore
BRIDGE="${BRIDGE:-vmbr0}"                       # = bridge
WORKDIR="${WORKDIR:-/var/lib/vz/template/build}"

IMAGE="debian-13-generic-amd64-${RELEASE}.qcow2"
BASE_URL="https://cloud.debian.org/images/cloud/trixie/${RELEASE}"
CUSTOM_IMAGE="debian13-agent-${RELEASE}.qcow2"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# --- Pre-flight checks -------------------------------------------------------
[[ $EUID -eq 0 ]] || die "run as root on the Proxmox node"
command -v qm >/dev/null || die "qm not found: this is not a Proxmox node"
if qm status "$VMID" >/dev/null 2>&1; then
  die "VM $VMID already exists. Destroy it first if you want to rebuild it: qm destroy $VMID"
fi

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# --- 1. Download the image and verify its integrity -------------------------
log "1/5 Download $IMAGE and verify its SHA512 checksum"
[[ -f "$IMAGE" ]] || wget -q --show-progress "$BASE_URL/$IMAGE"
wget -q -O SHA512SUMS "$BASE_URL/SHA512SUMS"
# Always re-check, even when the image was already downloaded.
sha512sum -c SHA512SUMS --ignore-missing --quiet || die "checksum mismatch: delete $WORKDIR/$IMAGE and retry"

# --- 2. Add the QEMU guest agent to the image -------------------------------
log "2/5 Install qemu-guest-agent in a copy of the image"
command -v virt-customize >/dev/null || apt-get install -y libguestfs-tools
cp -f "$IMAGE" "$CUSTOM_IMAGE"   # the verified original stays untouched
virt-customize -a "$CUSTOM_IMAGE" --install qemu-guest-agent --truncate /etc/machine-id

# --- 3. Create the base VM and import the disk ------------------------------
log "3/5 Create VM $VMID and import the disk into $STORAGE"
qm create "$VMID" --name "$NAME" --memory 2048 --cores 2 --net0 "virtio,bridge=$BRIDGE"
qm disk import "$VMID" "$CUSTOM_IMAGE" "$STORAGE"

# The import is attached as an unused disk; read its volume name instead of guessing it.
DISK="$(qm config "$VMID" | sed -n 's/^unused0: //p')"
[[ -n "$DISK" ]] || die "imported disk not found in the configuration of VM $VMID"

# --- 4. Configure the hardware ----------------------------------------------
log "4/5 Configure the hardware"
qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$DISK"
qm set "$VMID" --ide2 "$STORAGE:cloudinit"
qm set "$VMID" --boot order=scsi0
qm set "$VMID" --serial0 socket --vga serial0
qm set "$VMID" --agent enabled=1

# --- 5. Check, then convert to a template -----------------------------------
log "5/5 Check the configuration, then convert to a template"
CONFIG="$(qm config "$VMID")"
grep -q "^scsi0: $DISK" <<<"$CONFIG"      || die "scsi0 is not the imported disk"
grep -q '^ide2: .*cloudinit' <<<"$CONFIG" || die "cloud-init drive missing"
grep -q '^boot: order=scsi0' <<<"$CONFIG" || die "boot order is not scsi0"
grep -Eq '^agent: (enabled=)?1' <<<"$CONFIG" || die "guest agent is not enabled"

qm template "$VMID"
rm -f "$CUSTOM_IMAGE"

log "Template $VMID ($NAME) is ready. Test a clone: see docs/runbooks/template-cloud-init.md"
