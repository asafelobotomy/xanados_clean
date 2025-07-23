#!/usr/bin/env bash
# Integration script that loads all enhancements into the main scripts

# Source all library components
load_enhancements() {
    local script_dir="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
    
    # Load configuration system
    if [[ -f "$script_dir/lib/config.sh" ]]; then
        # shellcheck source=lib/config.sh
        source "$script_dir/lib/config.sh"
    fi
    
    # Load recovery system
    if [[ -f "$script_dir/lib/recovery.sh" ]]; then
        # shellcheck source=lib/recovery.sh  
        source "$script_dir/lib/recovery.sh"
    fi
    
    # Load performance monitoring
    if [[ -f "$script_dir/lib/performance.sh" ]]; then
        # shellcheck source=lib/performance.sh
        source "$script_dir/lib/performance.sh"
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

# Wrapper function to replace original run_step calls
run_step() {
    enhanced_run_step "$@"
}

# Enhanced final summary with all metrics
enhanced_final_summary() {
    print_banner "Maintenance Complete"
    
    local total_time
    total_time=$(($(date +%s) - ${SYSTEM_METRICS[start_time]:-$(date +%s)}))
    
    printf "%bSummary:%b\n" "$CYAN" "$NC"
    printf "• Total execution time: %dm %ds\n" $((total_time / 60)) $((total_time % 60))
    printf "• Completed steps: %d\n" "${#COMPLETED_STEPS[@]}"
    
    if (( ${#FAILED_STEPS[@]} > 0 )); then
        printf "• Failed steps: %d\n" "${#FAILED_STEPS[@]}"
        printf "%bFailed operations:%b\n" "$RED" "$NC"
        printf "  - %s\n" "${FAILED_STEPS[@]}"
    fi
    
    if (( ${#SUMMARY_LOG[@]} > 0 )); then
        printf "\n%bDetailed Summary:%b\n" "$CYAN" "$NC"
        printf "%s\n" "${SUMMARY_LOG[@]}"
    fi
    
    # Performance summary if available
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

# Override the original final_summary function
final_summary() {
    enhanced_final_summary
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
        log "⚠ Some enhancements not available: ${missing[*]}"
        log "Basic functionality will still work"
    else
        log "✓ All enhancements loaded successfully"
    fi
}

# Auto-load enhancements when this file is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Being sourced, load enhancements
    load_enhancements
    check_enhancements
fi
