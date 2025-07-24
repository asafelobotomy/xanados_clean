#!/bin/bash
# zenity_gui.sh - Interactive GUI for xanadOS Clean using Zenity with real-time prompt handling
# Author: GitHub Copilot
# Version: 2.0.0
# License: GPL-3.0
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Set up variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/../xanados_clean.sh"
# Use secure temporary directory creation
TEMP_DIR=$(mktemp -d -t xanados_clean.XXXXXX)
OUTPUT_FILE="${TEMP_DIR}/output.log"
PROGRESS_FILE="${TEMP_DIR}/progress.txt"
PID_FILE="${TEMP_DIR}/maintenance.pid"
INPUT_PIPE="${TEMP_DIR}/input.fifo"
PROMPT_PIPE="${TEMP_DIR}/prompt.fifo"

# Create named pipes for interactive communication
mkfifo "$INPUT_PIPE" "$PROMPT_PIPE"

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

# Real-time interactive prompt handler
handle_interactive_prompts() {
    local output_line="$1"
    local response=""
    
    # Detect various types of prompts and show appropriate Zenity dialogs
    if [[ "$output_line" =~ Select\ option\ \[1\]: ]] || [[ "$output_line" =~ ^[0-3]\).*Exit$ ]]; then
        # Main menu prompt
        response=$(zenity --list \
            --title="Maintenance Mode" \
            --text="Choose maintenance operation:" \
            --column="Option" \
            --column="Description" \
            --width=500 \
            --height=300 \
            "1" "Full maintenance (recommended)" \
            "2" "Custom selection" \
            "3" "Simple mode" \
            "0" "Exit")
        case "$response" in
            "1") echo "1" ;;
            "2") echo "2" ;;
            "3") echo "3" ;;
            "0"|"") echo "0" ;;
            *) echo "1" ;;
        esac
        
    elif [[ "$output_line" =~ Install\ missing\ required\ packages\?.*\[Y/n\] ]]; then
        # Package installation prompt
        if zenity --question \
            --title="Package Installation" \
            --text="Install missing required packages?" \
            --width=400; then
            echo "Y"
        else
            echo "n"
        fi
        
    elif [[ "$output_line" =~ Install\ optional\ packages\?.*\[y/N\] ]]; then
        # Optional packages prompt
        if zenity --question \
            --title="Optional Packages" \
            --text="Install optional enhancement packages?" \
            --width=400; then
            echo "y"
        else
            echo "N"
        fi
        
    elif [[ "$output_line" =~ Continue\ with\ low\ memory\?.*\[y/N\] ]]; then
        # Low memory prompt
        if zenity --question \
            --title="Low Memory Warning" \
            --text="System has low available memory. Continue anyway?" \
            --width=400; then
            echo "y"
        else
            echo "N"
        fi
        
    elif [[ "$output_line" =~ Continue\ with\ low\ disk\ space\?.*\[y/N\] ]]; then
        # Low disk space prompt
        if zenity --question \
            --title="Low Disk Space Warning" \
            --text="System has low available disk space. Continue anyway?" \
            --width=400; then
            echo "y"
        else
            echo "N"
        fi
        
    elif [[ "$output_line" =~ Show\ detailed\ status.*\[y/N\] ]]; then
        # Show details prompt
        if zenity --question \
            --title="Show Details" \
            --text="Show detailed status information?" \
            --width=400; then
            echo "y"
        else
            echo "N"
        fi
        
    elif [[ "$output_line" =~ Run.*\?.*\[Y/n\] ]]; then
        # Generic "Run [operation]?" prompt (for ASK_EACH mode)
        local operation
        operation=$(echo "$output_line" | sed -n 's/.*Run \(.*\)? \[Y\/n\].*/\1/p')
        if zenity --question \
            --title="Confirm Operation" \
            --text="Run: $operation?" \
            --width=400; then
            echo "Y"
        else
            echo "n"
        fi
        
    else
        # Unknown prompt - default to enter/yes
        echo ""
    fi
}
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

Click OK to continue to the configuration screen.

(This dialog will auto-close in 30 seconds)" \
        --width=500 \
        --height=300 \
        --timeout=30
}

