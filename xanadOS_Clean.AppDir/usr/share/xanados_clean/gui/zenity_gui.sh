#!/bin/bash
# zenity_gui.sh - Native GUI for xanadOS Clean using Zenity
# Author: GitHub Copilot
# Version: 2.0.0

# Set up variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/../xanados_clean.sh"
# Use secure temporary directory creation
TEMP_DIR=$(mktemp -d -t xanados_clean.XXXXXX)
OUTPUT_FILE="${TEMP_DIR}/output.log"
PROGRESS_FILE="${TEMP_DIR}/progress.txt"
PID_FILE="${TEMP_DIR}/maintenance.pid"

# Create temp directory (already created by mktemp)
# mkdir -p "$TEMP_DIR" # Not needed with mktemp -d

# Cleanup function
cleanup() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
        fi
    fi
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Check for dependencies
check_dependencies() {
    local missing=()
    
    if ! command -v zenity >/dev/null 2>&1; then
        missing+=("zenity")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        zenity --error \
            --title="Missing Dependencies" \
            --text="The following packages are required but not installed:

$(printf "• %s\n" "${missing[@]}")

Please install them using your package manager:
sudo pacman -S ${missing[*]}" \
            --width=400
        exit 1
    fi
}

# Show welcome dialog
show_welcome() {
    zenity --info \
        --title="xanadOS Clean v2.0.0" \
        --text="Welcome to xanadOS Clean!

This tool will help you maintain your Arch Linux system with automated cleanup, updates, and optimizations.

• System updates and package management
• Cache cleanup and orphan removal  
• Security scans and maintenance
• BTRFS optimization and SSD trimming
• Performance monitoring

Click OK to continue to the configuration screen." \
        --width=500 \
        --height=300
}

# Configuration dialog
show_config_dialog() {
    local config
    config=$(zenity --forms \
        --title="xanadOS Clean - Configuration" \
        --text="Configure your maintenance session:" \
        --add-combo="Operation Mode:" --combo-values="Interactive|Automatic|Simple" \
        --add-combo="Safety Mode:" --combo-values="Test Mode (Safe)|Live Mode (Apply Changes)" \
        --add-combo="Verbosity:" --combo-values="Normal|Verbose|Quiet" \
        --add-combo="Backup:" --combo-values="Create Backup|Skip Backup" \
        --separator="|" \
        --width=500 \
        --height=350)
    
    if [[ $? -ne 0 ]]; then
        exit 0
    fi
    
    echo "$config"
}

# Parse configuration
parse_config() {
    local config="$1"
    IFS='|' read -r operation_mode safety_mode verbosity backup_mode <<< "$config"
    
    # Set command arguments based on configuration
    COMMAND_ARGS=()
    
    case "$operation_mode" in
        "Automatic") COMMAND_ARGS+=("--auto") ;;
        "Simple") COMMAND_ARGS+=("--simple" "--auto") ;;
        "Interactive") ;; # Default
    esac
    
    case "$safety_mode" in
        "Test Mode (Safe)") COMMAND_ARGS+=("--test-mode") ;;
        "Live Mode (Apply Changes)") ;; # Default
    esac
    
    case "$verbosity" in
        "Verbose") COMMAND_ARGS+=("--verbose") ;;
        "Quiet") ;; # Could add quiet flag if implemented
        "Normal") ;; # Default
    esac
    
    # Store for later use
    OPERATION_MODE="$operation_mode"
    SAFETY_MODE="$safety_mode"
    VERBOSITY="$verbosity"
    BACKUP_MODE="$backup_mode"
}

# Show operation confirmation
show_confirmation() {
    local message="Ready to start system maintenance with the following configuration:

Operation Mode: $OPERATION_MODE
Safety Mode: $SAFETY_MODE  
Verbosity: $VERBOSITY
Backup: $BACKUP_MODE

Command: ${MAIN_SCRIPT} ${COMMAND_ARGS[*]}"

    if [[ "$SAFETY_MODE" == "Live Mode (Apply Changes)" ]]; then
        message+="\n\n⚠️  WARNING: Live mode will make actual changes to your system!"
    else
        message+="\n\n✅ Safe mode: No actual changes will be made to your system."
    fi
    
    zenity --question \
        --title="Confirm Maintenance Operation" \
        --text="$message" \
        --width=600 \
        --height=250 \
        --ok-label="Start Maintenance" \
        --cancel-label="Cancel"
}

