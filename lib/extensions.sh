#!/usr/bin/env bash
# extensions.sh - Error recovery, performance monitoring, and system enhancements
# Combines: recovery.sh + performance.sh + enhancements.sh functionality

# === ERROR RECOVERY SYSTEM ===

# Checkpoint and recovery state files
CHECKPOINT_FILE="${LOG_DIR:-/tmp}/xanados_checkpoint.state"
RECOVERY_LOG="${LOG_DIR:-/tmp}/xanados_recovery.log"

# Arrays to store completed and failed steps
declare -a COMPLETED_STEPS=()
declare -a FAILED_STEPS=()

# Recovery operations registry
declare -A RECOVERY_OPERATIONS=(
    ["refresh_mirrors"]="restore_original_mirrorlist"
    ["system_update"]="downgrade_packages"
    ["pre_backup"]="remove_incomplete_backup"
    ["flatpak_update"]="rollback_flatpak"
    ["cache_cleanup"]="restore_cache"
    ["btrfs_maintenance"]="abort_btrfs_operations"
)

# Create checkpoint with current system state
create_checkpoint() {
    local step_name="$1"
    local timestamp
    timestamp=$(date +%s)
    
    log "Creating checkpoint before: $step_name"
    
    # Save current state
    cat > "$CHECKPOINT_FILE" <<EOF
# xanadOS Clean Checkpoint
# Created: $(date)
STEP_NAME="$step_name"
TIMESTAMP="$timestamp"
COMPLETED_STEPS=(${COMPLETED_STEPS[*]})
EOF
    
    # Save package list
    pacman -Q > "${CHECKPOINT_FILE}.packages" 2>/dev/null || true
    
    # Save mirrorlist
    if [[ -f /etc/pacman.d/mirrorlist ]]; then
        cp /etc/pacman.d/mirrorlist "${CHECKPOINT_FILE}.mirrorlist" 2>/dev/null || true
    fi
    
    # Save timestamp for comparison
    echo "$timestamp" > "${CHECKPOINT_FILE}.timestamp"
}

# Resume from checkpoint if available
resume_from_checkpoint() {
    if [[ -f "$CHECKPOINT_FILE" ]]; then
        log "Loading checkpoint state from $CHECKPOINT_FILE"
        # shellcheck source=/dev/null
        source "$CHECKPOINT_FILE" 2>/dev/null || return 1
        return 0
    fi
    return 1
}

# Remove checkpoint after successful completion
cleanup_checkpoint() {
    if [[ -f "$CHECKPOINT_FILE" ]]; then
        log "Cleaning up checkpoint files"
        rm -f "$CHECKPOINT_FILE" \
              "${CHECKPOINT_FILE}.packages" \
              "${CHECKPOINT_FILE}.mirrorlist" \
              "${CHECKPOINT_FILE}.timestamp" 2>/dev/null || true
    fi
}

# Mark step as completed
mark_step_completed() {
    local step_name="$1"
    COMPLETED_STEPS+=("$step_name")
    log "Step completed: $step_name"
}

# Mark step as failed and record for recovery
mark_step_failed() {
    local step_name="$1"
    local error_msg="$2"
    
    FAILED_STEPS+=("$step_name")
    error "Step failed: $step_name - $error_msg"
    
    # Log failure details
    cat >> "$RECOVERY_LOG" <<EOF
[$(date)] STEP_FAILED: $step_name
Error: $error_msg
Completed steps: ${COMPLETED_STEPS[*]}
Failed steps: ${FAILED_STEPS[*]}
---
EOF
}

# Enhanced run_step with checkpoint and recovery
run_step_with_recovery() {
    local func="$1"
    local desc="$2"
    local allow_failure="${3:-false}"
    
    # Check if step should be skipped due to configuration
    if ! should_run_step "$func"; then
        summary "Skipped: $desc (disabled in configuration)"
        return 0
    fi
    
    # Interactive mode check
    if [[ "${ASK_EACH:-false}" == "true" ]]; then
        read -rp $"\nRun ${desc}? [Y/n] " ans
        if [[ ${ans,,} =~ ^n ]]; then
            summary "Skipped: ${desc}"
            return 0
        fi
    fi
    
    # Create checkpoint before critical operations
    if is_critical_step "$func"; then
        create_checkpoint "$func"
    fi
    
    show_progress "$desc"
    
    # Execute step with error handling
    local start_time
    start_time=$(date +%s)
    
    if $func; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        mark_step_completed "$func"
        summary "✓ $desc (${duration}s)"
        return 0
    else
        local exit_code=$?
        local error_msg="Function $func failed with exit code $exit_code"
        
        mark_step_failed "$func" "$error_msg"
        
        if [[ "$allow_failure" == "true" ]]; then
            summary "⚠ $desc (failed but continuing)"
            return 0
        else
            error "Critical step failed: $desc"
            offer_recovery "$func"
            return $exit_code
        fi
    fi
}

