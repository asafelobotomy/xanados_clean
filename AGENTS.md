# AGENTS.md

> **Arch Linux System Maintenance Script — Agent Documentation**  
> _Maintains a development- and gaming-focused Arch system with security in mind._

📅 **Last updated:** 2025-06-05  
✍️ **Author:** [Linux Specialist (ChatGPT)]

---

## 🔧 Package Managers

| Agent     | Role                         | Notes                                     |
|-----------|------------------------------|-------------------------------------------|
| `pacman`  | Core Arch package manager     | Used when `paru` is not installed         |
| `paru`    | AUR helper + frontend for `pacman` | Used if available; prompts for install otherwise |

---

## 🛡️ Security & Auditing Tools

| Agent          | Function                              | Optional? |
|----------------|---------------------------------------|-----------|
| `arch-audit`   | Checks packages for known CVEs        | ✅        |
| `rkhunter`     | Scans for rootkits and backdoors      | ✅        |
| `ufw`          | Displays firewall status              | ✅        |

---

## 💾 Backup Agents

| Agent        | Function                                 | Fallback |
|--------------|------------------------------------------|----------|
| `timeshift`  | Snapshot tool for system backups         | Yes      |
| `snapper`    | Btrfs-based snapshot tool                | Yes      |
| `rsync`      | Full filesystem backup to target dir     | No       |

---

## 💽 Storage & Filesystem Tools

| Agent         | Role & Function                                     |
|---------------|-----------------------------------------------------|
| `btrfs-progs` | Manages Btrfs scrub/balance/defrag                  |
| `util-linux`  | Provides tools like `fstrim`, `lsblk`, etc.         |
| `smartmontools` | Checks SSD/HDD health via `smartctl`             |

---

## 🧪 Diagnostics & Monitoring

| Agent         | Role                            |
|---------------|---------------------------------|
| `pciutils`    | Detects PCI hardware            |
| `lm_sensors`  | Displays CPU/GPU temperatures   |
| `shellcheck`  | Analyzes shell script syntax and style |

---

## 🎮 Gaming Enhancements

| Agent         | Role                                     |
|---------------|------------------------------------------|
| `gamemode`    | Boosts performance for games             |
| `nvidia-utils`| Enables `nvidia-smi` for GPU diagnostics |

---

## 🌐 Platform Tools

| Agent     | Role                    |
|-----------|-------------------------|
| `flatpak` | Updates sandboxed apps  |

---

## 🧹 System Cleanup

| Agent            | Function                            |
|------------------|-------------------------------------|
| `paccache`       | Cleans old pacman caches            |
| `journalctl`     | Rotates logs older than 7 days      |
| `systemctl`      | Lists failed services               |

---

## 📡 Network Operations

| Agent      | Purpose                                |
|------------|----------------------------------------|
| `reflector`| Optimizes mirrorlist for pacman        |
| `curl`     | Fetches latest Arch news feed          |

---

## 🧠 Behavior Notes

<details>
<summary><strong>📌 Missing Agents</strong></summary>

- If agents like `arch-audit` or `rkhunter` are not installed, the script offers to install them.
- Declining to install agents disables related functionality (e.g., skipping rootkit scans).
- All agent interactions are logged in `system_maint.log`.
</details>

<details>
<summary><strong>💡 Interactive Mode</strong></summary>

- When run in "custom selection" mode, the user is prompted before each maintenance step.
- Most actions can be skipped interactively to suit system-specific needs.
</details>

<details>
<summary><strong>🚀 CI/CD Integration — ShellCheck</strong></summary>

To automatically lint all shell scripts on push or pull request, add the following GitHub Actions workflow at:

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
