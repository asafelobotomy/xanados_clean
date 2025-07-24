#!/usr/bin/env bash
# xanados_clean.sh — xanadOS Arch Linux System Maintenance (Gaming + Dev + Security)
# Author: Co-Pilot (Claude Sonnet 4)
# Updated: 2025-07-23
# Version: 2.0.0
# Security: Enhanced with secure temporary files, SSL/TLS validation, and input sanitization

set -euo pipefail
IFS=$'\n\t'

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color definitions
readonly GREEN='\033[0;32m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Load library system with configurable path
LIB_DIR="${XANADOS_LIB_DIR:-$SCRIPT_DIR/lib}"
# Load new consolidated library system
if [[ -f "$LIB_DIR/core.sh" ]]; then
    # shellcheck source=lib/core.sh
    source "$LIB_DIR/core.sh"
fi

if [[ -f "$LIB_DIR/system.sh" ]]; then
    # shellcheck source=lib/system.sh
    source "$LIB_DIR/system.sh"
fi

if [[ -f "$LIB_DIR/maintenance.sh" ]]; then
    # shellcheck source=lib/maintenance.sh
    source "$LIB_DIR/maintenance.sh"
fi

if [[ -f "$LIB_DIR/extensions.sh" ]]; then
    # shellcheck source=lib/extensions.sh
    source "$LIB_DIR/extensions.sh"
fi

# Initialize variables
PKG_MGR=""
SIMPLE_MODE="${SIMPLE_MODE:-false}"
TEST_MODE="${TEST_MODE:-false}"

# Set defaults if not loaded by configuration system
LOG_FILE="${LOG_FILE:-${HOME}/Documents/system_maint.log}"
AUTO_MODE="${AUTO_MODE:-false}"

# Ensure log directory exists
[[ -d "${HOME}/Documents" ]] || LOG_FILE="${HOME}/system_maint.log"
LOG_DIR=$(dirname "${LOG_FILE}")
mkdir -p "${LOG_DIR}"

exec > >(tee -a "${LOG_FILE}") 2>&1
echo -e "\n========== SYSTEM MAINTENANCE RUN: $(date) =========="

# These functions are now provided by lib/core.sh

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
  # Check if SUDO is already set by GUI (don't override it)
  if [[ -z "${SUDO:-}" ]]; then
    SUDO="sudo"
  fi
  USER_CMD=()
fi

# These functions are now provided by lib/maintenance.sh and lib/system.sh

# Functions moved to consolidated libraries:
# - refresh_mirrors, dependency_check -> lib/maintenance.sh  
# - system_update, flatpak_update -> lib/maintenance.sh
# - remove_orphans, cache_cleanup -> lib/maintenance.sh
# - security_scan, btrfs_maintenance -> lib/maintenance.sh
# - ssd_trim, display_arch_news -> lib/maintenance.sh
# - system_report -> lib/system.sh
# - choose_pkg_manager, pkg_mgr_run -> lib/maintenance.sh
# - update_tool_if_outdated -> lib/maintenance.sh
# - pre_backup, rsync_backup -> lib/maintenance.sh  
# - check_failed_services, check_journal_errors -> lib/system.sh

final_summary() {
  # Use enhanced summary if available, otherwise fall back to basic
  if command -v enhanced_final_summary >/dev/null 2>&1; then
    enhanced_final_summary
  else
    print_banner "Maintenance Complete"
    log "System maintenance complete: $(date)"
    printf '%b' "${CYAN}\nSummary:\n${NC}"
    for line in "${SUMMARY_LOG[@]}"; do
      printf "  • %s\n" "$line"
    done
    printf '%b\n' "${BLUE}[✓] Maintenance completed successfully.${NC}"
  fi
}

main_menu() {
  # Skip menu in simple mode
  if [[ "${SIMPLE_MODE:-false}" == "true" ]]; then
    ASK_EACH=false
    return
  fi
  
  echo -e "\n1) Full maintenance\n2) Custom selection\n3) Simple mode\n0) Exit"
  if [[ ${AUTO_MODE} != true ]]; then
    read -rp "Select option [1]: " choice
  else
    choice="1"
  fi
  case "$choice" in
    0) exit 0 ;;
    2) ASK_EACH=true ;;
    3) SIMPLE_MODE=true; ASK_EACH=false ;;
    *) ASK_EACH=false ;;
  esac
}

# Simple mode - basic maintenance only (like arch-cleaner)
run_simple_maintenance() {
  print_banner "Simple Mode - Basic Maintenance"
  log "Running basic maintenance operations..."
  
  # Essential operations only - use simple run_step to avoid complications
  choose_pkg_manager
  run_step system_update "System Update"
  run_step remove_orphans "Remove Orphans" 
  run_step cache_cleanup "Cache Cleanup"
  run_step check_failed_services "Service Check"
  
  # Simple summary
  print_banner "Simple Maintenance Complete"
  log "Basic maintenance completed: $(date)"
  printf '%b' "${CYAN}\nOperations completed:\n${NC}"
  printf "  • System packages updated\n"
  printf "  • Orphaned packages removed\n" 
  printf "  • Package cache cleaned\n"
  printf "  • Failed services checked\n"
  printf '%b\n' "${BLUE}[✓] Simple maintenance completed successfully.${NC}"
}

