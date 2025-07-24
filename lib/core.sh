#!/usr/bin/env bash
# core.sh - Common functions for xanadOS Clean
# Contains: logging, progress, error handling, step execution
# License: GPL-3.0
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Color definitions (only set if not already defined)
if [[ -z "${GREEN:-}" ]]; then
    readonly GREEN='\033[0;32m'
    readonly BLUE='\033[1;34m'
    readonly CYAN='\033[1;36m'
    readonly RED='\033[0;31m'
    readonly NC='\033[0m'
fi

# Global variables for progress tracking
readonly TOTAL_STEPS=15
CURRENT_STEP=0
SUMMARY_LOG=()

# Logging functions
log() {
    printf "${GREEN}[+] %s${NC}\n" "$1"
}

error() {
    printf "${RED}[!] %s${NC}\n" "$1" >&2
}

warning() {
    printf "${CYAN}[!] %s${NC}\n" "$1"
}

summary() {
    SUMMARY_LOG+=("$1")
    log "$1"
}

# Log rotation management
setup_log_rotation() {
    local log_file="${1:-$LOG_FILE}"
    local max_size_mb="${2:-${MAX_LOG_SIZE:-50}}"
    local keep_count="${3:-${LOG_ROTATION_COUNT:-5}}"
    
    # Convert MB to bytes for size comparison
    local max_size_bytes=$((max_size_mb * 1024 * 1024))
    
    # Check if log file exists and needs rotation
    if [[ -f "$log_file" ]]; then
        local current_size
        current_size=$(stat -c%s "$log_file" 2>/dev/null || echo 0)
        
        if (( current_size > max_size_bytes )); then
            log "Log file size (${current_size} bytes) exceeds limit, rotating logs"
            rotate_logs "$log_file" "$keep_count"
        fi
    fi
    
    # Ensure log directory exists
    local log_dir
    log_dir=$(dirname "$log_file")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || {
            error "Failed to create log directory: $log_dir"
            return 1
        }
    fi
}

# Rotate log files
rotate_logs() {
    local log_file="$1"
    local keep_count="${2:-5}"
    
    # Remove oldest log if we've reached the limit
    local oldest_log="${log_file}.$((keep_count - 1))"
    [[ -f "$oldest_log" ]] && rm -f "$oldest_log"
    
    # Rotate existing logs
    for (( i = keep_count - 2; i >= 1; i-- )); do
        local current_log="${log_file}.$i"
        local next_log="${log_file}.$((i + 1))"
        
        if [[ -f "$current_log" ]]; then
            mv "$current_log" "$next_log"
        fi
    done
    
    # Move current log to .1
    if [[ -f "$log_file" ]]; then
        mv "$log_file" "${log_file}.1"
        log "Rotated log file: $log_file -> ${log_file}.1"
    fi
    
    # Compress old logs to save space (if gzip is available)
    if command -v gzip >/dev/null 2>&1; then
        for (( i = 2; i < keep_count; i++ )); do
            local log_to_compress="${log_file}.$i"
            if [[ -f "$log_to_compress" && ! -f "${log_to_compress}.gz" ]]; then
                gzip "$log_to_compress" 2>/dev/null || true
            fi
        done
    fi
}

# Initialize logging system
init_logging() {
    local log_file="${LOG_FILE:-${HOME}/Documents/system_maint.log}"
    
    # Setup log rotation before starting
    setup_log_rotation "$log_file"
    
    # Redirect output to log file
    exec > >(tee -a "$log_file") 2>&1
    
    # Log session start
    echo -e "\n========== SYSTEM MAINTENANCE RUN: $(date) =========="
    log "xanadOS Clean v2.0.0 starting"
    log "Log file: $log_file"
    log "PID: $$"
    log "User: $(whoami)"
    log "Working directory: $(pwd)"
}

# Progress management
show_progress() {
    local desc=$1
    ((++CURRENT_STEP))
    local width=30
    local filled=$((CURRENT_STEP * width / TOTAL_STEPS))
    local empty=$((width - filled))
    local bar
    bar=$(printf '%0.s#' $(seq 1 "$filled"))
    bar+=$(printf '%0.s-' $(seq 1 "$empty"))
    printf '%b[%s] (%d/%d) %s%b\n' "${CYAN}" "$bar" "$CURRENT_STEP" "$TOTAL_STEPS" "$desc" "${NC}"
}

