# AGENTS.md

> **Arch Linux System Maintenance Script — Agent Documentation**  
> _Maintains a development-, gaming-, and security-optimized Arch system._

📅 **Last updated:** 2025-06-05  
✍️ **Author:** [Linux Specialist (ChatGPT)]

---

## 🧠 Purpose

This document lists all **system agents** — tools, packages, and services invoked by the `system_maint.sh` Bash script.

Each agent includes:
- Its purpose (role)
- The function it serves in the script
- Whether it's optional or required
- Installation and integration notes when relevant

This helps with:
- Understanding script behavior
- Troubleshooting system dependencies
- Automating CI validation (e.g., ShellCheck)
- Aiding AI tools like GitHub Copilot, ChatGPT, or Codex with context

---

## 🔧 Package Managers

| Agent     | Role                         | Notes                                     |
|-----------|------------------------------|-------------------------------------------|
| <!-- AGENT: pacman --> `pacman`  | Core Arch package manager     | Used when `paru` is not available         |
| <!-- AGENT: paru --> `paru`    | AUR helper and `pacman` frontend | Used if installed, prompts if missing     |

---

## 🛡️ Security & Auditing Tools

| Agent            | Function                              | Optional |
|------------------|---------------------------------------|----------|
| <!-- AGENT: arch-audit --> `arch-audit`   | Checks packages for known CVEs        | ✅       |
| <!-- AGENT: rkhunter --> `rkhunter`       | Scans for rootkits and backdoors      | ✅       |
| <!-- AGENT: ufw --> `ufw`                 | Displays firewall status              | ✅       |

---

## 💾 Backup Agents

| Agent           | Function                                   | Fallback |
|-----------------|--------------------------------------------|----------|
| <!-- AGENT: timeshift --> `timeshift`     | Snapshot tool for system backups       | Yes      |
| <!-- AGENT: snapper --> `snapper`         | Btrfs-based snapshot utility           | Yes      |
| <!-- AGENT: rsync --> `rsync`             | Full filesystem backup (manual path)   | No       |

---

## 💽 Storage & Filesystem Tools

| Agent             | Role & Function                                  |
|-------------------|--------------------------------------------------|
| <!-- AGENT: btrfs-progs --> `btrfs-progs`     | Maintains Btrfs volumes (scrub, defrag, balance) |
| <!-- AGENT: util-linux --> `util-linux`       | Provides tools like `fstrim`, `lsblk`            |
| <!-- AGENT: smartmontools --> `smartmontools` | Checks SSD/HDD health via `smartctl`             |

---

## 🧪 Diagnostics & Monitoring

| Agent             | Function                          |
|-------------------|-----------------------------------|
| <!-- AGENT: pciutils --> `pciutils`       | Detects PCI hardware like GPUs/CPUs     |
| <!-- AGENT: lm_sensors --> `lm_sensors`   | Reports system temperatures             |
| <!-- AGENT: shellcheck --> `shellcheck`   | Static analyzer for shell script quality |

---

## 🎮 Gaming Enhancements

| Agent             | Role                                           |
|-------------------|------------------------------------------------|
| <!-- AGENT: gamemode --> `gamemode`       | Boosts performance for games             |
| <!-- AGENT: nvidia-utils --> `nvidia-utils` | Enables GPU diagnostics via `nvidia-smi` |

---

## 🌐 Platform Tools

| Agent     | Role                    |
|-----------|-------------------------|
| <!-- AGENT: flatpak --> `flatpak` | Supports and updates sandboxed apps  |

---

## 🧹 System Cleanup

| Agent             | Function                            |
|-------------------|-------------------------------------|
| <!-- AGENT: paccache --> `paccache`       | Cleans old Pacman package caches        |
| <!-- AGENT: journalctl --> `journalctl`   | Rotates and filters system logs         |
| <!-- AGENT: systemctl --> `systemctl`     | Lists failed services or unit issues    |

---

## 📡 Network Operations

| Agent         | Purpose                                |
|---------------|----------------------------------------|
| <!-- AGENT: reflector --> `reflector` | Optimizes and saves mirrorlist         |
| <!-- AGENT: curl --> `curl`           | Fetches latest Arch Linux news feed    |

---

## ⚙️ Shell Script Linting (CI)

| Agent        | Role                                      |
|--------------|-------------------------------------------|
| <!-- AGENT: shellcheck --> `shellcheck` | Validates script syntax, safety, and style |

To automatically check Bash scripts with ShellCheck in a GitHub repository, create the file:

📁 `.github/workflows/shellcheck.yml`

```yaml
name: ShellCheck

on:
  push:
    paths:
      - '**/*.sh'
  pull_request:
    paths:
      - '**/*.sh'

jobs:
  shellcheck:
    name: Shell Script Linting
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3

      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@v2
