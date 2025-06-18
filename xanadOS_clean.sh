#!/usr/bin/env bash
# system_maint.sh — Arch Linux System Maintenance (Gaming + Dev + Security)
# Author: Linux Specialist (ChatGPT)
# Updated: 2025-06-06

set -euo pipefail
IFS=$'\n\t'

readonly GREEN='\033[0;32m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

LOG_FILE="${HOME}/Documents/system_maint.log"
[[ -d "${HOME}/Documents" ]] || LOG_FILE="${HOME}/system_maint.log"

LOG_DIR=$(dirname "${LOG_FILE}")
mkdir -p "${LOG_DIR}"

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

err_trap() {
  error "Command '$BASH_COMMAND' failed at line ${BASH_LINENO[0]}"
  exit 1
}
trap err_trap ERR
SUMMARY_LOG=()

# Determine privilege level and configure sudo usage
if (( EUID == 0 )); then
  if [[ -n ${SUDO_USER:-} ]]; then
    SUDO=""
    USER_CMD=(sudo -u "$SUDO_USER")
  else
    error "Please run this script as a regular user with sudo access."
    exit 1
  fi
else
  SUDO="sudo"
  USER_CMD=()
fi

print_banner() {
  printf '%b' "${BLUE}"
  cat <<'ART'
                       _  ___  ___   ___ _    ___   _   _  _      _
__ ____ _ _ _  __ _ __| |/ _ \/ __| / __| |  | __| /_\ | \| |  __| |_
\ \ / _` | ' \/ _` / _` | (_) \__ \| (__| |__| _| / _ \| .` |_(_-< ' \
/_\_\__,_|_||_\__,_\__,_|\___/|___/_\___|____|___/_/ \_\_|\_(_)__/_||_|
                                 |___|
ART
  printf "            %s\n" "$1"
  printf '%b' "${NC}"
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
  ${SUDO} pacman -Sy --noconfirm reflector
  ${SUDO} reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  ${SUDO} pacman -Syy --noconfirm
  summary "Mirrorlist refreshed."
}

choose_pkg_manager() {
  if command -v paru &>/dev/null; then
    PKG_MGR="paru"
    summary "Using existing paru for all package operations."
  else
    read -rp $'\nParu not found. Would you like to install it? [Y/n] ' install_paru
    if [[ "${install_paru,,}" =~ ^(y|yes)?$ ]]; then
      ${SUDO} pacman -S --needed --noconfirm base-devel git
      "${USER_CMD[@]}" git clone https://aur.archlinux.org/paru.git /tmp/paru
      (cd /tmp/paru && "${USER_CMD[@]}" makepkg -si --noconfirm)
      rm -rf /tmp/paru
      PKG_MGR="paru"
      summary "Paru installed and selected."
    else
      PKG_MGR="pacman"
      summary "Paru declined. Using pacman."
    fi
  fi
}

pkg_mgr_run() {
  if [[ ${PKG_MGR} == pacman ]]; then
    ${SUDO} pacman "$@"
  else
    "${USER_CMD[@]}" paru "$@"
  fi
}

rsync_backup() {
  if command -v rsync &>/dev/null; then
    # Keep destination variable scoped to this function
    local RSYNC_DIR
    read -rp $'\nDestination path for rsync backup (leave blank to skip): ' RSYNC_DIR
    if [[ -n "${RSYNC_DIR}" ]]; then
      ${SUDO} rsync -aAX --delete --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / "${RSYNC_DIR}"
      summary "Rsync backup completed to ${RSYNC_DIR}"
    else
      summary "Rsync backup skipped."
    fi
  fi
}

pre_backup() {
  print_banner "System Backup"
  local now
  now=$(date +%s)
  local threshold=$((30*24*60*60))

  if command -v timeshift &>/dev/null; then
    local last_ts
    last_ts=$(${SUDO} find /timeshift/snapshots -maxdepth 1 -type d \
      -name '????-??-??_*' -printf '%T@\n' 2>/dev/null | sort -rn | head -n1)
    if [[ -n $last_ts ]] && (( now - ${last_ts%.*} < threshold )); then
      summary "Recent Timeshift snapshot found. Skipping backup step."
      return
    fi
    ${SUDO} timeshift --create --comments "Pre-maintenance backup" --tags D
    summary "System backup created using Timeshift."
    return
  elif command -v snapper &>/dev/null; then
    local last_snap
    last_snap=$(${SUDO} snapper list 2>/dev/null | awk 'NR>2 {print $5" "$6}' | tail -n1)
    if [[ -n $last_snap ]]; then
      local snap_ts
      snap_ts=$(date -d "$last_snap" +%s 2>/dev/null || echo 0)
      if (( now - snap_ts < threshold )); then
        summary "Recent Snapper snapshot found. Skipping backup step."
        return
      fi
    fi
    ${SUDO} snapper create -d "Pre-maintenance backup"
    summary "System backup created using Snapper."
    return
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
    [curl]="Retrieve web content"
    [xmlstarlet]="RSS parser"
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
      pkg_mgr_run -S --needed --noconfirm "${MISSING_PKGS[@]}"
      for pkg in "${MISSING_PKGS[@]}"; do
        summary "Installed: $pkg"
      done
    else
      for pkg in "${MISSING_PKGS[@]}"; do
        read -rp "Install $pkg? [Y/n] " answer
        if [[ "${answer,,}" =~ ^(y|yes)?$ ]]; then
          pkg_mgr_run -S --needed --noconfirm "$pkg"
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
    ${SUDO} pacman -Syu --noconfirm
  else
    "${USER_CMD[@]}" paru -Syu --noconfirm
  fi
  summary "System packages updated."
}

flatpak_update() {
  if command -v flatpak &>/dev/null; then
    print_banner "Flatpak Update"
    flatpak update --noninteractive -y
    summary "Flatpak packages updated."
  fi
}

remove_orphans() {
  print_banner "Remove Orphans"
  mapfile -t orphans < <(${SUDO} pacman -Qtdq 2>/dev/null || true)
  if (( ${#orphans[@]} )); then
    ${SUDO} pacman -Rns --noconfirm "${orphans[@]}"
    summary "Removed ${#orphans[@]} orphaned packages."
  else
    summary "No orphan packages found."
  fi
}

cache_cleanup() {
  print_banner "Cache Cleanup"
  if command -v paccache &>/dev/null; then
    ${SUDO} paccache -r
    summary "Pacman cache cleaned."
  fi
  read -rp $'\nClean ~/.cache directory? [y/N] ' clean_home
  if [[ ${clean_home,,} =~ ^y ]]; then
    # Remove all files, including dotfiles, while preventing globbing issues
    shopt -s dotglob
    rm -rf -- ~/.cache/*
    shopt -u dotglob
    summary "Home cache cleaned."
  fi
  ${SUDO} journalctl --vacuum-time=7d
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
    ${SUDO} rkhunter --update
    if ${SUDO} rkhunter --check --skip-keypress | grep -q Warning; then
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
      ${SUDO} btrfs scrub start -Bd "$path"
      local used_pct
      used_pct=$(df --output=pcent "$path" | tail -n1 | tr -dc '0-9')
      if (( used_pct >= 90 )); then
        ${SUDO} btrfs balance start -dusage=75 -musage=75 "$path"
        summary "Btrfs balance run on $path (usage ${used_pct}%)"
      else
        summary "Btrfs balance skipped on $path (usage ${used_pct}%)"
      fi
      ${SUDO} btrfs filesystem defragment -r "$path"
      summary "Btrfs maintenance completed on $path"
    done
  else
    summary "⚠️ Btrfs maintenance skipped."
  fi
}

ssd_trim() {
  print_banner "SSD TRIM"
  mapfile -t ssds < <(lsblk -d -n -o name,rota | awk '$2 == 0 {print "/dev/" $1}')
  for dev in "${ssds[@]}"; do
    ${SUDO} fstrim -v "$dev" && summary "SSD TRIM: $dev"
  done
}

display_arch_news() {
  print_banner "Arch News"
  if command -v curl &>/dev/null && command -v xmlstarlet &>/dev/null; then
    curl -s https://archlinux.org/feeds/news/ \
      | xmlstarlet sel -t -m '//item/title' -v . -n \
      | head -n 5
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
    ${SUDO} ufw status verbose && summary "UFW status checked."
  fi
  if [[ ! " ${DISABLED_FEATURES[*]} " =~ " smartmontools " ]]; then
    while read -r dev _; do
      ${SUDO} smartctl -H "$dev" && summary "SMART health check: $dev"
    done < <(${SUDO} smartctl --scan)
  fi
  if [[ ! " ${DISABLED_FEATURES[*]} " =~ " lm_sensors " ]]; then
    sensors && summary "Temperature sensors read."
  fi
}

final_summary() {
  print_banner "Maintenance Complete"
  log "System maintenance complete: $(date)"
  printf '%b' "${CYAN}\nSummary:\n${NC}"
  for line in "${SUMMARY_LOG[@]}"; do
    printf "  • %s\n" "$line"
  done
  printf '%b\n' "${BLUE}[✓] Maintenance completed successfully.${NC}"
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
