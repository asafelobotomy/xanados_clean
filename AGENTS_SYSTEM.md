# AGENTS_SYSTEM.md

> **System Maintenance Agents**
> *This file documents the system-level agents used by the maintenance scripts
to manage core functionality such as packages, storage, system monitoring,
and cleanup.*

---

## 🔧 Package Managers

- **`pacman`**  
  Arch Linux's default package manager. Used to install, upgrade, and remove
  software packages.
  *Used when `paru` is not installed.*

- **`paru`**
  An AUR helper and frontend for `pacman`. Enables seamless access to Arch User
  Repository (AUR) packages.
  *Preferred if installed. Script prompts to install if missing.*

- **`dnf`**
  Fedora's package manager used on Bazzite for installing and upgrading
  packages when not using rpm-ostree.

- **`rpm-ostree`**
  Manages immutable Fedora-based systems such as Bazzite. Used to apply
  atomic upgrades when available.

---

## 💽 Storage & Filesystem Tools

- **`btrfs-progs`**  
  Provides utilities for Btrfs file system maintenance:
  `scrub`, `balance`, and `defragment` commands are used to keep the filesystem
  healthy.

- **`util-linux`**  
  Supplies essential utilities such as `fstrim` (for SSDs) and `lsblk`
  (for block device inspection).

- **`smartmontools`**  
  Provides `smartctl`, which is used to query and monitor the health of hard
  drives and SSDs via SMART.

---

## 🌐 Platform Tools

- **`flatpak`**  
  Enables support for Flatpak applications. The script uses it to update
  Flatpak-managed apps if installed.

---

## 🧪 Diagnostics & Monitoring

- **`pciutils`**  
  Includes `lspci`, used for identifying connected PCI devices such as GPUs and
  network cards.

- **`lm_sensors`**  
  Used to detect and report CPU and GPU temperatures and voltages via the
  `sensors` command.

---

## 🧹 System Cleanup

- **`paccache`**
  Part of the `pacman-contrib` package. Used to clean outdated package versions
  from the local cache.

- **`dnf autoremove`**
  Removes unneeded packages on Fedora/Bazzite systems. The script also runs
  `dnf clean` to clear metadata.

- **`journalctl`**  
  Systemd log viewer. Used to rotate logs older than 7 days and display
  critical error messages.

- **`systemctl`**  
  Core systemd utility for managing system services. The script checks for
  failed services.

---

## 📡 Network Operations

- **`reflector`**
  Updates and ranks Arch mirrorlists by speed and protocol. Ensures fast and
  reliable package downloads.

- **`dnf-plugins-core`**
  Provides `fastestmirror` for optimizing Fedora mirror selection.

- **`curl`**
  Used to retrieve and display recent news from distribution RSS feeds
  (Arch Linux or Fedora).

- **`xmlstarlet`**
  Parses RSS feeds to display clean news titles.

---

## Notes

- These agents are considered **essential** for the baseline operation of
  the maintenance scripts.
- The script attempts to detect and use each tool. If a tool is missing and
  required, it will prompt for installation or skip the related functionality.

---
