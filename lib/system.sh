#!/usr/bin/env bash
# system.sh - System checks, requirements, and resource monitoring
# Contains: network checks, dependency verification, system monitoring
# License: GPL-3.0
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Network connectivity check
check_network() {
    ping -c1 -W2 archlinux.org >/dev/null 2>&1
}

# Verify required commands are available
require_pacman() {
    if ! command -v pacman >/dev/null 2>&1; then
        error "pacman is required. This script only runs on Arch Linux."
        exit 1
    fi
}

# Check system requirements and dependencies
dependency_check() {
    print_banner "Dependency Check"
    
    declare -A REQUIRED_PKGS=(
        [arch-audit]="Security vulnerability scanner"
        [rkhunter]="Rootkit scanner"
        [btrfs-progs]="Btrfs volume maintenance"
        [util-linux]="fstrim, lsblk, etc."
        [pciutils]="GPU/CPU detection"
        [lm_sensors]="Temperature monitoring"
        [smartmontools]="Drive health monitoring"
        [reflector]="Mirror optimization"
    )
    
    declare -A OPTIONAL_PKGS=(
        [timeshift]="System snapshots"
        [snapper]="Btrfs snapshots"
        [flatpak]="Flatpak package management"
        [paru]="AUR helper"
        [yay]="Alternative AUR helper"
        [informant]="Arch news notifications"
    )
    
    local missing_required=()
    local missing_optional=()
    
    # Check required packages
    for pkg in "${!REQUIRED_PKGS[@]}"; do
        if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
            missing_required+=("$pkg")
        fi
    done
    
    # Check optional packages
    for pkg in "${!OPTIONAL_PKGS[@]}"; do
        if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
            missing_optional+=("$pkg")
        fi
    done
    
    # Report missing required packages
    if (( ${#missing_required[@]} > 0 )); then
        warning "Missing required packages:"
        for pkg in "${missing_required[@]}"; do
            printf "  • %s - %s\n" "$pkg" "${REQUIRED_PKGS[$pkg]}"
        done
        
        if [[ "${AUTO_MODE:-false}" == "true" ]] || [[ "${XANADOS_AUTO_MODE:-false}" == "true" ]]; then
            # Use pre-collected preference from GUI or default to install
            local install_req="${XANADOS_INSTALL_MISSING:-Y}"
            if [[ ! ${install_req,,} =~ ^n ]]; then
                log "Installing missing required packages..."
                pkg_mgr_run -S --noconfirm "${missing_required[@]}"
            else
                log "Skipping installation of missing required packages per user preference"
            fi
        else
            read -rp "Install missing required packages? [Y/n] " install_req
            if [[ ! ${install_req,,} =~ ^n ]]; then
                pkg_mgr_run -S --noconfirm "${missing_required[@]}"
            fi
        fi
    fi
    
    # Report missing optional packages
    if (( ${#missing_optional[@]} > 0 )); then
        log "Optional packages available for enhanced functionality:"
        for pkg in "${missing_optional[@]}"; do
            printf "  • %s - %s\n" "$pkg" "${OPTIONAL_PKGS[$pkg]}"
        done
        
        if [[ "${AUTO_MODE:-false}" == "true" ]] || [[ "${XANADOS_AUTO_MODE:-false}" == "true" ]]; then
            # Use pre-collected preference from GUI or default to not install optional packages
            local install_opt="${XANADOS_INSTALL_OPTIONAL:-N}"
            if [[ ${install_opt,,} =~ ^y ]]; then
                log "Installing optional packages per user preference..."
                pkg_mgr_run -S --needed "${missing_optional[@]}"
            else
                log "Skipping optional packages per user preference"
            fi
        else
            read -rp "Install optional packages? [y/N] " install_opt
            if [[ ${install_opt,,} =~ ^y ]]; then
                pkg_mgr_run -S --needed "${missing_optional[@]}"
            fi
        fi
    fi
    
    # Set up disabled features list for missing tools
    DISABLED_FEATURES=()
    for pkg in "${missing_required[@]}" "${missing_optional[@]}"; do
        DISABLED_FEATURES+=("$pkg")
    done
    
    if (( ${#missing_required[@]} == 0 )); then
        summary "All required packages are present."
    else
        summary "Some required packages are missing - functionality may be limited."
    fi
}

# Check if tool needs updating (for security tools)
update_tool_if_outdated() {
    local tool="$1"
    local update_threshold=7 # days
    
    if ! command -v "$tool" >/dev/null 2>&1; then
        return 1
    fi
    
    # Check when tool was last updated
    local tool_date
    tool_date=$(pacman -Qi "$tool" 2>/dev/null | grep "Install Date" | awk -F: '{print $2}' | xargs)
    
    if [[ -n "$tool_date" ]]; then
        local tool_epoch
        tool_epoch=$(date -d "$tool_date" +%s 2>/dev/null || echo 0)
        local current_epoch
        current_epoch=$(date +%s)
        local days_old=$(( (current_epoch - tool_epoch) / 86400 ))
        
        if (( days_old > update_threshold )); then
            log "Updating $tool (${days_old} days old)"
            pkg_mgr_run -S --noconfirm "$tool"
        fi
    fi
}

# System resource monitoring
check_system_resources() {
    log "Checking system resources"
    
    # Check available memory
    local available_memory
    available_memory=$(free -m | awk 'NR==2{print $7}')
    if (( available_memory < 1000 )); then  # Less than 1GB
        warning "Low available memory: ${available_memory}MB"
        if [[ "${AUTO_MODE:-false}" == "true" ]] || [[ "${XANADOS_AUTO_MODE:-false}" == "true" ]]; then
            # Use pre-collected preference from GUI
            local continue_low_mem="${XANADOS_CONTINUE_LOW_RESOURCES:-N}"
            if [[ ! ${continue_low_mem,,} =~ ^y ]]; then
                error "Aborting due to low memory (per user preference)"
                exit 1
            else
                log "Continuing with low memory per user preference"
            fi
        else
            read -rp "Continue with low memory? [y/N] " continue_low_mem
            if [[ ! ${continue_low_mem,,} =~ ^y ]]; then
                error "Aborting due to low memory"
                exit 1
            fi
        fi
    fi
    
    # Check available disk space
    local available_space
    available_space=$(df / | awk 'NR==2{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    if (( available_gb < 5 )); then  # Less than 5GB
        warning "Low disk space: ${available_gb}GB available"
        if [[ "${AUTO_MODE:-false}" == "true" ]] || [[ "${XANADOS_AUTO_MODE:-false}" == "true" ]]; then
            # Use pre-collected preference from GUI
            local continue_low_space="${XANADOS_CONTINUE_LOW_RESOURCES:-N}"
            if [[ ! ${continue_low_space,,} =~ ^y ]]; then
                error "Aborting due to low disk space (per user preference)"
                exit 1
            else
                log "Continuing with low disk space per user preference"
            fi
        else
            read -rp "Continue with low disk space? [y/N] " continue_low_space
            if [[ ! ${continue_low_space,,} =~ ^y ]]; then
                error "Aborting due to low disk space"
                exit 1
            fi
        fi
    fi
    
    # Check system load
    local current_load
    current_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local cpu_count
    cpu_count=$(nproc)
    if command -v bc >/dev/null 2>&1; then
        if (( $(echo "$current_load > $cpu_count * 2" | bc -l) )); then
            warning "High system load: $current_load"
        fi
    fi
    
    log "System resources check completed"
}

# Hardware detection and optimization recommendations
detect_hardware() {
    log "Detecting hardware configuration"
    
    # Detect storage type (SSD vs HDD)
    local storage_info=()
    if command -v lsblk >/dev/null 2>&1; then
        while IFS= read -r line; do
            storage_info+=("$line")
        done < <(lsblk -rno NAME,ROTA | grep -E '^[a-z]+[a-z0-9]* ' | awk '$2 == 0 {print $1" (SSD)"} $2 == 1 {print $1" (HDD)"}')
    fi
    
    # Detect GPU
    local gpu_info=""
    if command -v lspci >/dev/null 2>&1; then
        gpu_info=$(lspci | grep -E "(VGA|3D|Display)" | head -1)
    fi
    
    # Detect CPU
    local cpu_info=""
    if [[ -f /proc/cpuinfo ]]; then
        cpu_info=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    fi
    
    # Store hardware info for optimization decisions
    export DETECTED_STORAGE=("${storage_info[@]}")
    export DETECTED_GPU="$gpu_info"
    export DETECTED_CPU="$cpu_info"
    
    if (( ${#storage_info[@]} > 0 )); then
        log "Storage detected: ${storage_info[*]}"
    fi
    if [[ -n "$gpu_info" ]]; then
        log "GPU detected: $gpu_info"
    fi
    if [[ -n "$cpu_info" ]]; then
        log "CPU detected: $cpu_info"
    fi
}

# System health monitoring
check_failed_services() {
    print_banner "Failed Services"
    
    local failed_services
    failed_services=$(systemctl --failed --no-legend --no-pager | awk '{print $1}')
    
    if [[ -n "$failed_services" ]]; then
        warning "Failed systemd services detected:"
        echo "$failed_services" | while read -r service; do
            printf "  • %s\n" "$service"
        done
        
        if [[ "${AUTO_MODE:-false}" == "true" ]] || [[ "${XANADOS_AUTO_MODE:-false}" == "true" ]]; then
            # Use pre-collected preference from GUI
            local show_details="${XANADOS_SHOW_DETAILS:-N}"
            if [[ ${show_details,,} =~ ^y ]]; then
                log "Showing detailed status for failed services per user preference"
                systemctl --failed
            else
                log "Skipping detailed service status per user preference"
            fi
        else
            read -rp "Show detailed status for failed services? [y/N] " show_details
            if [[ ${show_details,,} =~ ^y ]]; then
                systemctl --failed
            fi
        fi
        summary "⚠ Found failed systemd services"
    else
        summary "✓ No failed systemd services"
    fi
}

# Journal error analysis
check_journal_errors() {
    print_banner "Recent System Errors"
    
    local error_count
    error_count=$(journalctl -p 3 -b --no-pager | wc -l)
    
    if (( error_count > 0 )); then
        warning "Found $error_count error entries in journal"
        
        if [[ "${AUTO_MODE:-false}" != "true" ]]; then
            read -rp "Show recent error entries? [y/N] " show_errors
            if [[ ${show_errors,,} =~ ^y ]]; then
                journalctl -p 3 -xb | tail -n 20
            fi
        fi
        summary "⚠ Found $error_count journal errors"
    else
        summary "✓ No critical errors in journal"
    fi
}

# Filesystem-specific maintenance
btrfs_maintenance() {
    print_banner "Btrfs Maintenance"
    
    # Check if btrfs is in use
    local btrfs_mounts
    btrfs_mounts=$(mount | grep btrfs | awk '{print $3}')
    
    if [[ -z "$btrfs_mounts" ]]; then
        summary "No Btrfs filesystems detected - skipping"
        return 0
    fi
    
    if [[ " ${DISABLED_FEATURES[*]} " =~ " btrfs-progs " ]]; then
        warning "btrfs-progs not available - skipping Btrfs maintenance"
        return 0
    fi
    
    log "Btrfs filesystems detected: $btrfs_mounts"
    
    # Balance filesystem
    echo "$btrfs_mounts" | while read -r mount_point; do
        if [[ -n "$mount_point" ]]; then
            log "Balancing Btrfs filesystem: $mount_point"
            if ${SUDO} btrfs filesystem balance start -dusage=50 "$mount_point" 2>/dev/null; then
                log "✓ Balanced $mount_point"
            else
                warning "Could not balance $mount_point (may not need balancing)"
            fi
            
            # Scrub filesystem
            log "Scrubbing Btrfs filesystem: $mount_point"
            if ${SUDO} btrfs scrub start "$mount_point" >/dev/null 2>&1; then
                log "✓ Started scrub for $mount_point"
            else
                warning "Could not start scrub for $mount_point"
            fi
        fi
    done
    
    summary "Btrfs maintenance completed"
}

# SSD optimization
ssd_trim() {
    print_banner "SSD Optimization"
    
    # Find SSD mounts
    local ssd_mounts=()
    if command -v lsblk >/dev/null 2>&1; then
        mapfile -t ssd_mounts < <(lsblk -rno MOUNTPOINT,ROTA | awk '$1 != "" && $2 == 0 {print $1}')
    fi
    
    if (( ${#ssd_mounts[@]} == 0 )); then
        summary "No SSD drives detected - skipping TRIM"
        return 0
    fi
    
    log "SSD drives detected: ${ssd_mounts[*]}"
    
    # Perform TRIM on each SSD mount
    for mount_point in "${ssd_mounts[@]}"; do
        if [[ -n "$mount_point" ]]; then
            log "Running TRIM on: $mount_point"
            if ${SUDO} fstrim -v "$mount_point" 2>/dev/null; then
                log "✓ TRIM completed for $mount_point"
            else
                warning "TRIM failed for $mount_point"
            fi
        fi
    done
    
    summary "SSD TRIM operations completed"
}

# System temperature monitoring
check_temperatures() {
    if ! command -v sensors >/dev/null 2>&1; then
        return 0
    fi
    
    log "Checking system temperatures"
    
    local temp_output
    temp_output=$(sensors 2>/dev/null | grep -E "(Core|temp)" | head -5)
    
    if [[ -n "$temp_output" ]]; then
        echo "$temp_output" | while read -r line; do
            if [[ "$line" =~ \+([0-9]+)\. ]]; then
                local temp="${BASH_REMATCH[1]}"
                if (( temp > 80 )); then
                    warning "High temperature detected: $line"
                fi
            fi
        done
    fi
}

# Smart drive health check
check_drive_health() {
    if ! command -v smartctl >/dev/null 2>&1; then
        return 0
    fi
    
    log "Checking drive health"
    
    # Get list of drives
    local drives
    drives=$(lsblk -rno NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}')
    
    echo "$drives" | while read -r drive; do
        if [[ -n "$drive" ]]; then
            local health
            health=$(${SUDO} smartctl -H "$drive" 2>/dev/null | grep "SMART overall-health")
            if [[ "$health" =~ PASSED ]]; then
                log "✓ $drive: SMART health OK"
            elif [[ -n "$health" ]]; then
                warning "$drive: $health"
            fi
        fi
    done
}

# Memory usage analysis
analyze_memory_usage() {
    log "Analyzing memory usage"
    
    # Try multiple methods to get memory information
    local total_mem used_mem mem_info
    
    # Method 1: Use free command
    if command -v free >/dev/null 2>&1; then
        mem_info=$(free -m 2>/dev/null | awk 'NR==2{print $2 " " $3}')
        
        if [[ -n "$mem_info" ]]; then
            # Use array to safely parse the output
            local mem_array
            read -ra mem_array <<< "$mem_info"
            total_mem=${mem_array[0]:-0}
            used_mem=${mem_array[1]:-0}
        fi
    fi
    
    # Method 2: Fallback to /proc/meminfo if free failed
    if [[ -z "$total_mem" ]] || [[ "$total_mem" -eq 0 ]] && [[ -r /proc/meminfo ]]; then
        local memtotal memavailable
        memtotal=$(grep "^MemTotal:" /proc/meminfo | awk '{print int($2/1024)}')
        memavailable=$(grep "^MemAvailable:" /proc/meminfo | awk '{print int($2/1024)}')
        
        if [[ -n "$memtotal" && -n "$memavailable" ]]; then
            total_mem="$memtotal"
            used_mem=$((memtotal - memavailable))
        fi
    fi
    
    # Validate that we got numeric values
    if ! [[ "$total_mem" =~ ^[0-9]+$ ]] || ! [[ "$used_mem" =~ ^[0-9]+$ ]] || [[ "$total_mem" -eq 0 ]]; then
        warning "Could not parse memory information from available sources"
        log "Debug: total_mem='$total_mem', used_mem='$used_mem', mem_info='$mem_info'"
        return 1
    fi
    
    local usage_percent=$((used_mem * 100 / total_mem))
    
    if (( usage_percent > 90 )); then
        warning "High memory usage: ${usage_percent}% (${used_mem}MB/${total_mem}MB)"
        
        # Show top memory consumers
        if command -v ps >/dev/null 2>&1; then
            log "Top memory consumers:"
            ps aux --sort=-%mem 2>/dev/null | head -6 | awk 'NR>1{printf "  %s: %.1f%%\n", $11, $4}' || true
        fi
    else
        log "Memory usage: ${usage_percent}% (${used_mem}MB/${total_mem}MB)"
    fi
}

# Comprehensive system report
system_report() {
    print_banner "System Report"
    
    # Hardware information
    detect_hardware
    
    # Temperature check
    check_temperatures
    
    # Drive health
    check_drive_health
    
    # Memory analysis
    analyze_memory_usage
    
    # Kernel version
    log "Kernel: $(uname -r)"
    
    # System uptime
    log "Uptime: $(uptime -p 2>/dev/null || uptime)"
    
    # Package count
    local pkg_count
    pkg_count=$(pacman -Q | wc -l)
    log "Installed packages: $pkg_count"
    
    # Available updates
    if command -v checkupdates >/dev/null 2>&1; then
        local update_count
        update_count=$(checkupdates 2>/dev/null | wc -l)
        if (( update_count > 0 )); then
            log "Available updates: $update_count"
        else
            log "System is up to date"
        fi
    fi
    
    summary "System report completed"
}

# Initialize system monitoring
init_system_monitoring() {
    # Detect hardware configuration
    detect_hardware
    
    # Check system resources
    check_system_resources
    
    log "System monitoring initialized"
}

# Export system functions
export -f check_network require_pacman dependency_check update_tool_if_outdated
export -f check_system_resources detect_hardware check_failed_services
export -f check_journal_errors btrfs_maintenance ssd_trim system_report
export -f init_system_monitoring check_temperatures check_drive_health
export -f analyze_memory_usage