# Banner display
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

# Error trap handler
err_trap() {
    error "Command '$BASH_COMMAND' failed at line ${BASH_LINENO[0]}"
    exit 1
}

# Set up error handling
setup_error_handling() {
    set -euo pipefail
    IFS=$'\n\t'
    trap err_trap ERR
}

# Step execution with progress tracking
run_step() {
    local func=$1
    local desc=$2
    
    # Check if step should be skipped due to user choice
    if [[ "${ASK_EACH:-false}" == "true" ]]; then
        read -rp $"\nRun ${desc}? [Y/n] " ans
        if [[ ${ans,,} =~ ^n ]]; then
            summary "Skipped: ${desc}"
            return 0
        fi
    fi
    
    # Show progress and execute
    show_progress "$desc"
    
    # Use enhanced step execution if available, otherwise basic execution
    if command -v run_step_with_recovery >/dev/null 2>&1; then
        run_step_with_recovery "$func" "$desc"
    elif command -v run_step_monitored >/dev/null 2>&1; then
        run_step_monitored "$func" "$desc"
    else
        # Basic execution
        if "$func"; then
            summary "✓ $desc"
            return 0
        else
            local exit_code=$?
            error "Step failed: $desc"
            return $exit_code
        fi
    fi
}

# Enhanced argument parsing with validation
parse_arguments() {
    # Validate we have bash 4+ for associative arrays
    if (( BASH_VERSINFO[0] < 4 )); then
        error "This script requires Bash 4.0 or higher"
        exit 1
    fi
    
    local config_file_specified=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -a|--auto)
                AUTO_MODE=true
                log "Enabled automatic mode"
                ;;
            -s|--simple)
                export SIMPLE_MODE=true
                AUTO_MODE=true
                log "Running in simple mode - basic maintenance only"
                ;;
            -t|--test-mode)
                export TEST_MODE=true
                log "Running in test mode - no actual changes will be made"
                ;;
            --ask-each)
                ASK_EACH=true
                log "Will prompt before each maintenance step"
                ;;
            --config)
                if [[ -n "${2:-}" ]]; then
                    # Validate config file exists and is readable
                    if [[ ! -f "$2" ]]; then
                        error "Config file does not exist: $2"
                        exit 1
                    fi
                    if [[ ! -r "$2" ]]; then
                        error "Config file is not readable: $2"
                        exit 1
                    fi
                    export CONFIG_FILE="$2"
                    config_file_specified=true
                    log "Using custom config file: $2"
                    shift
                else
                    error "Error: --config requires a file path"
                    exit 1
                fi
                ;;
            --create-config)
                create_default_config
                exit 0
                ;;
            --show-config)
                if command -v display_config >/dev/null 2>&1; then
                    display_config
                else
                    error "Configuration system not loaded"
                fi
                exit 0
                ;;
            --recovery)
                if command -v resume_from_checkpoint >/dev/null 2>&1; then
                    resume_from_checkpoint
                else
                    error "Recovery system not available"
                fi
                exit 0
                ;;
            --performance)
                if command -v generate_performance_report >/dev/null 2>&1; then
                    generate_performance_report
                else
                    error "Performance monitoring not available"
                fi
                exit 0
                ;;
            --*)
                error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                error "Unknown argument: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
    
    # Validate argument combinations
    validate_argument_combinations "$config_file_specified"
}

# Validate argument combinations for conflicts
validate_argument_combinations() {
    local config_specified="$1"
    
    # Simple mode conflicts with ask-each
    if [[ "${SIMPLE_MODE:-false}" == "true" && "${ASK_EACH:-false}" == "true" ]]; then
        warning "Simple mode automatically runs without prompts, ignoring --ask-each"
        ASK_EACH=false
    fi
    
    # Auto mode conflicts with ask-each
    if [[ "${AUTO_MODE:-false}" == "true" && "${ASK_EACH:-false}" == "true" ]]; then
        warning "Auto mode runs without prompts, ignoring --ask-each"
        ASK_EACH=false
    fi
    
    # Test mode validation
    if [[ "${TEST_MODE:-false}" == "true" ]]; then
        log "Test mode enabled - all operations will be simulated"
    fi
    
    # Config file validation
    if [[ "$config_specified" == "true" ]]; then
        log "Custom configuration will override default settings"
    fi
}

