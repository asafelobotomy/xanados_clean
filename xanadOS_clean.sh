#!/usr/bin/env bash
# system_maint.sh — Arch Linux System Maintenance (Gaming + Dev + Security)
# Author: Linux Specialist (ChatGPT)
# Updated: 2025-06-03

set -euo pipefail
IFS=$'\n\t'

# ----------------------------
# Constants and Logging Setup
# ----------------------------
readonly GREEN='\033[0;32m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

LOG_FILE="${HOME}/Documents/system_maint.log"
[[ -d "${HOME}/Documents" ]] || LOG_FILE="${HOME}/system_maint.log"

exec > >(tee -a "${LOG_FILE}") 2>&1
echo -e "\n========== SYSTEM MAINTENANCE RUN: $(date) =========="

# ----------------------------
# Logging Functions
# ----------------------------
log() {
  printf "${GREEN}[+] %s${NC}\n" "$1"
}

error() {
  printf "${RED}[!] %s${NC}\n" "$1" >&2
}

summary() {
  SUMMARY_LOG+=("$1")
  log "$1"
}

trap 'error "Script exited unexpectedly. See log: ${LOG_FILE}"' ERR
SUMMARY_LOG=()

# ----------------------------
# Banner Function
# ----------------------------
print_banner() {
  printf '%b' "${BLUE}"
  cat <<'EOF'
  ___  _   _ ____  ____  _____ ____  _   _
 / _ \| | | |  _ \|  _ \| ____|  _ \| | | |
| | | | | | | |_) | | | |  _| | |_) | | | |
| |_| | |_| |  _ <| |_| | |___|  _ <| |_| |
 \__\_\\___/|_| \_\____/|_____|_| \_\\___/
EOF
  printf "            %s\n" "$1"
  printf '%b' "${NC}"
}

# ----------------------------
# Refresh Mirrors
# ----------------------------
print_banner "Refresh Mirrors"
log "Refreshing mirrorlist before any installs or upgrades..."
sudo pacman -Sy --noconfirm reflector
sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syy --noconfirm
summary "Mirrorlist refreshed."

# ----------------------------
# Package Manager: paru prompt
# ----------------------------
if command -v paru &>/dev/null; then
  PKG_MGR="paru"
  summary "Using existing paru for all package operations."
else
  read -rp $'\nParu not found. Would you like to install it? [Y/n] ' install_paru
  if [[ "${install_paru,,}" =~ ^(y|yes)?$ ]]; then
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru && makepkg -si --noconfirm
    PKG_MGR="paru"
    summary "Paru installed and selected."
  else
    PKG_MGR="pacman"
    summary "Paru declined. Using pacman."
  fi
fi

# ----------------------------
# Pre-Script Backup
# ----------------------------
print_banner "System Backup"
if command -v timeshift &>/dev/null; then
  sudo timeshift --create --comments "Pre-maintenance backup" --tags D
  summary "System backup created using Timeshift."
elif command -v snapper &>/dev/null; then
  sudo snapper create -d "Pre-maintenance backup"
  summary "System backup created using Snapper."
else
  summary "⚠️ No supported backup tool found. Backup skipped."
fi

# ----------------------------
# Dependency Check
# ----------------------------
print_banner "Dependency Check"
declare -A REQUIRED_PKGS=(
  [arch-audit]="Security vulnerability scanner"
  [rkhunter]="Rootkit scanner"
  [btrfs-progs]="Btrfs volume maintenance"
  [util-linux]="fstrim, lsblk, etc."
  [pciutils]="GPU/CPU detection"
  [lm_sensors]="Temp monitoring"
  [nvidia-utils]="NVIDIA GPU support"
  [ufw]="Firewall status checker"
  [smartmontools]="SSD health monitoring"
  [gamemode]="Gaming performance boost"
)

DISABLED_FEATURES=()
MISSING_PKGS=()

for pkg in "${!REQUIRED_PKGS[@]}"; do
  if ! ${PKG_MGR} -Qi "$pkg" &>/dev/null; then
    MISSING_PKGS+=("$pkg")
  fi
done

