#!/usr/bin/env bash
# Configuration management for xanadOS Clean
# This file provides functions to load and validate configuration

# Configuration file search paths (in order of priority)
readonly CONFIG_PATHS=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/xanados_clean/config.conf"
    "${HOME}/.xanados_clean.conf"
    "/etc/xanados_clean/config.conf"
    "${SCRIPT_DIR:-}/config/default.conf"
)

# Load configuration from the first found config file
load_config() {
    local config_file=""
    
    # Find the first existing config file
    for path in "${CONFIG_PATHS[@]}"; do
        if [[ -f "$path" && -r "$path" ]]; then
            config_file="$path"
            break
        fi
    done
    
    if [[ -n "$config_file" ]]; then
        log "Loading configuration from: $config_file"
        # Source configuration file with error handling
        # shellcheck source=/dev/null
        if ! source "$config_file" 2>/dev/null; then
            error "Failed to load configuration from $config_file"
            return 1
        fi
    else
        log "No configuration file found, using defaults"
    fi
    
    # Validate and set defaults for critical variables
    validate_config
}

# Validate configuration values and set defaults
validate_config() {
    # General settings with defaults
    LOG_FILE="${LOG_FILE:-${HOME}/Documents/system_maint.log}"
    MAX_LOG_SIZE="${MAX_LOG_SIZE:-50}"
    LOG_ROTATION_COUNT="${LOG_ROTATION_COUNT:-5}"
    AUTO_MODE="${AUTO_MODE:-false}"
    ASK_EACH_STEP="${ASK_EACH_STEP:-false}"
    
    # Backup settings
    BACKUP_METHOD="${BACKUP_METHOD:-auto}"
    RSYNC_BACKUP_DIR="${RSYNC_BACKUP_DIR:-}"
    BACKUP_SKIP_THRESHOLD_DAYS="${BACKUP_SKIP_THRESHOLD_DAYS:-30}"
    
    # Package management
    AUR_HELPER="${AUR_HELPER:-auto}"
    UPDATE_MIRRORS="${UPDATE_MIRRORS:-true}"
    AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-true}"
    
    # Maintenance options
    ENABLE_FLATPAK="${ENABLE_FLATPAK:-true}"
    ENABLE_SECURITY_SCAN="${ENABLE_SECURITY_SCAN:-true}"
    ENABLE_BTRFS_MAINTENANCE="${ENABLE_BTRFS_MAINTENANCE:-auto}"
    ENABLE_SSD_TRIM="${ENABLE_SSD_TRIM:-auto}"
    ENABLE_ORPHAN_REMOVAL="${ENABLE_ORPHAN_REMOVAL:-true}"
    ENABLE_CACHE_CLEANUP="${ENABLE_CACHE_CLEANUP:-true}"
    
    # System reporting
    SHOW_NEWS="${SHOW_NEWS:-true}"
    ENABLE_SYSTEM_REPORT="${ENABLE_SYSTEM_REPORT:-true}"
    REPORT_GPU_INFO="${REPORT_GPU_INFO:-true}"
    REPORT_TEMPERATURE="${REPORT_TEMPERATURE:-true}"
    REPORT_SMART_STATUS="${REPORT_SMART_STATUS:-true}"
    
    # Network settings
    NETWORK_TIMEOUT="${NETWORK_TIMEOUT:-5}"
    MIRROR_REFRESH_TIMEOUT="${MIRROR_REFRESH_TIMEOUT:-300}"
    
    # Security settings
    ENABLE_RKHUNTER="${ENABLE_RKHUNTER:-true}"
    ENABLE_ARCH_AUDIT="${ENABLE_ARCH_AUDIT:-true}"
    UPDATE_SECURITY_DATABASES="${UPDATE_SECURITY_DATABASES:-true}"
    
    # Advanced options
    PRE_MAINTENANCE_SCRIPT="${PRE_MAINTENANCE_SCRIPT:-}"
    POST_MAINTENANCE_SCRIPT="${POST_MAINTENANCE_SCRIPT:-}"
    PACKAGE_EXCLUSIONS="${PACKAGE_EXCLUSIONS:-}"
    CUSTOM_PACMAN_ARGS="${CUSTOM_PACMAN_ARGS:-}"
    CUSTOM_DNF_ARGS="${CUSTOM_DNF_ARGS:-}"
    DEBUG_MODE="${DEBUG_MODE:-false}"
    
    # Validate numeric values
    validate_numeric "MAX_LOG_SIZE" "$MAX_LOG_SIZE" 1 1000
    validate_numeric "LOG_ROTATION_COUNT" "$LOG_ROTATION_COUNT" 1 20
    validate_numeric "BACKUP_SKIP_THRESHOLD_DAYS" "$BACKUP_SKIP_THRESHOLD_DAYS" 0 365
    validate_numeric "NETWORK_TIMEOUT" "$NETWORK_TIMEOUT" 1 60
    validate_numeric "MIRROR_REFRESH_TIMEOUT" "$MIRROR_REFRESH_TIMEOUT" 30 3600
    
    # Validate boolean values
    validate_boolean "AUTO_MODE" "$AUTO_MODE"
    validate_boolean "ASK_EACH_STEP" "$ASK_EACH_STEP"
    validate_boolean "UPDATE_MIRRORS" "$UPDATE_MIRRORS"
    validate_boolean "AUTO_INSTALL_DEPS" "$AUTO_INSTALL_DEPS"
    validate_boolean "ENABLE_FLATPAK" "$ENABLE_FLATPAK"
    validate_boolean "ENABLE_SECURITY_SCAN" "$ENABLE_SECURITY_SCAN"
    validate_boolean "ENABLE_ORPHAN_REMOVAL" "$ENABLE_ORPHAN_REMOVAL"
    validate_boolean "ENABLE_CACHE_CLEANUP" "$ENABLE_CACHE_CLEANUP"
    validate_boolean "SHOW_NEWS" "$SHOW_NEWS"
    validate_boolean "ENABLE_SYSTEM_REPORT" "$ENABLE_SYSTEM_REPORT"
    validate_boolean "REPORT_GPU_INFO" "$REPORT_GPU_INFO"
    validate_boolean "REPORT_TEMPERATURE" "$REPORT_TEMPERATURE"
    validate_boolean "REPORT_SMART_STATUS" "$REPORT_SMART_STATUS"
    validate_boolean "ENABLE_RKHUNTER" "$ENABLE_RKHUNTER"
    validate_boolean "ENABLE_ARCH_AUDIT" "$ENABLE_ARCH_AUDIT"
    validate_boolean "UPDATE_SECURITY_DATABASES" "$UPDATE_SECURITY_DATABASES"
    validate_boolean "DEBUG_MODE" "$DEBUG_MODE"
    
    # Validate choice values
    validate_choice "BACKUP_METHOD" "$BACKUP_METHOD" "auto" "timeshift" "snapper" "rsync" "none"
    validate_choice "AUR_HELPER" "$AUR_HELPER" "auto" "paru" "yay" "none"
    
    # Enable debug mode if requested
    if [[ "$DEBUG_MODE" == "true" ]]; then
        set -x
    fi
}

