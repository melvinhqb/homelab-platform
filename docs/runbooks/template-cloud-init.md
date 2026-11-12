# Cloud-init template

Base for all VMs. Run on the Proxmox node, over SSH.

Selected image: **debian-13-generic-amd64-20261111-2659**. It is a dated release, never `latest`, so builds are reproducible. The `genericcloud` variant was not published for this release.

## Placeholders

| Placeholder       | Meaning                                              | Example          |
|-------------------|------------------------------------------------------|------------------|
| `<USER>`          | Default user created by cloud-init                   | `admin`          |
| `<KEY_COMMENT>`   | Comment identifying your key in `authorized_keys`    | `workstation`    |
| `<VM_IP>`         | Static IP of the test clone                          | `10.0.0.210`     |
| `<CIDR>`          | Subnet prefix length                                 | `24`             |
| `<GATEWAY>`       | Default gateway                                      | `10.0.0.1`       |
| `<DNS>`           | DNS server                                           | `10.0.0.1`       |

## Build the template

### 1. Download the image and verify its integrity

```bash
wget https://cloud.debian.org/images/cloud/trixie/20261111-2659/debian-13-generic-amd64-20261111-2659.qcow2
wget -O SHA512SUMS https://cloud.debian.org/images/cloud/trixie/20261111-2659/SHA512SUMS
sha512sum -c SHA512SUMS --ignore-missing
```

- The first `wget` downloads the Debian cloud image in qcow2 format. It is a ready-to-boot disk with cloud-init preinstalled.
- The second `wget` downloads the checksum file published for the same release. `-O` names it `SHA512SUMS`, so an older copy in the directory is overwritten instead of being saved as `SHA512SUMS.1`.
- `sha512sum -c` hashes the image and compares it with the published checksum. `--ignore-missing` skips the other images listed in the file that were not downloaded. The expected output is `...qcow2: OK`. Anything else means a corrupted or tampered download: delete it and start over.

### 2. Create the base VM and import the disk

```bash
qm create 9000 --name debian13-cloudinit --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm disk import 9000 debian-13-generic-amd64-20261111-2659.qcow2 local-lvm
```

- `qm create` creates an empty VM shell with ID 9000. A high ID keeps templates apart from regular VMs. It gets 2 GiB of RAM, 2 vCPUs and a VirtIO network card on bridge `vmbr0`. These are only defaults: each clone can override them.
- `qm disk import` converts the qcow2 image and copies it into the `local-lvm` storage. The disk is attached to VM 9000 as an *unused* disk, named `vm-9000-disk-0`. Step 3 attaches it.

### 3. Configure the hardware

```bash
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0 \
  && qm set 9000 --ide2 local-lvm:cloudinit \
  && qm set 9000 --boot order=scsi0 \
  && qm set 9000 --serial0 socket --vga serial0 \
  && qm set 9000 --agent enabled=1
```

The commands are chained with `&&`, so the chain stops at the first error instead of leaving a half-configured VM.

- `--scsihw virtio-scsi-pci --scsi0 ...`: picks the paravirtualized VirtIO SCSI controller, which performs well, and attaches the imported disk as `scsi0`.
- `--ide2 local-lvm:cloudinit`: adds the cloud-init drive. Proxmox writes the user, SSH keys and network settings to this small virtual CD-ROM, and cloud-init reads them at first boot.
- `--boot order=scsi0`: boots only from the system disk, never from the network or the cloud-init drive.
- `--serial0 socket --vga serial0`: adds a serial port and uses it as the display. Debian cloud images send their console to the serial port, so without this the Proxmox console stays blank.
- `--agent enabled=1`: enables the QEMU guest agent channel. Proxmox can then read the VM's IP addresses and shut it down cleanly. The `qemu-guest-agent` package must also be installed in the guest.

### 4. Check, then convert to a template

```bash
qm config 9000
qm template 9000
```

- `qm config` prints the VM configuration. Before going further, check that `scsi0` points to `vm-9000-disk-0`, that `ide2` is the `cloudinit` drive, and that `boot: order=scsi0` is there.
- `qm template` converts the VM to a read-only template. You can no longer start it, only clone it. On LVM-thin, the disk is renamed `base-9000-disk-0`. **This cannot be undone.** If something is wrong, destroy the template and rebuild it.

## Test a clone

Check that a VM cloned from the template boots and applies its cloud-init settings.

```bash
grep <KEY_COMMENT> /etc/pve/priv/authorized_keys > /root/<USER>.pub
```

Takes your workstation's public key out of the keys already authorized on the cluster and saves it to a file. `--sshkeys` expects a file path, not the key itself.

```bash
qm clone 9000 100 --name test-clone --full
```

Creates VM 100 from the template. `--full` makes an independent copy of the disk. A linked clone would stay tied to the template's disk.

```bash
qm set 100 --ciuser <USER> --sshkeys /root/<USER>.pub \
  --ipconfig0 ip=<VM_IP>/<CIDR>,gw=<GATEWAY> --nameserver <DNS>
```

Sets the clone's cloud-init settings: the default user to create, the SSH key allowed to log in as that user, a static IP with its gateway for `net0`, and the DNS server. No password is set, so SSH key login is the only way in.

```bash
qm resize 100 scsi0 +5G
```

Grows the disk by 5 GiB, because the cloud image is very small (about 3 GiB). At first boot, cloud-init (`growpart`) extends the partition and the root filesystem to fill the disk.

```bash
qm start 100
```

Starts the clone. cloud-init then sets the hostname (from the VM name), creates the user, installs the key, configures the network and grows the disk.

From your workstation:

```bash
ssh <USER>@<VM_IP>
hostname       # should print test-clone
ip -br a       # should show <VM_IP>/<CIDR> on the interface
df -h /        # root size should include the extra 5G
sudo whoami    # should print root, without a password prompt
```

Then clean up on the Proxmox node:

```bash
qm stop 100 && qm destroy 100 --purge
```

Stops the VM, then deletes it with its disks. `--purge` also removes it from backup jobs, replication and HA settings.