if (( ${#MISSING_PKGS[@]} )); then
  echo -e "\nMissing packages needed for full script functionality:"
  for pkg in "${MISSING_PKGS[@]}"; do
    echo -e "  • $pkg: ${REQUIRED_PKGS[$pkg]}"
  done

  read -rp $'\nInstall all missing packages? [Y/n] ' install_all
  if [[ "${install_all,,}" =~ ^(y|yes)?$ ]]; then
    sudo ${PKG_MGR} -S --needed --noconfirm "${MISSING_PKGS[@]}"
    for pkg in "${MISSING_PKGS[@]}"; do
      summary "Installed: $pkg"
    done
  else
    for pkg in "${MISSING_PKGS[@]}"; do
      read -rp "Install $pkg? [Y/n] " answer
      if [[ "${answer,,}" =~ ^(y|yes)?$ ]]; then
        sudo ${PKG_MGR} -S --needed --noconfirm "$pkg"
        summary "Installed: $pkg"
      else
        DISABLED_FEATURES+=("$pkg")
        summary "⚠️ Skipped: $pkg"
      fi
    done
  fi
else
  summary "All required packages are present."
fi

# ----------------------------
# System Update
# ----------------------------
print_banner "System Update"
sudo ${PKG_MGR} -Syu --noconfirm
summary "System packages updated."

# ----------------------------
# Orphaned Packages
# ----------------------------
print_banner "Remove Orphans"
  orphans=$(sudo pacman -Qtdq 2>/dev/null || true)
  if [[ -n "${orphans}" ]]; then
  sudo pacman -Rns --noconfirm "${orphans}"
  summary "Removed $(echo "${orphans}" | wc -l) orphaned packages."
else
  summary "No orphan packages found."
fi

# ----------------------------
# Security Scan
# ----------------------------
print_banner "Security Scan"
if [[ ! " ${DISABLED_FEATURES[*]} " =~ " arch-audit " ]]; then
  if arch-audit | grep -q CVE; then
    summary "⚠️ Vulnerable packages found."
  else
    summary "No vulnerabilities detected."
  fi
fi

if [[ ! " ${DISABLED_FEATURES[*]} " =~ " rkhunter " ]]; then
  sudo rkhunter --update
  if sudo rkhunter --check --skip-keypress | grep -q Warning; then
    summary "⚠️ rkhunter reported warnings."
  else
    summary "rkhunter scan clean."
  fi
fi

# ----------------------------
# Btrfs Maintenance
# ----------------------------
print_banner "BTRFS Maintenance"
if [[ ! " ${DISABLED_FEATURES[*]} " =~ " btrfs-progs " ]]; then
  mapfile -t btrfs_mounts < <(findmnt -t btrfs -n -o TARGET)
  for path in "${btrfs_mounts[@]}"; do
    sudo btrfs scrub start -Bd "$path"
    sudo btrfs balance start -dusage=75 -musage=75 "$path"
    sudo btrfs filesystem defragment -r "$path"
    summary "Btrfs maintenance completed on $path"
  done
else
  summary "⚠️ Btrfs maintenance skipped."
fi

# ----------------------------
# SSD TRIM
# ----------------------------
print_banner "SSD TRIM"
mapfile -t ssds < <(lsblk -d -o name,rota | awk '$2 == 0 {print "/dev/" $1}')
for dev in "${ssds[@]}"; do
  sudo fstrim -v "$dev" && summary "SSD TRIM: $dev"
done

# ----------------------------
# System Reporting
# ----------------------------
print_banner "System Report"
if [[ ! " ${DISABLED_FEATURES[*]} " =~ " nvidia-utils " ]]; then
  nvidia-smi && summary "NVIDIA GPU info displayed."
fi

if [[ ! " ${DISABLED_FEATURES[*]} " =~ " gamemode " ]]; then
  systemctl --user status gamemoded && summary "Gamemode status checked."
fi

if [[ ! " ${DISABLED_FEATURES[*]} " =~ " ufw " ]]; then
  sudo ufw status verbose && summary "UFW status checked."
fi

if [[ ! " ${DISABLED_FEATURES[*]} " =~ " smartmontools " ]]; then
  while read -r dev _; do
    sudo smartctl -H "$dev" && summary "SMART health check: $dev"
  done < <(sudo smartctl --scan)
fi

if [[ ! " ${DISABLED_FEATURES[*]} " =~ " lm_sensors " ]]; then
  sensors && summary "Temperature sensors read."
fi

# ----------------------------
# Final Summary
# ----------------------------
print_banner "Maintenance Complete"
log "System maintenance complete: $(date)"

printf '%b' "${CYAN}\nSummary:\n${NC}"
for line in "${SUMMARY_LOG[@]}"; do
  printf "  • %s\n" "$line"
done

printf '%b\n' "${BLUE}[✓] Maintenance completed successfully." "${NC}"
exit 0