# Check for pacman lock
check_pacman_lock() {
    if [[ -f "/var/lib/pacman/db.lck" ]]; then
        local choice
        choice=$(zenity --question \
            --title="Package Manager Lock Detected" \
            --text="⚠️  Package Manager Database is Locked

Lock file: /var/lib/pacman/db.lck

This usually means another package operation is running:
• Software centers (pamac, gnome-software)
• AUR helpers (yay, paru)
• Another pacman instance

What would you like to do?" \
            --switch \
            --extra-button="Wait for Lock Release" \
            --extra-button="Remove Lock File" \
            --ok-label="Cancel Operation" \
            --width=500 \
            --height=200)
        
        case $? in
            0) 
                # Cancel - user chose to abort
                return 1 
                ;;
            1) 
                # Wait for lock - monitor until released
                (
                    echo "# Waiting for package manager lock to be released..."
                    echo "10"
                    local wait_count=0
                    while [[ -f "/var/lib/pacman/db.lck" ]]; do
                        sleep 2
                        wait_count=$((wait_count + 2))
                        if [[ $wait_count -ge 60 ]]; then
                            echo "# Still waiting... (${wait_count}s elapsed)"
                            echo "50"
                        fi
                    done
                    echo "# Lock released successfully!"
                    echo "100"
                ) | zenity --progress \
                    --title="Waiting for Package Manager" \
                    --text="Monitoring lock file: /var/lib/pacman/db.lck" \
                    --pulsate \
                    --auto-close \
                    --width=450
                return 0
                ;;
            2) 
                # Remove lock file - confirm first
                if zenity --question \
                    --title="Confirm Lock Removal" \
                    --text="⚠️  Remove Package Manager Lock File?

This will delete: /var/lib/pacman/db.lck

⚠️  WARNING: Only do this if you're certain no other package operations are running!

Removing the lock while another process is using it could corrupt your package database.

Are you sure you want to proceed?" \
                    --width=500 \
                    --height=200; then
                    
                    # User confirmed, remove the lock
                    if sudo rm -f "/var/lib/pacman/db.lck" 2>/dev/null; then
                        zenity --info \
                            --title="Lock Removed" \
                            --text="✅ Successfully removed package manager lock file.

You can now proceed with package operations." \
                            --width=400
                        return 0
                    else
                        zenity --error \
                            --title="Lock Removal Failed" \
                            --text="❌ Failed to remove lock file.

Please check your permissions or try running as administrator." \
                            --width=400
                        return 1
                    fi
                else
                    # User cancelled lock removal
                    return 1
                fi
                ;;
        esac
    fi
    return 0
}

# Check for potentially stale pacman lock files
check_stale_pacman_lock() {
    local lock_file="/var/lib/pacman/db.lck"
    
    if [[ -f "$lock_file" ]]; then
        # Check if the lock is actually stale
        local lock_age
        lock_age=$(( $(date +%s) - $(stat -c %Y "$lock_file" 2>/dev/null || echo 0) ))
        
        # If lock is older than 5 minutes, consider it potentially stale
        if [[ $lock_age -gt 300 ]]; then
            # Check if any pacman processes are actually running
            if ! pgrep -x "pacman\|pamac\|yay\|paru" >/dev/null 2>&1; then
                # No active processes - offer to remove stale lock
                if zenity --question \
                    --title="Stale Package Manager Lock Detected" \
                    --text="🔍 Found potentially stale package manager lock

Lock file: /var/lib/pacman/db.lck
Age: $((lock_age / 60)) minutes

No active package manager processes detected. This lock file appears to be orphaned (left behind by a crashed or interrupted operation).

Would you like to remove the stale lock file?" \
                    --width=500 \
                    --height=200; then
                    
                    if sudo rm -f "$lock_file" 2>/dev/null; then
                        zenity --info \
                            --title="Stale Lock Removed" \
                            --text="✅ Successfully removed stale lock file.

Package operations can now proceed normally." \
                            --width=400
                        return 0
                    else
                        zenity --error \
                            --title="Lock Removal Failed" \
                            --text="❌ Failed to remove stale lock file.

Please check your permissions." \
                            --width=400
                        return 1
                    fi
                else
                    return 1
                fi
            else
                zenity --info \
                    --title="Lock File Active" \
                    --text="🔍 Package manager lock file found

Lock file age: $((lock_age / 60)) minutes

Active package manager processes detected - lock is legitimate." \
                    --width=400
                return 1
            fi
        fi
    fi
    
    return 0
}