# Help display
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

xanadOS Clean v2.0.0 - Professional Arch Linux system maintenance

OPTIONS:
    -h, --help              Show this help message
    -v, --version           Show version information
    -a, --auto              Run in automatic mode (non-interactive)
    -s, --simple            Simple mode - basic maintenance only (auto-enabled)
    -t, --test-mode         Dry-run mode (no actual changes)
    --ask-each             Prompt before each maintenance step
    --config FILE          Use custom configuration file
    --create-config        Create default configuration file
    --show-config          Display current configuration
    --recovery             Run recovery procedures for failed operations
    --performance          Generate detailed performance report

EXAMPLES:
    $0                     # Interactive mode
    $0 --auto              # Automatic mode
    $0 --simple            # Simple mode (basic maintenance)
    $0 --config ~/.my.conf # Use custom config
    $0 --test-mode         # Dry run to see what would be done

CONFIGURATION:
    Config files are searched in this order:
    1. \${XDG_CONFIG_HOME}/xanados_clean/config.conf
    2. \${HOME}/.xanados_clean.conf
    3. /etc/xanados_clean/config.conf
    4. config/default.conf

LOGS:
    Default log location: ~/Documents/system_maint.log

For detailed documentation, see:
    docs/USER_GUIDE.md      - Complete usage instructions
    docs/DEVELOPER_GUIDE.md - API reference and development

EOF
}

# Version display
show_version() {
    cat << EOF
xanadOS Clean v2.0.0

Professional-grade maintenance automation for Arch Linux systems.

Features:
- Configuration management
- Error recovery system
- Performance monitoring  
- Comprehensive testing
- Arch Linux optimizations

Copyright (C) 2025 xanadOS Project
Licensed under GPL-3.0

For more information: https://github.com/asafelobotomy/xanados_clean
EOF
}

# Initialize core systems
init_core_systems() {
    # Set up error handling
    setup_error_handling
    
    # Initialize summary log
    SUMMARY_LOG=()
    
    # Reset step counter
    CURRENT_STEP=0
    
    log "Core systems initialized"
}