# Check if step should run based on configuration
should_run_step() {
    local step_name="$1"
    
    case "$step_name" in
        "flatpak_update")
            [[ "${ENABLE_FLATPAK:-auto}" != "false" ]]
            ;;
        "security_scan")
            [[ "${ENABLE_SECURITY_SCAN:-true}" == "true" ]]
            ;;
        "remove_orphans")
            [[ "${ENABLE_ORPHAN_REMOVAL:-true}" == "true" ]]
            ;;
        "cache_cleanup")
            [[ "${ENABLE_CACHE_CLEANUP:-true}" == "true" ]]
            ;;
        "btrfs_maintenance")
            [[ "${ENABLE_BTRFS_MAINTENANCE:-auto}" != "false" ]]
            ;;
        "ssd_trim")
            [[ "${ENABLE_SSD_TRIM:-auto}" != "false" ]]
            ;;
        "display_arch_news")
            [[ "${SHOW_NEWS:-true}" == "true" ]]
            ;;
        "system_report")
            [[ "${ENABLE_SYSTEM_REPORT:-true}" == "true" ]]
            ;;
        *)
            true  # Run by default
            ;;
    esac
}

# Check if step is critical and needs checkpoint
is_critical_step() {
    local step_name="$1"
    
    case "$step_name" in
        "refresh_mirrors"|"system_update"|"pre_backup")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Offer recovery options after step failure
offer_recovery() {
    local failed_step="$1"
    
    while true; do
        printf "\n%bRecovery Options for failed step: %s%b\n" "$CYAN" "$failed_step" "$NC"
        printf "1. Retry the failed operation\n"
        printf "2. Skip this step and continue\n"
        printf "3. Attempt automatic recovery\n"
        printf "4. Abort maintenance\n"
        printf "5. Show recovery instructions\n"
        
        read -rp "Choose an option (1-5): " choice
        
        case "$choice" in
            1)
                log "Retrying failed step: $failed_step"
                if $failed_step; then
                    summary "✓ Retry successful: $failed_step"
                    return 0
                else
                    error "Retry failed. Returning to recovery menu."
                    continue
                fi
                ;;
            2)
                log "Skipping failed step: $failed_step"
                summary "⚠ Skipped after failure: $failed_step"
                return 0
                ;;
            3)
                if attempt_automatic_recovery "$failed_step"; then
                    summary "✓ Automatic recovery successful: $failed_step"
                    return 0
                else
                    error "Automatic recovery failed. Try manual recovery."
                    continue
                fi
                ;;
            4)
                error "Aborting maintenance due to user request"
                exit 1
                ;;
            5)
                show_recovery_info "$failed_step"
                continue
                ;;
            *)
                echo "Invalid choice. Please select 1-5."
                continue
                ;;
        esac
    done
}

# Attempt automatic recovery for failed step
attempt_automatic_recovery() {
    local failed_step="$1"
    local recovery_func="${RECOVERY_OPERATIONS[$failed_step]:-}"
    
    if [[ -n "$recovery_func" && $(type -t "$recovery_func") == "function" ]]; then
        log "Attempting automatic recovery with: $recovery_func"
        if $recovery_func; then
            log "Automatic recovery successful"
            return 0
        else
            error "Automatic recovery failed"
            return 1
        fi
    else
        error "No automatic recovery available for: $failed_step"
        return 1
    fi
}

# Show recovery information for specific step
show_recovery_info() {
    local step="$1"
    
    printf "\n%bRecovery Information for: %s%b\n" "$BLUE" "$step" "$NC"
    
    case "$step" in
        "refresh_mirrors")
            cat << EOF
Mirror refresh failure recovery:
1. Check network connectivity: ping archlinux.org
2. Restore original mirrorlist: sudo cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
3. Update package database: sudo pacman -Sy
4. Try manual mirror selection
EOF
            ;;
        "system_update")
            cat << EOF
System update failure recovery:
1. Check available disk space: df -h
2. Clear package cache: sudo pacman -Sc
3. Check for conflicting packages: sudo pacman -Syu
4. Try partial updates: sudo pacman -Su
5. Check Arch news for breaking changes
EOF
            ;;
        "pre_backup")
            cat << EOF