# Progress monitoring function
monitor_progress() {
    local current_step=0
    local total_steps=15
    local last_line=""
    
    # Start progress dialog in background
    (
        while IFS= read -r line; do
            # Extract step information from colored output
            if [[ "$line" =~ \[([0-9]+)/([0-9]+)\] ]]; then
                current_step="${BASH_REMATCH[1]}"
                total_steps="${BASH_REMATCH[2]}"
                step_name=$(echo "$line" | sed 's/.*] //' | sed 's/\x1b\[[0-9;]*m//g')
                percentage=$(( current_step * 100 / total_steps ))
                echo "$percentage"
                echo "# Step $current_step of $total_steps: $step_name"
            elif [[ "$line" =~ ^\[.*\] ]]; then
                # Regular log line
                clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^\[.\] //')
                if [[ -n "$clean_line" ]]; then
                    echo "# $clean_line"
                    last_line="$clean_line"
                fi
            fi
        done < <(tail -f "$OUTPUT_FILE" 2>/dev/null)
    ) | zenity --progress \
        --title="xanadOS Clean - System Maintenance" \
        --text="Initializing system maintenance..." \
        --percentage=0 \
        --width=600 \
        --height=150 \
        --auto-close
    
    return ${PIPESTATUS[1]}
}

# Run maintenance with real-time monitoring
run_maintenance() {
    # Check pacman lock if not in test mode
    if [[ "$SAFETY_MODE" != "Test Mode (Safe)" ]]; then
        if ! check_pacman_lock; then
            return 1
        fi
    fi
    
    # Start maintenance in background
    (
        "${MAIN_SCRIPT}" "${COMMAND_ARGS[@]}" 2>&1 | tee "$OUTPUT_FILE"
        echo $? > "${TEMP_DIR}/exit_code"
    ) &
    
    local maintenance_pid=$!
    echo "$maintenance_pid" > "$PID_FILE"
    
    # Monitor progress
    monitor_progress
    local progress_exit=$?
    
    # Wait for maintenance to complete
    wait "$maintenance_pid"
    local maintenance_exit
    maintenance_exit=$(cat "${TEMP_DIR}/exit_code" 2>/dev/null || echo "1")
    
    # If user cancelled progress dialog
    if [[ $progress_exit -ne 0 ]]; then
        kill "$maintenance_pid" 2>/dev/null
        zenity --question \
            --title="Operation Cancelled" \
            --text="Maintenance operation was cancelled by user.
            
Would you like to view the partial log?" \
            --width=400
        
        if [[ $? -eq 0 ]]; then
            show_log_viewer
        fi
        return 1
    fi
    
    return "$maintenance_exit"
}

# Show results dialog
show_results() {
    local exit_code=$1
    local log_preview
    log_preview=$(tail -20 "$OUTPUT_FILE" | sed 's/\x1b\[[0-9;]*m//g' | head -10)
    
    if [[ $exit_code -eq 0 ]]; then
        zenity --info \
            --title="Maintenance Complete" \
            --text="✅ System maintenance completed successfully!

Recent operations:
$log_preview

Would you like to view the full log?" \
            --width=600 \
            --height=400
        
        if [[ $? -eq 0 ]]; then
            show_log_viewer
        fi
    else
        zenity --error \
            --title="Maintenance Failed" \
            --text="❌ System maintenance encountered errors.

Recent output:
$log_preview

The full log is available for review." \
            --width=600 \
            --height=400
        
        show_log_viewer
    fi
}