# Validate numeric values
validate_numeric() {
    local var_name="$1"
    local value="$2"
    local min="$3"
    local max="$4"
    
    if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < min )) || (( value > max )); then
        error "Invalid value for $var_name: $value (must be between $min and $max)"
        return 1
    fi
}

# Validate boolean values
validate_boolean() {
    local var_name="$1"
    local value="$2"
    
    if [[ "$value" != "true" && "$value" != "false" ]]; then
        error "Invalid value for $var_name: $value (must be 'true' or 'false')"
        return 1
    fi
}

# Validate choice values
validate_choice() {
    local var_name="$1"
    local value="$2"
    shift 2
    local valid_choices=("$@")
    
    local is_valid=false
    for choice in "${valid_choices[@]}"; do
        if [[ "$value" == "$choice" ]]; then
            is_valid=true
            break
        fi
    done
    
    if [[ "$is_valid" != "true" ]]; then
        error "Invalid value for $var_name: $value (must be one of: ${valid_choices[*]})"
        return 1
    fi
}

# Create a default configuration file for the user
create_default_config() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xanados_clean"
    local config_file="$config_dir/config.conf"
    
    if [[ -f "$config_file" ]]; then
        log "Configuration file already exists at $config_file"
        return 0
    fi
    
    log "Creating default configuration at $config_file"
    mkdir -p "$config_dir"
    
    if [[ -f "${SCRIPT_DIR:-}/config/default.conf" ]]; then
        cp "${SCRIPT_DIR:-}/config/default.conf" "$config_file"
        log "Default configuration created. Edit $config_file to customize settings."
    else
        error "Default configuration template not found"
        return 1
    fi
}

# Display current configuration
show_config() {
    printf "%b=== xanadOS Clean Configuration ===%b\n" "$BLUE" "$NC"
    printf "Configuration loaded from: %s\n" "${config_file:-built-in defaults}"
    printf "\n%bGeneral Settings:%b\n" "$CYAN" "$NC"
    printf "  LOG_FILE: %s\n" "$LOG_FILE"
    printf "  AUTO_MODE: %s\n" "$AUTO_MODE"
    printf "  ASK_EACH_STEP: %s\n" "$ASK_EACH_STEP"
    printf "\n%bBackup Settings:%b\n" "$CYAN" "$NC"
    printf "  BACKUP_METHOD: %s\n" "$BACKUP_METHOD"
    printf "  BACKUP_SKIP_THRESHOLD_DAYS: %s\n" "$BACKUP_SKIP_THRESHOLD_DAYS"
    printf "\n%bMaintenance Options:%b\n" "$CYAN" "$NC"
    printf "  ENABLE_FLATPAK: %s\n" "$ENABLE_FLATPAK"
    printf "  ENABLE_SECURITY_SCAN: %s\n" "$ENABLE_SECURITY_SCAN"
    printf "  ENABLE_ORPHAN_REMOVAL: %s\n" "$ENABLE_ORPHAN_REMOVAL"
    printf "  ENABLE_CACHE_CLEANUP: %s\n" "$ENABLE_CACHE_CLEANUP"
}

# Function to run pre/post maintenance scripts
run_custom_script() {
    local script_path="$1"
    local script_type="$2"
    
    if [[ -n "$script_path" && -f "$script_path" && -x "$script_path" ]]; then
        log "Running $script_type script: $script_path"
        if ! "$script_path"; then
            error "$script_type script failed: $script_path"
            return 1
        fi
    fi
}