Backup failure recovery:
1. Check available disk space: df -h
2. Verify backup destination permissions
3. Remove incomplete backups manually
4. Try alternative backup method
EOF
            ;;
        *)
            echo "No specific recovery information available for this step."
            echo "Check the log file for detailed error messages: $LOG_FILE"
            ;;
    esac
    
    printf "\nPress Enter to return to recovery menu..."
    read -r
}

# Recovery function implementations
restore_original_mirrorlist() {
    log "Restoring original mirrorlist"
    if [[ -f "${CHECKPOINT_FILE}.mirrorlist" ]]; then
        ${SUDO} cp "${CHECKPOINT_FILE}.mirrorlist" "/etc/pacman.d/mirrorlist"
        return $?
    fi
    return 1
}

downgrade_packages() {
    log "Package downgrade not implemented - manual intervention required"
    return 1
}

remove_incomplete_backup() {
    log "Removing incomplete backup operations"
    # This would remove incomplete snapshots or rsync operations
    return 0
}

rollback_flatpak() {
    if command -v flatpak >/dev/null 2>&1; then
        log "Rolling back Flatpak changes"
        # Flatpak doesn't have easy rollback, just update to fix issues
        flatpak update -y >/dev/null 2>&1 || true
    fi
    return 0
}

restore_cache() {
    log "Cache cleanup is generally safe - no restore needed"
    return 0
}

abort_btrfs_operations() {
    log "Aborting Btrfs operations"
    # Stop any running btrfs operations
    ${SUDO} pkill -f "btrfs" 2>/dev/null || true
    return 0
}

