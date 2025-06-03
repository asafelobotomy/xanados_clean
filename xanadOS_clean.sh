#!/usr/bin/env bash
# system_maint.sh — Arch Linux System Maintenance (Gaming + Dev + Security)
# Author: Linux Specialist (ChatGPT)
# Updated: 2025-06-05

set -euo pipefail
IFS=$'\n\t'

readonly GREEN='\033[0;32m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

LOG_FILE="${HOME}/Documents/system_maint.log"
[[ -d "${HOME}/Documents" ]] || LOG_FILE="${HOME}/system_maint.log"

exec > >(tee -a "${LOG_FILE}") 2>&1
echo -e "\n========== SYSTEM MAINTENANCE RUN: $(date) =========="

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

print_banner() {
  printf "${BLUE}"
  cat <<'ART'
  ___  _   _ ____  ____  _____ ____  _   _
 / _ \| | | |  _ \|  _ \| ____|  _ \| | | |
| | | | | | | |_) | | | |  _| | |_) | | | |
| |_| | |_| |  _ <| |_| | |___|  _ <| |_| |
 \__\_\\___/|_| \_\____/|_____|_| \_\\___/
ART
  printf "            %s\n" "$1"
  printf "${NC}"
}

run_step() {
  local func=$1
  local desc=$2
  if [[ "${ASK_EACH:-false}" == true ]]; then
    read -rp $"\nRun ${desc}? [Y/n] " ans
    if [[ ${ans,,} =~ ^n ]]; then
      summary "Skipped: ${desc}"
      return
    fi
  fi
  "$func"
}

refresh_mirrors() {
  print_banner "Refresh Mirrors"
  log "Refreshing mirrorlist before any installs or upgrades..."
  sudo pacman -Sy --noconfirm reflector
  sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  sudo pacman -Syy --noconfirm
  summary "Mirrorlist refreshed."
}

choose_pkg_manager() {
  if command -v paru &>/dev/null; then
    PKG_MGR="paru"
    summary "Using existing paru for all package operations."
  else
    read -rp $'\nParu not found. Would you like to install it? [Y/n] ' install_paru
    if [[ "${install_paru,,}" =~ ^(y|yes)?$ ]]; then
      sudo pacman -S --needed --noconfirm base-devel git
      git clone https://aur.archlinux.org/paru.git /tmp/paru
      (cd /tmp/paru && makepkg -si --noconfirm)
      PKG_MGR="paru"
      summary "Paru installed and selected."
    else
      PKG_MGR="pacman"
      summary "Paru declined. Using pacman."
    fi
  fi
}

rsync_backup() {
  if command -v rsync &>/dev/null; then
    read -rp $'\nDestination path for rsync backup (leave blank to skip): ' RSYNC_DIR
    if [[ -n "${RSYNC_DIR}" ]]; then
      sudo rsync -aAX --delete --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / "${RSYNC_DIR}"
      summary "Rsync backup completed to ${RSYNC_DIR}"
    else
      summary "Rsync backup skipped."
    fi
  fi
}

pre_backup() {
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
  rsync_backup
}

dependency_check() {
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
    [rsync]="Incremental backup"
    [flatpak]="Flatpak support"
    [pacman-contrib]="Pacman helper tools"
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
      if [[ ${PKG_MGR} == pacman ]]; then
        sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
      else
        ${PKG_MGR} -S --needed --noconfirm "${MISSING_PKGS[@]}"
      fi
      for pkg in "${MISSING_PKGS[@]}"; do
        summary "Installed: $pkg"
      done
    else
      for pkg in "${MISSING_PKGS[@]}"; do
        read -rp "Install $pkg? [Y/n] " answer
        if [[ "${answer,,}" =~ ^(y|yes)?$ ]]; then
          if [[ ${PKG_MGR} == pacman ]]; then
            sudo pacman -S --needed --noconfirm "$pkg"
          else
            ${PKG_MGR} -S --needed --noconfirm "$pkg"
          fi
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
}