# Final summary display
final_summary() {
    # Prominent completion banner
    printf "\n"
    printf "╔═══════════════════════════════════════════════════════════════╗\n"
    printf "║  %b🎉 XANADOS SYSTEM MAINTENANCE COMPLETED SUCCESSFULLY! 🎉%b  ║\n" "$GREEN" "$NC"
    printf "╚═══════════════════════════════════════════════════════════════╝\n"
    printf "\n"
    
    # Status indicator
    printf "%b✅ STATUS: ALL OPERATIONS COMPLETED%b\n" "$GREEN" "$NC"
    printf "%b📅 FINISHED: %s%b\n" "$BLUE" "$(date '+%Y-%m-%d %H:%M:%S')" "$NC"
    
    if (( ${#SUMMARY_LOG[@]} > 0 )); then
        printf "\n%b📋 OPERATIONS PERFORMED (%d total):%b\n" "$BLUE" "${#SUMMARY_LOG[@]}" "$NC"
        for item in "${SUMMARY_LOG[@]}"; do
            printf "  ✓ %s\n" "$item"
        done
    fi
    
    # Show additional information if enhanced systems are available
    if command -v enhanced_final_summary >/dev/null 2>&1; then
        enhanced_final_summary
    else
        printf "\n%b📁 LOG FILE:%b\n" "$CYAN" "$NC"
        printf "  • Full details: %s\n" "${LOG_FILE:-~/Documents/system_maint.log}"
        
        # Check for reboot requirement
        if [[ -f /var/run/reboot-required ]]; then
            printf "\n%b⚠️  REBOOT RECOMMENDED:%b\n" "$YELLOW" "$NC"
            printf "  • System updates require restart\n"
            printf "  • Run: sudo reboot\n"
        fi
        
        # Final success message
        printf "\n"
        printf "┌─────────────────────────────────────────────────────────────┐\n"
        printf "│ %bYour xanadOS system is now optimized and secure! 🚀%b        │\n" "$GREEN" "$NC"
        printf "│ All maintenance tasks completed without errors.             │\n"
        printf "└─────────────────────────────────────────────────────────────┘\n"
        printf "\n"
    fi
}

# Create default configuration file
create_default_config() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xanados_clean"
    local config_file="$config_dir/config.conf"
    
    if [[ -f "$config_file" ]]; then
        read -rp "Configuration file exists at $config_file. Overwrite? [y/N] " overwrite
        if [[ ! ${overwrite,,} =~ ^y ]]; then
            log "Configuration creation cancelled"
            return 0
        fi
    fi
    
    mkdir -p "$config_dir"
    
    # Copy default configuration if available
    if [[ -f "${SCRIPT_DIR:-}/config/default.conf" ]]; then
        cp "${SCRIPT_DIR:-}/config/default.conf" "$config_file"
        log "Configuration file created at: $config_file"
        log "Edit this file to customize settings"
    else
        # Create basic configuration
        cat > "$config_file" << 'EOF'
# xanadOS Clean Configuration File
# Copy this file to ~/.config/xanados_clean/config.conf

# General Settings
LOG_FILE="${HOME}/Documents/system_maint.log"
AUTO_MODE=false
ASK_EACH_STEP=false

# Backup Settings  
BACKUP_METHOD=auto
BACKUP_SKIP_THRESHOLD_DAYS=30

# Feature Toggles
ENABLE_FLATPAK=auto
ENABLE_SECURITY_SCAN=true
ENABLE_ORPHAN_REMOVAL=true
ENABLE_CACHE_CLEANUP=true
ENABLE_BTRFS_MAINTENANCE=auto
ENABLE_SSD_TRIM=auto
ENABLE_ARCH_OPTIMIZATIONS=true

# Performance & Recovery
ENABLE_PERFORMANCE_MONITORING=true
ENABLE_ERROR_RECOVERY=true
EOF
        log "Basic configuration file created at: $config_file"
    fi
}

# Utility functions for common operations
check_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

is_root() {
    [[ $EUID -eq 0 ]]
}

has_sudo() {
    sudo -n true 2>/dev/null
}

# Package manager detection and setup
setup_package_manager() {
    if ! check_command pacman; then
        error "pacman is required. This script only runs on Arch Linux."
        exit 1
    fi
    
    # Set up sudo command
    if is_root; then
        SUDO=""
        USER_CMD=()
    else
        if ! has_sudo; then
            error "Please run this script as a regular user with sudo access."
            exit 1
        fi
        SUDO="sudo"
        USER_CMD=()
    fi
    
    # Choose package manager
    if [[ "${AUTO_MODE:-false}" == "true" ]]; then
        if check_command paru; then
            PKG_MGR="paru"
        elif check_command yay; then
            PKG_MGR="yay" 
        else
            PKG_MGR="pacman"
        fi
    else
        choose_pkg_manager
    fi
    
    log "Package manager: $PKG_MGR"
}

# Interactive package manager selection
choose_pkg_manager() {
    if check_command paru; then
        read -rp "Use paru for AUR packages? [Y/n] " use_paru
        if [[ ! ${use_paru,,} =~ ^n ]]; then
            PKG_MGR="paru"
            return
        fi
    fi
    
    if check_command yay; then
        read -rp "Use yay for AUR packages? [Y/n] " use_yay
        if [[ ! ${use_yay,,} =~ ^n ]]; then
            PKG_MGR="yay"
            return
        fi
    fi
    
    PKG_MGR="pacman"
}

# Package manager command wrapper
pkg_mgr_run() {
    if [[ "$PKG_MGR" == "pacman" ]]; then
        ${SUDO} pacman "$@"
    else
        "${USER_CMD[@]}" "$PKG_MGR" "$@"
    fi
}

# Export core functions for use by other modules
export -f log error warning summary show_progress print_banner
export -f run_step parse_arguments show_help show_version
export -f final_summary check_command is_root has_sudo
export -f setup_package_manager choose_pkg_manager pkg_mgr_run
export -f init_core_systems create_default_config

# Export variables
export SUDO PKG_MGR
