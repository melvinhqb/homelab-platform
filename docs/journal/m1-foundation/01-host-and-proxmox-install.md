# 1. Host and Proxmox installation

## Goal

Turn an old laptop into a hypervisor that can be driven from code.

## What was done

- **Host selection.** Two old laptops were available. The one kept has an Intel Core i5-8265U (4 cores, 8 threads), 8 GB of DDR4 RAM (one slot, upgradable to 12 GB) and a 512 GB NVMe SSD. The other one was capped at 8 GB of older DDR3L RAM. See [ADR 0001](../../adr/0001-proxmox-and-k3s.md) for the hypervisor choice.
- **Network.** The laptop has no Ethernet port. A USB 3 Ethernet adapter (Realtek RTL8153) is used, because Proxmox bridges do not work well over Wi-Fi.
- **BIOS.** Intel VT-x enabled, Secure Boot disabled for the installer, storage controller switched to AHCI (see below).
- **Installation.** Proxmox VE 9.2, ext4 on the NVMe SSD, static IP outside the DHCP range of the router.

## Problems and fixes

### The USB stick did not boot

- **Symptom.** The laptop showed `Start PXE over IPv4`, failed the network boot, then started Windows.
- **Cause.** The downloaded ISO was the **arm64** build. The laptop is x86_64, so the firmware did not see the stick as bootable and moved on to the next device.
- **Fix.** Downloaded the official **amd64** ISO from proxmox.com, checked its SHA256 against the published value, flashed it again, and booted it through Windows' "Use a device" menu (Shift + Restart), which is more reliable than the F12 menu on this laptop.

### "No Hard Disk found!"

- **Symptom.** The installer did not list the NVMe SSD, which Windows had been using.
- **Cause.** The storage controller was in **Intel RST** mode. Windows has a driver for it, the Linux installer does not see the disk behind it.
- **Fix.** Switched the controller to **AHCI** in the BIOS. This makes the existing Windows unbootable, which did not matter since the disk was wiped.

### Choosing the management interface

- **Symptom.** The installer offered `nic0` and `nic1`, with no obvious way to tell which one was wired.
- **Fix.** Proxmox 9 uses neutral interface names, so the **driver** shown next to each one is what matters: `r8152` is the USB Ethernet adapter, `ath10k_pci` is the Wi-Fi card.
- **Also.** The installer pre-filled an IP leased by the router's DHCP. It was replaced by a fixed address outside the DHCP range, so the router cannot hand it to another device later.

## Lessons

- Check the **target architecture** of an image (amd64 or arm64) before flashing it, and verify its checksum.
- On recent Intel laptops, check the storage controller mode (RST/VMD or AHCI) before installing Linux.
- A server needs a **static address outside the DHCP range**.

## Result

Proxmox VE runs on the laptop, wired through the USB adapter, and its web UI answers on `https://10.0.0.5:8006` from the LAN.