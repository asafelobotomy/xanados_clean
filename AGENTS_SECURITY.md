# AGENTS_SECURITY.md

> **Security & Backup Agents**  
> *This file documents the tools used by `system_maint.sh` for vulnerability
scanning, rootkit detection, firewall auditing, and backup operations.*

---

## 🛡️ Security & Auditing Tools

- **`arch-audit`**  
  A vulnerability scanner that checks installed Arch Linux packages for known
  CVEs (Common Vulnerabilities and Exposures).
  *Used to flag outdated or insecure software.*

- **`rkhunter`**  
  Rootkit Hunter scans the system for known rootkits, backdoors, and other
  signs of intrusion.
  *Updates its database and runs a check with log summaries.*

- **`ufw`**  
  The Uncomplicated Firewall. Used to check firewall status and rules.  
  *Only queried if installed.*

---

## 💾 Backup Agents

- **`timeshift`**  
  Creates system snapshots for rollback. Ideal for backing up system states
  before performing risky operations.
  *Used if installed and available.*

- **`snapper`**  
  Btrfs snapshot manager. An alternative to Timeshift for Btrfs-managed
  systems.
  *Only used if Timeshift is not available.*

- **`rsync`**  
  Performs a full incremental backup of the root filesystem to a specified
  directory.
  *Optional and manually triggered during script execution.*

---

## 🎮 Gaming Enhancements

- **`gamemode`**  
  A runtime daemon that optimizes the system for gaming workloads.  
  *The script checks its status if installed.*

- **`nvidia-utils`**  
  Enables `nvidia-smi` for querying NVIDIA GPU status and temperatures.  
  *Optional; included for systems with NVIDIA GPUs.*

---

## Notes

- All security-related tools are **optional but recommended**.
- If a tool is not installed, the script prompts the user to install or skip it.
- Skipping an agent disables its corresponding feature gracefully.
- Backups (via Timeshift, Snapper, or rsync) are triggered early to ensure
  recovery is possible.

---