system_update() {
  print_banner "System Update"
  if [[ ${PKG_MGR} == pacman ]]; then
    sudo pacman -Syu --noconfirm
  else
    ${PKG_MGR} -Syu --noconfirm
  fi
  summary "System packages updated."
}

flatpak_update() {
  if command -v flatpak &>/dev/null; then
    print_banner "Flatpak Update"
    flatpak update -y
    summary "Flatpak packages updated."
  fi
}

remove_orphans() {
  print_banner "Remove Orphans"
  orphans=$(sudo pacman -Qtdq 2>/dev/null || true)
  if [[ -n "${orphans}" ]]; then
    sudo pacman -Rns --noconfirm "${orphans}"
    summary "Removed $(echo "${orphans}" | wc -l) orphaned packages."
  else
    summary "No orphan packages found."
  fi
}

cache_cleanup() {
  print_banner "Cache Cleanup"
  if command -v paccache &>/dev/null; then
    sudo paccache -r
    summary "Pacman cache cleaned."
  fi
  read -rp $'\nClean ~/.cache directory? [y/N] ' clean_home
  if [[ ${clean_home,,} =~ ^y ]]; then
    rm -rf ~/.cache/*
    summary "Home cache cleaned."
  fi
  journalctl --vacuum-time=7d
  summary "Journal logs rotated."
}

security_scan() {
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
}

check_failed_services() {
  print_banner "Failed Services"
  systemctl --failed
  summary "Checked systemd failed services."
}

check_journal_errors() {
  print_banner "Recent System Errors"
  journalctl -p 3 -xb | tail -n 20
  summary "Displayed recent journal errors."
}

btrfs_maintenance() {
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
}

ssd_trim() {
  print_banner "SSD TRIM"
  mapfile -t ssds < <(lsblk -d -o name,rota | awk '$2 == 0 {print "/dev/" $1}')
  for dev in "${ssds[@]}"; do
    sudo fstrim -v "$dev" && summary "SSD TRIM: $dev"
  done
}

display_arch_news() {
  print_banner "Arch News"
  if command -v curl &>/dev/null; then
    curl -s https://archlinux.org/feeds/news/ | grep -o '<title>[^<]*' | sed 's/<title>//' | sed -n '2,6p'
    summary "Latest Arch news displayed."
  fi
}

system_report() {
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
}

final_summary() {
  print_banner "Maintenance Complete"
  log "System maintenance complete: $(date)"
  printf "${CYAN}\nSummary:\n${NC}"
  for line in "${SUMMARY_LOG[@]}"; do
    printf "  • %s\n" "$line"
  done
  printf "\n${BLUE}[✓] Maintenance completed successfully.${NC}\n"
}

main_menu() {
  echo -e "\n1) Full maintenance\n2) Custom selection\n0) Exit"
  read -rp "Select option [1]: " choice
  case "$choice" in
    0) exit 0 ;;
    2) ASK_EACH=true ;;
    *) ASK_EACH=false ;;
  esac
}

main() {
  print_banner "Arch Maintenance"
  main_menu
  run_step refresh_mirrors "Refresh Mirrors"
  run_step choose_pkg_manager "Package Manager Setup"
  run_step pre_backup "System Backup"
  run_step dependency_check "Dependency Check"
  run_step system_update "System Update"
  run_step flatpak_update "Flatpak Update"
  run_step remove_orphans "Remove Orphans"
  run_step cache_cleanup "Cache Cleanup"
  run_step security_scan "Security Scan"
  run_step check_failed_services "Failed Service Check"
  run_step check_journal_errors "Journal Error Check"
  run_step btrfs_maintenance "Btrfs Maintenance"
  run_step ssd_trim "SSD Trim"
  run_step display_arch_news "Arch News"
  run_step system_report "System Report"
  final_summary
}

main "$@"