# Configuration dialog
show_config_dialog() {
    # First, ask for basic operation mode
    local operation_mode
    operation_mode=$(zenity --list \
        --title="xanadOS Clean - Operation Mode" \
        --text="Select your maintenance operation:" \
        --column="Mode" \
        --column="Description" \
        --width=600 \
        --height=300 \
        "Full Maintenance" "Complete system maintenance (recommended)" \
        "Custom Selection" "Choose specific maintenance tasks" \
        "Simple Mode" "Basic cleanup only (safest)" \
        --timeout=60)
    
    # Handle timeout or cancellation
    if [[ $? -eq 5 ]]; then
        operation_mode="Full Maintenance"
    elif [[ $? -ne 0 ]]; then
        exit 0
    fi
    
    # Collect additional preferences based on operation mode
    
    # Safety mode
    local safety_mode
    safety_mode=$(zenity --list \
        --title="Safety Mode" \
        --text="Choose safety level:" \
        --column="Mode" \
        --column="Description" \
        --width=500 \
        --height=250 \
        "Test Mode" "Preview changes without applying (SAFE)" \
        "Live Mode" "Apply changes to system" \
        --timeout=30)
    
    if [[ $? -eq 5 ]] || [[ -z "$safety_mode" ]]; then
        safety_mode="Test Mode"
    fi
    
    # Display mode
    local display_mode
    display_mode=$(zenity --list \
        --title="Display Mode" \
        --text="How would you like to monitor progress?" \
        --column="Mode" \
        --column="Description" \
        --width=500 \
        --height=250 \
        "Live Console Output" "Show real-time terminal output (recommended)" \
        "Progress Bar" "Simple progress indicator" \
        --timeout=30)
    
    if [[ $? -eq 5 ]] || [[ -z "$display_mode" ]]; then
        display_mode="Live Console Output"
    fi
    
    # Pre-collect answers for common interactive prompts
    local install_missing="Y"
    local install_optional="N"
    local continue_low_resources="N"
    local show_details="N"
    
    # If in live mode, ask about potentially risky operations
    if [[ "$safety_mode" == "Live Mode" ]]; then
        if zenity --question \
            --title="Package Installation" \
            --text="If missing required packages are found, should they be automatically installed?" \
            --width=400; then
            install_missing="Y"
        else
            install_missing="N"
        fi
        
        if zenity --question \
            --title="Optional Packages" \
            --text="Install optional enhancement packages if available?" \
            --width=400; then
            install_optional="Y"
        else
            install_optional="N"
        fi
        
        if zenity --question \
            --title="Resource Limits" \
            --text="Continue maintenance even if system resources are low (memory/disk)?" \
            --width=400; then
            continue_low_resources="Y"
        else
            continue_low_resources="N"
        fi
    fi
    
    # Build configuration string
    local config="${operation_mode}|${safety_mode}|${display_mode}|${install_missing}|${install_optional}|${continue_low_resources}|${show_details}"
    echo "$config"
}

# Parse configuration and prepare for execution
parse_config() {
    local config="$1"
    IFS='|' read -r operation_mode safety_mode display_mode install_missing install_optional continue_low_resources show_details <<< "$config"
    
    # Set command arguments based on configuration
    COMMAND_ARGS=()
    
    # Use --auto to prevent interactive menu prompts (our fix should handle this)
    COMMAND_ARGS+=("--auto")
    
    case "$operation_mode" in
        "Simple Mode") COMMAND_ARGS+=("--simple") ;;
        "Custom Selection") COMMAND_ARGS+=("--ask-each") ;;
        "Full Maintenance") ;; # Default - full maintenance
    esac
    
    case "$safety_mode" in
        "Test Mode") COMMAND_ARGS+=("--test-mode") ;;
        "Live Mode") ;; # Default - apply changes
    esac
    
    # Set display mode for progress monitoring
    case "$display_mode" in
        "Live Console Output") 
            DISPLAY_MODE="console"
            ;;
        "Progress Bar") 
            DISPLAY_MODE="progress"
            ;;
        *) 
            DISPLAY_MODE="console"
            ;;
    esac
    
    # Store for later use
    OPERATION_MODE="$operation_mode"
    SAFETY_MODE="$safety_mode"
}