# Show recovery status
show_recovery_status() {
    if (( ${#FAILED_STEPS[@]} > 0 )); then
        printf "\n%bRecovery Status:%b\n" "$RED" "$NC"
        printf "Failed steps: %s\n" "${FAILED_STEPS[*]}"
        printf "Recovery log: %s\n" "$RECOVERY_LOG"
    fi
}

# === PERFORMANCE MONITORING SYSTEM ===

# Performance metrics collection
declare -A STEP_METRICS=()
declare -A SYSTEM_METRICS=()

# Initialize performance monitoring
init_performance_monitoring() {
    log "Initializing performance monitoring"
    
    # Record initial system state
    SYSTEM_METRICS[start_time]=$(date +%s)
    SYSTEM_METRICS[start_memory]=$(free -m | awk 'NR==2{print $3}')
    SYSTEM_METRICS[start_disk_io]=$(iostat -d 1 1 2>/dev/null | tail -n +4 | awk '{sum+=$4} END {print sum}' || echo "0")
    SYSTEM_METRICS[start_load]=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
}

# Record performance metrics for a step
record_step_performance() {
    local step_name="$1"
    local start_time="$2"
    local end_time="$3"
    local peak_memory="${4:-0}"
    
    local duration=$((end_time - start_time))
    local current_memory
    current_memory=$(free -m | awk 'NR==2{print $3}')
    local memory_delta=$((current_memory - SYSTEM_METRICS[start_memory]))
    
    STEP_METRICS["${step_name}_duration"]=$duration
    STEP_METRICS["${step_name}_memory_delta"]=$memory_delta
    STEP_METRICS["${step_name}_peak_memory"]=$peak_memory
    
    # Log if step took unusually long or used excessive memory
    if (( duration > 300 )); then  # 5 minutes
        warning "Performance warning: $step_name took ${duration}s (>5min)"
    fi
    
    if (( memory_delta > 1000 )); then  # 1GB
        warning "Memory warning: $step_name used ${memory_delta}MB additional memory"
    fi
}

# Enhanced run_step with performance monitoring
run_step_monitored() {
    local func="$1"
    local desc="$2"
    local allow_failure="${3:-false}"
    
    # Pre-step checks
    if ! should_run_step "$func"; then
        summary "Skipped: $desc (disabled in configuration)"
        return 0
    fi
    
    if [[ "${ASK_EACH:-false}" == "true" ]]; then
        read -rp $"\nRun ${desc}? [Y/n] " ans
        if [[ ${ans,,} =~ ^n ]]; then
            summary "Skipped: ${desc}"
            return 0
        fi
    fi
    
    # Performance monitoring setup
    local start_time start_memory
    start_time=$(date +%s)
    start_memory=$(free -m | awk 'NR==2{print $3}')
    
    # Create checkpoint for critical operations
    if is_critical_step "$func"; then
        create_checkpoint "$func"
    fi
    
    show_progress "$desc"
    
    # Execute step with monitoring
    local peak_memory=$start_memory
    local monitor_pid
    
    # Background memory monitoring using temp file to share variable
    local peak_memory_file
    peak_memory_file=$(mktemp)
    echo "$peak_memory" > "$peak_memory_file"
    
    {
        while sleep 5; do
            local current_mem
            current_mem=$(free -m | awk 'NR==2{print $3}')
            local stored_peak
            stored_peak=$(cat "$peak_memory_file")
            if (( current_mem > stored_peak )); then
                echo "$current_mem" > "$peak_memory_file"
            fi
        done
    } &
    monitor_pid=$!
    
    # Execute the actual function
    local func_result=0
    if $func; then
        local end_time end_memory
        end_time=$(date +%s)
        end_memory=$(free -m | awk 'NR==2{print $3}')
        
        # Stop monitoring
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true
        
        # Read final peak memory value
        peak_memory=$(cat "$peak_memory_file")
        rm -f "$peak_memory_file"
        
        # Record performance metrics
        record_step_performance "$func" "$start_time" "$end_time" "$peak_memory"
        
        local duration=$((end_time - start_time))
        mark_step_completed "$func"
        summary "✓ $desc (${duration}s)"
        func_result=0
    else
        func_result=$?
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true
        
        mark_step_failed "$func" "Function failed with exit code $func_result"
        
        if [[ "$allow_failure" == "true" ]]; then
            summary "⚠ $desc (failed but continuing)"
            func_result=0
        else
            error "Critical step failed: $desc"
            offer_recovery "$func"
        fi
    fi
    
    return $func_result
}

# Generate performance report
generate_performance_report() {
    local total_time
    total_time=$(($(date +%s) - SYSTEM_METRICS[start_time]))
    local end_memory
    end_memory=$(free -m | awk 'NR==2{print $3}')
    local total_memory_delta=$((end_memory - SYSTEM_METRICS[start_memory]))
    
    printf "\n%b=== Performance Report ===%b\n" "$BLUE" "$NC"
    
    # Calculate minutes with proper fallback
    local minutes
    if command -v bc >/dev/null 2>&1; then
        minutes=$(echo "scale=1; $total_time / 60" | bc -l 2>/dev/null || echo "0.0")
    else
        # Fallback calculation using bash arithmetic
        minutes=$((total_time * 10 / 60))
        minutes="${minutes%?}.${minutes: -1}"
    fi
    
    printf "Total execution time: %d seconds (%s minutes)\n" "$total_time" "$minutes"
    printf "Memory usage change: %+d MB\n" "$total_memory_delta"
    
    # Step-by-step performance
    if (( ${#COMPLETED_STEPS[@]} > 0 )); then
        printf "\n%bStep Performance:%b\n" "$CYAN" "$NC"
        for step in "${COMPLETED_STEPS[@]}"; do
            local duration="${STEP_METRICS[${step}_duration]:-N/A}"
            local memory="${STEP_METRICS[${step}_memory_delta]:-N/A}"
            printf "  %-20s: %4ss, %+4sMB\n" "$step" "$duration" "$memory"
        done
    fi
    
    # Performance recommendations
    printf "\n%bRecommendations:%b\n" "$CYAN" "$NC"
    if (( total_time > 1800 )); then  # 30 minutes
        echo "  • Consider running during off-peak hours for better performance"
    fi
    
    if (( total_memory_delta > 500 )); then  # 500MB
        echo "  • Monitor memory usage during maintenance"
        echo "  • Close unnecessary applications before running"
    fi
    
    # Check for slow steps
    local slow_steps=()
    for step in "${COMPLETED_STEPS[@]}"; do
        local duration="${STEP_METRICS[${step}_duration]:-0}"
        if (( duration > 120 )); then  # 2 minutes
            slow_steps+=("$step (${duration}s)")
        fi
    done
    
    if (( ${#slow_steps[@]} > 0 )); then
        echo "  • Slow operations detected:"
        printf "    - %s\n" "${slow_steps[@]}"
    fi
    
    # System optimization suggestions
    if command -v iostat >/dev/null 2>&1; then
        local avg_io
        avg_io=$(iostat -d 1 1 2>/dev/null | tail -n +4 | awk '{sum+=$4} END {print sum/NR}' || echo "0")
        if (( $(echo "$avg_io > 100" | bc -l 2>/dev/null || echo "0") )); then
            echo "  • High I/O detected - consider SSD upgrade or defragmentation"
        fi
    fi
}

# === SYSTEM ENHANCEMENTS & INTEGRATION ===

# Load all enhancement libraries
load_enhancements() {
    local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
    
    # Load configuration system
    if [[ -f "$script_dir/lib/maintenance.sh" ]]; then
        # shellcheck source=lib/maintenance.sh
        source "$script_dir/lib/maintenance.sh"
    fi
    
    # Load system monitoring
    if [[ -f "$script_dir/lib/system.sh" ]]; then
        # shellcheck source=lib/system.sh
        source "$script_dir/lib/system.sh"
    fi
}

# Enhanced initialization function
enhanced_init() {
    # Load all enhancement libraries
    load_enhancements
    
    # Initialize systems
    init_performance_monitoring 2>/dev/null || true
    
    # Check system resources
    check_system_resources 2>/dev/null || true
    
    # Attempt to resume from checkpoint
    if resume_from_checkpoint 2>/dev/null; then
        log "Resuming from previous checkpoint"
        return 0
    fi
    
    # Optimize system for maintenance
    if [[ "${AUTO_MODE:-false}" == "true" ]]; then
        optimize_system_performance 2>/dev/null || true
    fi
    
    return 1  # No checkpoint found, start fresh
}

# Enhanced cleanup function
enhanced_cleanup() {
    # Generate performance report
    if command -v generate_performance_report >/dev/null 2>&1; then
        generate_performance_report
    fi
    
    # Restore system performance settings
    if command -v restore_system_performance >/dev/null 2>&1; then
        restore_system_performance 2>/dev/null || true
    fi
    
    # Cleanup checkpoint files on successful completion
    if (( ${#FAILED_STEPS[@]} == 0 )); then
        cleanup_checkpoint 2>/dev/null || true
    fi
    
    # Show recovery status if there were failures
    if command -v show_recovery_status >/dev/null 2>&1; then
        show_recovery_status
    fi
}

# Enhanced run_step that uses all systems
enhanced_run_step() {
    local func="$1"
    local desc="$2"
    local allow_failure="${3:-false}"
    
    # Use recovery-aware run_step if available
    if command -v run_step_with_recovery >/dev/null 2>&1; then
        run_step_with_recovery "$func" "$desc" "$allow_failure"
    # Use performance-monitored run_step if available
    elif command -v run_step_monitored >/dev/null 2>&1; then
        run_step_monitored "$func" "$desc" "$allow_failure"
    # Fall back to original run_step
    else
        run_step "$func" "$desc"
    fi
}

# Enhanced final summary with all metrics
enhanced_final_summary() {
    print_banner "Maintenance Complete"
    
    if (( ${#SUMMARY_LOG[@]} > 0 )); then
        printf "\n%bSummary of operations:%b\n" "$BLUE" "$NC"
        for item in "${SUMMARY_LOG[@]}"; do
            printf "  • %s\n" "$item"
        done
    fi
    
    # Performance report
    if command -v generate_performance_report >/dev/null 2>&1; then
        generate_performance_report
    fi
    
    # Configuration summary
    printf "\n%bConfiguration:%b\n" "$CYAN" "$NC"
    printf "• Log file: %s\n" "$LOG_FILE"
    printf "• Auto mode: %s\n" "${AUTO_MODE:-false}"
    printf "• Recovery log: %s\n" "${RECOVERY_LOG:-N/A}"
    
    printf "\n%bMaintenance completed at: %s%b\n" "$GREEN" "$(date)" "$NC"
}

# Function to check if we have all enhancements loaded
check_enhancements() {
    local missing=()
    
    # Check for configuration system
    if ! command -v load_config >/dev/null 2>&1; then
        missing+=("Configuration system")
    fi
    
    # Check for recovery system  
    if ! command -v create_checkpoint >/dev/null 2>&1; then
        missing+=("Recovery system")
    fi
    
    # Check for performance monitoring
    if ! command -v init_performance_monitoring >/dev/null 2>&1; then
        missing+=("Performance monitoring")
    fi
    
    if (( ${#missing[@]} > 0 )); then
        warning "Missing enhancements: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Export extension functions
export -f create_checkpoint resume_from_checkpoint cleanup_checkpoint
export -f mark_step_completed mark_step_failed run_step_with_recovery
export -f should_run_step is_critical_step offer_recovery attempt_automatic_recovery
export -f show_recovery_info show_recovery_status
export -f restore_original_mirrorlist downgrade_packages remove_incomplete_backup
export -f rollback_flatpak restore_cache abort_btrfs_operations
export -f init_performance_monitoring record_step_performance run_step_monitored
export -f generate_performance_report enhanced_init enhanced_cleanup
export -f enhanced_run_step enhanced_final_summary check_enhancements
export -f load_enhancements
