#!/usr/bin/env bash
# Performance monitoring and optimization for xanadOS Clean

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
        log "⚠ Performance warning: $step_name took ${duration}s (>5min)"
    fi
    
    if (( memory_delta > 1000 )); then  # 1GB
        log "⚠ Memory warning: $step_name used ${memory_delta}MB additional memory"
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
    local start_time start_memory start_io
    start_time=$(date +%s)
    start_memory=$(free -m | awk 'NR==2{print $3}')
    start_io=$(iostat -d 1 1 2>/dev/null | tail -n +4 | awk '{sum+=$4} END {print sum}' || echo "0")
    
    # Create checkpoint for critical operations
    if is_critical_step "$func"; then
        create_checkpoint "$func"
    fi
    
    show_progress "$desc"
    
    # Execute step with monitoring
    local peak_memory=$start_memory
    local monitor_pid
    
    # Background memory monitoring
    (
        while sleep 5; do
            local current_mem
            current_mem=$(free -m | awk 'NR==2{print $3}')
            if (( current_mem > peak_memory )); then
                peak_memory=$current_mem
            fi
        done
    ) &
    monitor_pid=$!
    
    # Execute the actual function
    local func_result=0
    if $func; then
        local end_time end_memory end_io
        end_time=$(date +%s)
        end_memory=$(free -m | awk 'NR==2{print $3}')
        end_io=$(iostat -d 1 1 2>/dev/null | tail -n +4 | awk '{sum+=$4} END {print sum}' || echo "0")
        
        # Stop monitoring
        kill $monitor_pid 2>/dev/null || true
        wait $monitor_pid 2>/dev/null || true
        
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
    printf "Total execution time: %dm %ds\n" $((total_time / 60)) $((total_time % 60))
    printf "Memory usage change: %+d MB\n" "$total_memory_delta"
    printf "Initial system load: %s\n" "${SYSTEM_METRICS[start_load]}"
    
    # Step-by-step performance
    printf "\n%bStep Performance:%b\n" "$CYAN" "$NC"
    for step in "${COMPLETED_STEPS[@]}"; do
        local duration="${STEP_METRICS[${step}_duration]:-0}"
        local memory="${STEP_METRICS[${step}_memory_delta]:-0}"
        printf "  %-25s %3ds  %+4dMB\n" "$step" "$duration" "$memory"
    done
    
    # Performance recommendations
    printf "\n%bOptimization Recommendations:%b\n" "$CYAN" "$NC"
    
    if (( total_time > 1800 )); then  # 30 minutes
        echo "  • Consider running during off-peak hours"
        echo "  • Check for I/O bottlenecks"
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
        if (( $(echo "$avg_io > 50" | bc -l 2>/dev/null || echo "0") )); then
            echo "  • High I/O detected - consider SSD upgrade"
        fi
    fi
}

# Optimize system for maintenance operations
optimize_system_performance() {
    log "Optimizing system for maintenance operations"
    
    # Set CPU governor to performance if available
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        if ${SUDO} sh -c 'echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor' 2>/dev/null; then
            log "CPU governor set to performance mode"
        fi
    fi
    
    # Increase I/O scheduler queue depth for better throughput
    for disk in /sys/block/sd*/queue/nr_requests; do
        if [[ -f "$disk" ]]; then
            ${SUDO} sh -c "echo 128 > $disk" 2>/dev/null || true
        fi
    done
    
    # Adjust swappiness for better memory performance
    if [[ -f /proc/sys/vm/swappiness ]]; then
        local current_swappiness
        current_swappiness=$(cat /proc/sys/vm/swappiness)
        if (( current_swappiness > 10 )); then
            ${SUDO} sh -c 'echo 10 > /proc/sys/vm/swappiness' 2>/dev/null || true
            log "Reduced swappiness for better performance"
        fi
    fi
}

# Restore system settings after maintenance
restore_system_performance() {
    log "Restoring original system performance settings"
    
    # Restore CPU governor
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        ${SUDO} sh -c 'echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor' 2>/dev/null || true
    fi
    
    # Restore swappiness
    if [[ -f /proc/sys/vm/swappiness ]]; then
        ${SUDO} sh -c 'echo 60 > /proc/sys/vm/swappiness' 2>/dev/null || true
    fi
}

# Check system resources before starting
check_system_resources() {
    log "Checking system resources"
    
    # Check available memory
    local available_memory
    available_memory=$(free -m | awk 'NR==2{print $7}')
    if (( available_memory < 1000 )); then  # Less than 1GB
        log "⚠ Warning: Low available memory (${available_memory}MB)"
        if [[ "${AUTO_MODE:-false}" != "true" ]]; then
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
        log "⚠ Warning: Low disk space (${available_gb}GB available)"
        if [[ "${AUTO_MODE:-false}" != "true" ]]; then
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
    if (( $(echo "$current_load > $cpu_count * 2" | bc -l 2>/dev/null || echo "0") )); then
        log "⚠ Warning: High system load ($current_load)"
    fi
}

# Parallel execution for compatible operations
run_parallel_operations() {
    local operations=("$@")
    local pids=()
    local results=()
    
    log "Running ${#operations[@]} operations in parallel"
    
    # Start operations in background
    for op in "${operations[@]}"; do
        (
            $op
            echo $? > "/tmp/xanados_result_$$_${op//[^a-zA-Z0-9]/_}"
        ) &
        pids+=($!)
    done
    
    # Wait for all operations to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Collect results
    local success_count=0
    for op in "${operations[@]}"; do
        local result_file="/tmp/xanados_result_$$_${op//[^a-zA-Z0-9]/_}"
        if [[ -f "$result_file" ]]; then
            local result
            result=$(cat "$result_file")
            results+=("$result")
            rm -f "$result_file"
            if (( result == 0 )); then
                ((success_count++))
            fi
        fi
    done
    
    log "Parallel operations completed: $success_count/${#operations[@]} successful"
    return $(( ${#operations[@]} - success_count ))
}