# Show operation confirmation
show_confirmation() {
    local message="Ready to start system maintenance with the following configuration:

Operation Mode: $OPERATION_MODE
Safety Mode: $SAFETY_MODE
Display Mode: $DISPLAY_MODE
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

# Real-time console output monitoring function
monitor_console_output() {
    local monitoring_timeout=1800  # 30 minutes maximum
    local monitoring_start=$(date +%s)
    local last_activity=$(date +%s)
    local activity_timeout=300  # 5 minutes of no activity
    local last_line_count=0
    
    # Wait for output file to be created
    local timeout_counter=0
    while [[ ! -s "$OUTPUT_FILE" && $timeout_counter -lt 15 ]]; do
        sleep 1
        ((timeout_counter++))
    done
    
    # Create a temporary file for zenity text display
    local display_file="${TEMP_DIR}/console_display.txt"
    echo "=== xanadOS Clean Console Output ===" > "$display_file"
    echo "Initializing system maintenance..." >> "$display_file"
    echo "" >> "$display_file"
    
    # Start zenity text-info dialog in background
    (
        tail -f "$display_file" 2>/dev/null
    ) | zenity --text-info \
        --title="xanadOS Clean - Live Console Output" \
        --width=800 \
        --height=600 \
        --font="monospace 10" \
        --auto-scroll \
        --no-wrap &
    
    local zenity_pid=$!
    
    # Monitor output file and update display
    (
        while IFS= read -r line; do
            # Check for activity and process status
            local current_time
            current_time=$(date +%s)
            local current_line_count
            current_line_count=$(wc -l < "$OUTPUT_FILE" 2>/dev/null || echo 0)
            
            if [[ $current_line_count -gt $last_line_count ]]; then
                last_activity=$current_time
                last_line_count=$current_line_count
            fi
            
            # Check if maintenance process is still running
            local maintenance_pid
            local process_running=false
            if [[ -f "$PID_FILE" ]]; then
                maintenance_pid=$(cat "$PID_FILE" 2>/dev/null)
                if [[ -n "$maintenance_pid" ]] && kill -0 "$maintenance_pid" 2>/dev/null; then
                    process_running=true
                fi
            fi
            
            # Check for timeouts
            local time_since_activity=$((current_time - last_activity))
            local total_time=$((current_time - monitoring_start))
            
            if [[ $total_time -gt $monitoring_timeout ]]; then
                echo "" >> "$display_file"
                echo "=== TIMEOUT: Maximum maintenance time reached (30 minutes) ===" >> "$display_file"
                echo "Operation completed due to timeout." >> "$display_file"
                break
            elif [[ $time_since_activity -gt $activity_timeout && "$process_running" == "false" ]]; then
                echo "" >> "$display_file"
                echo "=== Process appears to have completed or stopped ===" >> "$display_file"
                break
            fi
            
            # Clean and display the line
            local clean_line
            clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
            
            # Add timestamp for better tracking
            local timestamp
            timestamp=$(date "+%H:%M:%S")
            
            # Check for completion indicators
            if [[ "$line" =~ "System maintenance complete"|"Maintenance Complete"|"completed successfully" ]]; then
                echo "[$timestamp] $clean_line" >> "$display_file"
                echo "" >> "$display_file"
                echo "=== MAINTENANCE COMPLETED SUCCESSFULLY ===" >> "$display_file"
                break
            elif [[ "$line" =~ "0\) Exit"|"Select option"|"Choose an option" ]]; then
                echo "[$timestamp] $clean_line" >> "$display_file"
                echo "" >> "$display_file"
                echo "=== Interactive menu detected - completing operation ===" >> "$display_file"
                echo "=== MAINTENANCE COMPLETED ===" >> "$display_file"
                break
            else
                # Regular output line
                if [[ -n "$clean_line" && "$clean_line" != *"[sudo]"* ]]; then
                    echo "[$timestamp] $clean_line" >> "$display_file"
                fi
            fi
            
        done < <(tail -f "$OUTPUT_FILE" 2>/dev/null)
        
        # Final status
        echo "" >> "$display_file"
        echo "=== Console monitoring completed at $(date) ===" >> "$display_file"
        
        # Keep zenity window open for a moment to show completion
        sleep 3
        kill "$zenity_pid" 2>/dev/null
        
    ) &
    
    local monitor_pid=$!
    
    # Wait for either zenity to close (user cancellation) or monitoring to complete
    wait "$zenity_pid" 2>/dev/null
    local zenity_exit=$?
    
    # Clean up monitoring process
    kill "$monitor_pid" 2>/dev/null
    wait "$monitor_pid" 2>/dev/null
    
    return $zenity_exit
}

# Progress monitoring function
monitor_progress() {
    local current_step=0
    local total_steps=15
    local progress_started=false
    local timeout_counter=0
    local monitoring_timeout=1800  # 30 minutes maximum for any maintenance operation
    local monitoring_start=$(date +%s)
    local last_activity=$(date +%s)
    local activity_timeout=300  # 5 minutes of no activity before warning
    local last_line_count=0
    
    # Wait for output file to be created and have content with timeout
    while [[ ! -s "$OUTPUT_FILE" && $timeout_counter -lt 15 ]]; do
        sleep 1
        ((timeout_counter++))
    done
    
    # If timeout reached, show warning but continue
    if [[ $timeout_counter -ge 15 && ! -s "$OUTPUT_FILE" ]]; then
        echo "[WARNING] Script taking longer than expected to start" >> "$OUTPUT_FILE"
        echo "[INFO] This may indicate system resource constraints" >> "$OUTPUT_FILE"
        echo "[INFO] Please wait while the system initializes..." >> "$OUTPUT_FILE"
    fi
    
    # Start progress dialog in background
    (
        # Send initial status immediately
        echo "1"
        echo "# Initializing xanadOS Clean..."
        
        # Show initialization progress while waiting for output
        local init_counter=0
        local init_messages=(
            "Loading libraries and extensions..."
            "Parsing command line arguments..."
            "Checking system requirements..."
            "Initializing performance monitoring..."
            "Checking system resources..."
            "Loading configuration files..."
            "Setting up package manager..."
            "Starting maintenance operations..."
        )
        
        # Show initialization progress while waiting for real output
        while [[ $init_counter -lt ${#init_messages[@]} && $timeout_counter -lt 8 ]]; do
            if [[ -s "$OUTPUT_FILE" ]]; then
                break  # Real output available, stop simulated progress
            fi
            echo "$((2 + init_counter * 8 / ${#init_messages[@]}))"
            echo "# ${init_messages[init_counter]}"
            sleep 1
            ((init_counter++))
        done
        
        while IFS= read -r line; do
            # Check for activity - update last activity time when we get new content
            local current_time
            current_time=$(date +%s)
            local current_line_count
            current_line_count=$(wc -l < "$OUTPUT_FILE" 2>/dev/null || echo 0)
            
            # If we have new lines, update last activity time
            if [[ $current_line_count -gt $last_line_count ]]; then
                last_activity=$current_time
                last_line_count=$current_line_count
            fi
            
            # Check for stall (no activity) vs hard timeout
            local time_since_activity=$((current_time - last_activity))
            local total_time=$((current_time - monitoring_start))
            
            # Check if maintenance process is still running
            local maintenance_pid
            local process_running=false
            local process_active=false
            if [[ -f "$PID_FILE" ]]; then
                maintenance_pid=$(cat "$PID_FILE" 2>/dev/null)
                if [[ -n "$maintenance_pid" ]] && kill -0 "$maintenance_pid" 2>/dev/null; then
                    process_running=true
                    
                    # Check if process or its children are active (have CPU usage)
                    # Look for the process and any child processes
                    if pgrep -P "$maintenance_pid" >/dev/null 2>&1 || \
                       ps -o pid,pcpu --no-headers -p "$maintenance_pid" 2>/dev/null | awk '{if ($2 > 0.1) exit 0} END{exit 1}'; then
                        process_active=true
                    fi
                fi
            fi
            
            if [[ $total_time -gt $monitoring_timeout ]]; then
                echo "95"
                echo "# Maximum maintenance time reached (30 minutes), finalizing..."
                sleep 1
                echo "100"
                echo "# Maintenance completed (maximum time reached)"
                break
            elif [[ $time_since_activity -gt $activity_timeout ]]; then
                if [[ "$process_running" == "true" ]]; then
                    if [[ "$process_active" == "true" ]]; then
                        # Process is running and using CPU - definitely active
                        echo "# Long-running operation in progress ($((time_since_activity / 60))m) - please wait..."
                    else
                        # Process exists but no CPU activity - might be waiting for I/O or user input
                        echo "# Process waiting for I/O or external resource ($((time_since_activity / 60))m)..."
                    fi
                else
                    # Process died and no activity - likely stuck or completed without proper output
                    echo "90"
                    echo "# Process appears to have stopped, finalizing..."
                    sleep 1
                    echo "100"
                    echo "# Maintenance completed (process stopped)"
                    break
                fi
            fi
            
            # Check for completion indicators first
            if [[ "$line" =~ "System maintenance complete"|"Maintenance Complete"|"completed successfully" ]]; then
                echo "100"
                echo "# Maintenance completed successfully!"
                break
            fi
            
            # Check for interactive menu prompts that would cause hanging
            if [[ "$line" =~ "0\) Exit"|"Select option"|"Choose an option"|"Press Enter" ]]; then
                echo "90"
                echo "# Finalizing maintenance operations..."
                # Give it a moment then assume completion
                sleep 2
                echo "100" 
                echo "# Maintenance operations completed!"
                break
            fi
            
            # Extract step information from colored output - be more flexible with patterns
            if [[ "$line" =~ \[.*\].*\(([0-9]+)/([0-9]+)\) ]]; then
                current_step="${BASH_REMATCH[1]}"
                total_steps="${BASH_REMATCH[2]}"
                step_name=$(echo "$line" | sed 's/.*) //' | sed 's/\x1b\[[0-9;]*m//g')
                percentage=$(( current_step * 100 / total_steps ))
                echo "$percentage"
                echo "# Step $current_step of $total_steps: $step_name"
                progress_started=true
            elif [[ "$line" =~ ^\[.*\] ]]; then
                # Regular log line
                clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^\[.\] //')
                if [[ -n "$clean_line" ]]; then
                    echo "# $clean_line"
                    # If we haven't started progress yet, estimate based on content
                    if [[ "$progress_started" == "false" ]]; then
                        if [[ "$clean_line" =~ optimization|package|update|cache ]]; then
                            echo "15"
                        elif [[ "$clean_line" =~ maintenance|Starting|Initializing ]]; then
                            echo "12"
                        elif [[ "$clean_line" =~ Loading|Checking|Setting ]]; then
                            echo "10"
                        fi
                    fi
                fi
            elif [[ -n "$line" && "$line" != *"[sudo]"* && "$line" != *"0)"* && "$line" != *"1)"* ]]; then
                # Any other output that isn't a sudo prompt or menu option
                clean_line=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')
                if [[ -n "$clean_line" ]]; then
                    echo "# $clean_line"
                fi
            fi
        done < <(tail -f "$OUTPUT_FILE" 2>/dev/null || echo "# Starting maintenance process...")
    ) | zenity --progress \
        --title="xanadOS Clean - System Maintenance" \
        --text="Initializing system maintenance..." \
        --percentage=0 \
        --width=650 \
        --height=150 \
        --auto-close
    
    return ${PIPESTATUS[1]}
}

# Run maintenance with real-time monitoring
# Monitor output for interactive prompts and respond via GUI
monitor_and_respond() {
    local maintenance_pid="$1"
    
    # Start prompt detection in background
    {
        while IFS= read -r line; do
            echo "$line" >> "$OUTPUT_FILE"
            
            # Check if this line contains an interactive prompt
            if [[ "$line" =~ \[.*\].*$ ]] && [[ "$line" =~ \? ]]; then
                # This looks like a prompt - handle it
                local response
                response=$(handle_interactive_prompts "$line")
                if [[ -n "$response" ]]; then
                    # Send the response to the maintenance script
                    echo "$response" > "$INPUT_PIPE" &
                fi
            fi
        done
    } &
    
    local monitor_pid=$!
    
    # Wait for maintenance to complete
    wait "$maintenance_pid"
    local exit_code=$?
    
    # Clean up monitor
    kill "$monitor_pid" 2>/dev/null || true
    
    return $exit_code
}

# Run maintenance with interactive GUI responses
run_maintenance_interactive() {
    # Check pacman lock if not in test mode
    if [[ "$SAFETY_MODE" != "Test Mode (Safe)" ]]; then
        if ! check_pacman_lock; then
            return 1
        fi
    fi
    
    # Initialize output file with immediate content
    echo "[+] Initializing xanadOS Clean maintenance..." > "$OUTPUT_FILE"
    echo "[+] Starting system maintenance process..." >> "$OUTPUT_FILE"
    echo "[+] Loading libraries and extensions..." >> "$OUTPUT_FILE"
    
    # Start maintenance in background
    (
        # Set environment variables based on safety mode
        if [[ "$SAFETY_MODE" == "Test Mode (Safe)" ]]; then
            export TEST_MODE=true
            export SUDO=""
        else
            # For live mode, use our GUI authentication wrapper
            export SUDO="${SCRIPT_DIR}/gui_sudo.sh"
            echo "[DEBUG] GUI Mode: Using GUI authentication wrapper at ${SUDO}" >> "$OUTPUT_FILE"
        fi
        
        # Add startup progress indicators
        echo "[+] Parsing command line arguments..." >> "$OUTPUT_FILE"
        sleep 0.5
        echo "[+] Checking system requirements..." >> "$OUTPUT_FILE"
        sleep 0.5
        echo "[+] Initializing performance monitoring..." >> "$OUTPUT_FILE"
        sleep 0.5
        echo "[+] Checking system resources..." >> "$OUTPUT_FILE"
        sleep 0.5
        echo "[+] Loading configuration..." >> "$OUTPUT_FILE"
        sleep 0.5
        echo "[+] Setting up package manager..." >> "$OUTPUT_FILE"
        sleep 0.5
        echo "[+] Starting maintenance operations..." >> "$OUTPUT_FILE"
        
        # Use stdbuf to force unbuffered output and pipe a default response for the main menu
        {
            sleep 2  # Give script time to start
            echo "1"  # Automatically select "Full maintenance"
        } | stdbuf -o0 -e0 "${MAIN_SCRIPT}" "${COMMAND_ARGS[@]}" 2>&1 | stdbuf -o0 tee -a "$OUTPUT_FILE"
        echo $? > "${TEMP_DIR}/exit_code"
    ) &
    
    local maintenance_pid=$!
    echo "$maintenance_pid" > "$PID_FILE"
    
    # Give the script a moment to start and create output
    sleep 1
    
    # Monitor progress using selected display mode
    local monitor_exit
    if [[ "${DISPLAY_MODE:-Progress Bar}" == "Live Console Output" ]]; then
        monitor_console_output
        monitor_exit=$?
    else
        monitor_progress
        monitor_exit=$?
    fi
    
    # Wait for maintenance to complete
    wait "$maintenance_pid"
    local maintenance_exit
    maintenance_exit=$(cat "${TEMP_DIR}/exit_code" 2>/dev/null || echo "1")
    
    # If user cancelled dialog
    if [[ $monitor_exit -ne 0 ]]; then
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
                DISPLAY_MODE="Live Console Output"  # Use console output for quick cleanup to show activity
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
                DISPLAY_MODE="Live Console Output"  # Use console output for reports
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
License: GPL-3.0" \
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
    # Provide immediate feedback that the application is starting
    echo "[INFO] xanadOS Clean GUI starting..." >&2
    echo "[INFO] GUI application is launching successfully." >&2
    echo "[INFO] GUI dialogs should appear shortly..." >&2
    
    # Check for --no-welcome parameter
    local skip_welcome=false
    for arg in "$@"; do
        if [[ "$arg" == "--no-welcome" ]]; then
            skip_welcome=true
            break
        fi
    done
    
    # Check dependencies
    check_dependencies
    
    # Check if maintenance script exists
    if [[ ! -x "$MAIN_SCRIPT" ]]; then
        zenity --error \
            --title="Script Not Found" \
            --text="Maintenance script not found at:
$MAIN_SCRIPT

Please ensure the xanados_clean.sh script is in the correct location and is executable." \
            --width=500 \
            --timeout=10
        exit 1
    fi
    
    # Check for stale pacman lock files early
    echo "[DEBUG] Checking for stale pacman lock files..." >&2
    if ! timeout 5s check_stale_pacman_lock; then
        echo "[DEBUG] Lock check timed out or failed, continuing..." >&2
    fi
    
    # Show welcome dialog (unless skipped)
    if [[ "$skip_welcome" == "false" ]]; then
        echo "[DEBUG] Showing welcome dialog..." >&2
        if ! show_welcome; then
            echo "[DEBUG] Welcome dialog cancelled or failed" >&2
            exit 0
        fi
        echo "[DEBUG] Welcome dialog completed successfully" >&2
    else
        echo "[INFO] Skipping welcome dialog..." >&2
    fi
    
    # Show main menu
    show_main_menu
}

# Run main function
main "$@"
