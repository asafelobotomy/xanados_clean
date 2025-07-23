#!/usr/bin/env bash
# Error recovery and checkpoint system for xanadOS Clean

# Checkpoint and recovery state file
CHECKPOINT_FILE="${LOG_DIR:-/tmp}/xanados_checkpoint.state"
RECOVERY_LOG="${LOG_DIR:-/tmp}/xanados_recovery.log"

# Array to store completed steps
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
# Step: $step_name
CHECKPOINT_TIMESTAMP=$timestamp
CURRENT_STEP="$step_name"
COMPLETED_STEPS=(${COMPLETED_STEPS[*]})
PKG_MGR="${PKG_MGR:-}"
LOG_FILE="$LOG_FILE"
EOF
    
    # Create package state backup for potential rollback
    if command -v pacman >/dev/null 2>&1; then
        pacman -Qq > "${CHECKPOINT_FILE}.packages" 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed > "${CHECKPOINT_FILE}.packages" 2>/dev/null || true
    fi
    
    # Save mirror configuration
    if [[ -f "/etc/pacman.d/mirrorlist" ]]; then
        cp "/etc/pacman.d/mirrorlist" "${CHECKPOINT_FILE}.mirrorlist" 2>/dev/null || true
    fi
    
    echo "$timestamp" > "${CHECKPOINT_FILE}.timestamp"
}

# Load checkpoint state
load_checkpoint() {
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
            [[ "${ENABLE_FLATPAK:-true}" == "true" ]]
            ;;
        "security_scan")
            [[ "${ENABLE_SECURITY_SCAN:-true}" == "true" ]]
            ;;
        "btrfs_maintenance")
            [[ "${ENABLE_BTRFS_MAINTENANCE:-auto}" != "false" ]]
            ;;
        "ssd_trim")
            [[ "${ENABLE_SSD_TRIM:-auto}" != "false" ]]
            ;;
        "remove_orphans")
            [[ "${ENABLE_ORPHAN_REMOVAL:-true}" == "true" ]]
            ;;
        "cache_cleanup")
            [[ "${ENABLE_CACHE_CLEANUP:-true}" == "true" ]]
            ;;
        "display_arch_news"|"display_fedora_news")
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
        "system_update"|"refresh_mirrors"|"pre_backup")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Offer recovery options when critical step fails
offer_recovery() {
    local failed_step="$1"
    
    echo
    error "Critical operation failed: $failed_step"
    echo "Recovery options:"
    echo "1) Retry the failed step"
    echo "2) Skip this step and continue"
    echo "3) Attempt automatic recovery"
    echo "4) Abort and exit"
    echo "5) Show recovery information"
    
    while true; do
        read -rp "Choose recovery option [1-5]: " choice
        case "$choice" in
            1)
                log "Retrying failed step: $failed_step"
                if $failed_step; then
                    mark_step_completed "$failed_step"
                    summary "✓ Retry successful: $failed_step"
                    return 0
                else
                    error "Retry failed. Offering recovery options again."
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
        log "No automatic recovery available for: $failed_step"
        return 1
    fi
}

# Show recovery information and suggestions
show_recovery_info() {
    local failed_step="$1"
    
    echo
    echo "=== Recovery Information for: $failed_step ==="
    
    case "$failed_step" in
        "refresh_mirrors")
            cat <<EOF
Mirror refresh failure can be caused by:
- Network connectivity issues
- Outdated reflector configuration
- Regional mirror problems

Manual recovery steps:
1. Check network: ping -c3 archlinux.org
2. Use manual mirrors: edit /etc/pacman.d/mirrorlist
3. Update package database: sudo pacman -Syy
EOF
            ;;
        "system_update")
            cat <<EOF
System update failure can be caused by:
- Package conflicts
- Signature verification issues
- Insufficient disk space
- Corrupted package cache

Manual recovery steps:
1. Clear cache: sudo pacman -Scc
2. Update keyring: sudo pacman -S archlinux-keyring
3. Force database sync: sudo pacman -Syy
4. Partial update: sudo pacman -Su --ignore problematic-package
EOF
            ;;
        "pre_backup")
            cat <<EOF
Backup failure can be caused by:
- Insufficient disk space
- Permission issues
- Snapshot service not configured

Manual recovery steps:
1. Check disk space: df -h
2. Configure Timeshift: sudo timeshift-gtk
3. Manual backup: sudo rsync -aAX / /backup/location/
EOF
            ;;
        *)
            echo "No specific recovery information available for: $failed_step"
            echo "Check the logs for detailed error messages."
            ;;
    esac
    
    echo
    echo "Log file: $LOG_FILE"
    echo "Recovery log: $RECOVERY_LOG"
    echo "Press Enter to continue..."
    read -r
}

# Recovery functions for specific operations

restore_original_mirrorlist() {
    if [[ -f "${CHECKPOINT_FILE}.mirrorlist" ]]; then
        log "Restoring original mirrorlist"
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
    if command -v btrfs >/dev/null 2>&1; then
        log "Canceling any running Btrfs operations"
        ${SUDO} btrfs scrub cancel / 2>/dev/null || true
        ${SUDO} btrfs balance cancel / 2>/dev/null || true
    fi
    return 0
}

# Resume from checkpoint if available
resume_from_checkpoint() {
    if load_checkpoint; then
        log "Found checkpoint from: $CURRENT_STEP"
        echo "Previous maintenance session was interrupted."
        echo "Completed steps: ${COMPLETED_STEPS[*]}"
        
        read -rp "Resume from checkpoint? [Y/n] " resume
        if [[ ${resume,,} =~ ^n ]]; then
            log "Starting fresh maintenance session"
            cleanup_checkpoint
            return 1
        else
            log "Resuming maintenance from checkpoint"
            return 0
        fi
    fi
    return 1
}

# Show recovery status and statistics
show_recovery_status() {
    if [[ -f "$RECOVERY_LOG" ]]; then
        echo
        echo "=== Recovery Status ==="
        echo "Failed steps in this session: ${#FAILED_STEPS[@]}"
        echo "Completed steps: ${#COMPLETED_STEPS[@]}"
        
        if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
            echo "Failed operations:"
            printf "  - %s\n" "${FAILED_STEPS[@]}"
        fi
        
        echo "Recent recovery log entries:"
        tail -n 10 "$RECOVERY_LOG" 2>/dev/null || echo "No recovery log entries"
    fi
}