main() {
  # Parse command line arguments
  parse_arguments "$@"
  
  # Check for stale pacman lock files early (unless in test mode)
  if [[ "${TEST_MODE:-false}" != "true" ]] && command -v check_stale_pacman_lock >/dev/null 2>&1; then
    check_stale_pacman_lock
  fi
  
  # Handle simple mode early to bypass complex initialization
  if [[ "${SIMPLE_MODE:-false}" == "true" ]]; then
    require_pacman
    print_banner "Arch Maintenance v2.0"
    
    # Check for test mode
    if [[ "${TEST_MODE:-false}" == "true" ]]; then
      log "Running in test mode - no actual changes will be made"
      export TEST_MODE="true"
      # Use a function instead of command substitution for test mode
      sudo() { echo "[TEST-MODE] Would run: $*"; }
      export -f sudo
      SUDO="sudo"
    fi
    
    run_simple_maintenance
    return
  fi
  
  # Enhanced initialization with all systems for full mode
  local resumed=false
  if command -v enhanced_init >/dev/null 2>&1; then
    if enhanced_init; then
      resumed=true
    fi
  fi
  
  # Load configuration (after argument parsing to handle custom config file)
  if command -v load_config >/dev/null 2>&1; then
    load_config
  fi
  
  # Run pre-maintenance script if configured
  if [[ -n "${PRE_MAINTENANCE_SCRIPT:-}" ]]; then
    run_custom_script "$PRE_MAINTENANCE_SCRIPT" "pre-maintenance"
  fi
  
  require_pacman
  print_banner "Arch Maintenance v2.0"
  
  # Check for test mode
  if [[ "${TEST_MODE:-false}" == "true" ]]; then
    log "Running in test mode - no actual changes will be made"
    export TEST_MODE="true"
    # Use a function instead of command substitution for test mode
    sudo() { echo "[TEST-MODE] Would run: $*"; }
    export -f sudo
    SUDO="sudo"
  fi
  
  # Skip menu if resuming from checkpoint
  if [[ "$resumed" != "true" ]]; then
    if [[ "${AUTO_MODE:-false}" != "true" ]]; then
      main_menu
    else
      ASK_EACH=false
    fi
  fi
  
  # Run maintenance steps with enhanced execution
  local run_func="run_step"
  if command -v enhanced_run_step >/dev/null 2>&1; then
    run_func="enhanced_run_step"
  fi
  
  # Apply latest Arch Linux optimizations first
  if [[ "${ENABLE_ARCH_OPTIMIZATIONS:-true}" == "true" ]] && command -v run_arch_optimizations >/dev/null 2>&1; then
    $run_func run_arch_optimizations "Arch Linux Optimizations"
  fi
  
  if [[ "${UPDATE_MIRRORS:-true}" == "true" ]]; then
    $run_func refresh_mirrors "Refresh Mirrors"
  fi
  $run_func choose_pkg_manager "Package Manager Setup"
  $run_func pre_backup "System Backup"
  $run_func dependency_check "Dependency Check"
  $run_func system_update "System Update"
  
  if [[ "${ENABLE_FLATPAK:-true}" == "true" ]]; then
    $run_func flatpak_update "Flatpak Update"
  fi
  
  if [[ "${ENABLE_ORPHAN_REMOVAL:-true}" == "true" ]]; then
    $run_func remove_orphans "Remove Orphans"
  fi
  
  if [[ "${ENABLE_CACHE_CLEANUP:-true}" == "true" ]]; then
    $run_func cache_cleanup "Cache Cleanup"
  fi
  
  if [[ "${ENABLE_SECURITY_SCAN:-true}" == "true" ]]; then
    $run_func security_scan "Security Scan"
  fi
  
  $run_func check_failed_services "Failed Service Check"
  $run_func check_journal_errors "Journal Error Check"
  
  if [[ "${ENABLE_BTRFS_MAINTENANCE:-auto}" != "false" ]]; then
    $run_func btrfs_maintenance "Btrfs Maintenance"
  fi
  
  if [[ "${ENABLE_SSD_TRIM:-auto}" != "false" ]]; then
    $run_func ssd_trim "SSD Trim"
  fi
  
  if [[ "${SHOW_NEWS:-true}" == "true" ]]; then
    $run_func display_arch_news "Arch News"
  fi
  
  if [[ "${ENABLE_SYSTEM_REPORT:-true}" == "true" ]]; then
    $run_func system_report "System Report"
  fi
  
  # Run post-maintenance script if configured
  if [[ -n "${POST_MAINTENANCE_SCRIPT:-}" ]]; then
    run_custom_script "$POST_MAINTENANCE_SCRIPT" "post-maintenance"
  fi
  
  # Enhanced cleanup and summary
  if command -v enhanced_cleanup >/dev/null 2>&1; then
    enhanced_cleanup
  fi
  
  final_summary
}

main "$@"