# Log viewer
show_log_viewer() {
    local clean_log
    clean_log=$(sed 's/\x1b\[[0-9;]*m//g' "$OUTPUT_FILE")
    
    zenity --text-info \
        --title="Maintenance Log - xanadOS Clean" \
        --filename=<(echo "$clean_log") \
        --width=800 \
        --height=600 \
        --font="monospace 10"
}

# Main menu for additional operations
show_main_menu() {
    while true; do
        local choice
        choice=$(zenity --list \
            --title="xanadOS Clean - Main Menu" \
            --text="Select an operation:" \
            --column="Operation" \
            --column="Description" \
            --width=600 \
            --height=400 \
            "Run Maintenance" "Run full system maintenance" \
            "Quick Cleanup" "Basic cleanup only (safe)" \
            "System Report" "Generate system health report" \
            "View Configuration" "Show current configuration" \
            "Create Config" "Create custom configuration file" \
            "View Logs" "View maintenance logs" \
            "About" "About xanadOS Clean" \
            "Exit" "Exit application")
        
        case "$choice" in
            "Run Maintenance")
                local config
                config=$(show_config_dialog)
                if [[ $? -eq 0 ]]; then
                    parse_config "$config"
                    if show_confirmation; then
                        if run_maintenance; then
                            show_results 0
                        else
                            show_results 1
                        fi
                    fi
                fi
                ;;
            "Quick Cleanup")
                COMMAND_ARGS=("--simple" "--auto" "--test-mode")
                OPERATION_MODE="Simple"
                SAFETY_MODE="Test Mode (Safe)"
                if show_confirmation; then
                    if run_maintenance; then
                        show_results 0
                    else
                        show_results 1
                    fi
                fi
                ;;
            "System Report")
                COMMAND_ARGS=("--performance")
                if run_maintenance; then
                    show_results 0
                else
                    show_results 1
                fi
                ;;
            "View Configuration")
                "${MAIN_SCRIPT}" --show-config 2>&1 | zenity --text-info \
                    --title="Current Configuration" \
                    --width=600 \
                    --height=400 \
                    --font="monospace 10"
                ;;
            "Create Config")
                "${MAIN_SCRIPT}" --create-config
                zenity --info \
                    --title="Configuration Created" \
                    --text="Default configuration file has been created.
                    
You can edit it manually or use the GUI options." \
                    --width=400
                ;;
            "View Logs")
                show_log_viewer
                ;;
            "About")
                zenity --info \
                    --title="About xanadOS Clean" \
                    --text="xanadOS Clean v2.0.0
Professional Arch Linux System Maintenance

Features:
• Automated system updates and cleanup
• Package management and optimization  
• Security scanning and maintenance
• BTRFS filesystem maintenance
• SSD optimization and trimming
• Performance monitoring and reporting

Author: GitHub Copilot
License: MIT" \
                    --width=500 \
                    --height=300
                ;;
            "Exit"|"")
                break
                ;;
        esac
    done
}

# Main execution
main() {
    # Check dependencies
    check_dependencies
    
    # Check if maintenance script exists
    if [[ ! -x "$MAIN_SCRIPT" ]]; then
        zenity --error \
            --title="Script Not Found" \
            --text="Maintenance script not found at:
$MAIN_SCRIPT

Please ensure the xanados_clean.sh script is in the correct location and is executable." \
            --width=500
        exit 1
    fi
    
    # Check for stale pacman lock files early
    check_stale_pacman_lock
    
    # Show welcome dialog
    if ! show_welcome; then
        exit 0
    fi
    
    # Show main menu
    show_main_menu
}

# Run main function
main "$@"
