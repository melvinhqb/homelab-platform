# 2. Proxmox hardening

## Goal

Secure the hypervisor before anything runs on it.

## What was done

- **Repositories.** Enterprise repositories (PVE and Ceph) disabled, since they need a subscription; `no-subscription` repository added; full upgrade and reboot.
- **Accounts.** A named administrator (`admin@pve`) for daily use, with TOTP two-factor authentication on it and on `root@pam`, plus recovery keys stored in a password manager. `root` is kept for emergencies and host-level tasks.
- **SSH.** Key-based login only, configured in a drop-in file, checked with `sshd -t` before the restart:

  ```
  # /etc/ssh/sshd_config.d/99-hardening.conf
  PasswordAuthentication no
  PermitRootLogin prohibit-password
  ```

  Checked from a second terminal: key login works, `ssh -o PubkeyAuthentication=no` is refused.
- **Exposure.** No port forwarding to the host, DMZ disabled, the host's address is outside the DHCP range, and a test from a mobile network on the public IP got no answer on port 8006.
- **Laptop as a server.** Lid close and sleep ignored (`HandleLidSwitch=ignore`, sleep targets masked), so the server never suspends itself.

## Problems and fixes

### An unexpected key ended up authorized

- **Symptom.** `ssh-copy-id` reported **2 keys** added instead of one.
- **Cause.** Without `-i`, `ssh-copy-id` sends **every key loaded in the SSH agent**. A key used for another, older server was now authorized on the hypervisor.
- **Fix.** Reviewed `authorized_keys` and removed the extra key, keeping the workstation key and Proxmox's own `root@pve` key.

### A stray line in `authorized_keys`

- **Cause.** A command written for Windows PowerShell (`type $env:USERPROFILE\...`) was run on Linux. Its error message was appended to the file instead of a key.
- **Fix.** Removed the line. On Proxmox, `~/.ssh/authorized_keys` is a symlink to `/etc/pve/priv/authorized_keys`: the file was rewritten with `cat >` rather than `sed -i`, which would have replaced the symlink with a regular file.

### IPv6 has no NAT

- **Finding.** VMs and the host get a **public IPv6** address from the ISP. Checking port forwarding only covers IPv4.
- **Fix.** Checked that the router's IPv6 firewall blocks inbound connections.

## Lessons

- Always review `authorized_keys` after `ssh-copy-id`, or target one key with `ssh-copy-id -i <key>.pub`.
- Validate an SSH configuration before restarting the daemon, and keep a session open while testing.
- "Not exposed" has to be checked for **both IPv4 and IPv6**.

## Result

The host only accepts SSH keys, the web UI requires a second factor, and nothing is reachable from the Internet. Remote access, if needed later, will go through a VPN (Tailscale or WireGuard), never through an open port.