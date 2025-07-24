#!/usr/bin/env bash
# maintenance.sh - Configuration management and Arch-specific maintenance operations
# Combines: config.sh + arch_optimizations.sh functionality

# Configuration file search paths (in order of priority)
if ! declare -p CONFIG_PATHS >/dev/null 2>&1; then
    readonly CONFIG_PATHS=(
        "${XDG_CONFIG_HOME:-$HOME/.config}/xanados_clean/config.conf"
        "${HOME}/.xanados_clean.conf"
        "/etc/xanados_clean/config.conf"
        "${SCRIPT_DIR:-}/config/default.conf"
    )
fi

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

# Check if pacman is locked and wait or handle appropriately
check_pacman_lock() {
    local lock_file="/var/lib/pacman/db.lck"
    local max_wait=30
    local wait_time=0
    
    while [[ -f "$lock_file" ]]; do
        if [[ $wait_time -eq 0 ]]; then
            warning "Pacman is currently locked by another process"
            log "Waiting for pacman lock to be released..."
        fi
        
        if [[ $wait_time -ge $max_wait ]]; then
            error "Pacman has been locked for more than ${max_wait} seconds"
            error "Database lock file: $lock_file"
            if [[ "${AUTO_MODE:-false}" != "true" ]]; then
                echo ""
                echo "⚠️  This usually means another package manager is running (pamac, yay, etc.)"
                echo "   If you're sure no other package operations are active, you can remove the lock."
                echo ""
                echo "Options:"
                echo "  1. Wait longer (another 30 seconds)"
                echo "  2. Remove pacman database lock file"
                echo "  3. Skip package operations"
                echo ""
                read -rp "Choose an option [1-3]: " choice
                case $choice in
                    1) 
                        log "Waiting another 30 seconds for lock release..."
                        max_wait=$((max_wait + 30)) 
                        ;;
                    2) 
                        warning "Removing pacman database lock file: $lock_file"
                        if ${SUDO} rm -f "$lock_file" 2>/dev/null; then
                            success "Lock file removed successfully"
                        else
                            error "Failed to remove lock file - check permissions"
                            return 1
                        fi
                        break
                        ;;
                    3) 
                        log "Skipping package operations due to lock"
                        return 1 
                        ;;
                    *) 
                        warning "Invalid choice, skipping package operations"
                        return 1 
                        ;;
                esac
            else
                return 1
            fi
        fi
        
        sleep 2
        wait_time=$((wait_time + 2))
    done
    
    return 0
}

# Proactively check for stale pacman lock files
check_stale_pacman_lock() {
    local lock_file="/var/lib/pacman/db.lck"
    
    if [[ -f "$lock_file" ]]; then
        # Check if the lock is actually stale
        local lock_age
        lock_age=$(( $(date +%s) - $(stat -c %Y "$lock_file" 2>/dev/null || echo 0) ))
        
        # If lock is older than 5 minutes, consider it potentially stale
        if [[ $lock_age -gt 300 ]]; then
            warning "Found potentially stale pacman lock file (${lock_age}s old)"
            
            # Enhanced check for pacman processes - more comprehensive
            # Check both process names and file locks
            local pacman_running=false
            
            # Check for running package manager processes
            if pgrep -x "pacman\|pamac\|yay\|paru" >/dev/null 2>&1; then
                pacman_running=true
            fi
            
            # Also check if any process has the database lock file open
            if command -v fuser >/dev/null 2>&1; then
                if fuser "$lock_file" >/dev/null 2>&1; then
                    pacman_running=true
                fi
            fi
            
            # Check for any pacman-related processes in a broader way
            if pgrep -f "pacman\|pamac\|yay\|paru" >/dev/null 2>&1; then
                pacman_running=true
            fi
            
            if [[ "$pacman_running" == "false" ]]; then
                if [[ "${AUTO_MODE:-false}" != "true" ]]; then
                    echo ""
                    echo "🔍 No active package manager processes detected."
                    echo "   The lock file appears to be stale (orphaned)."
                    echo ""
                    read -rp "Remove the stale lock file? [y/N]: " -n 1 remove_lock
                    echo ""
                    
                    if [[ "$remove_lock" =~ ^[Yy]$ ]]; then
                        if ${SUDO} rm -f "$lock_file" 2>/dev/null; then
                            success "Stale lock file removed successfully"
                            return 0
                        else
                            error "Failed to remove stale lock file"
                            return 1
                        fi
                    else
                        log "Keeping lock file as requested"
                        return 1
                    fi
                else
                    warning "Stale lock detected in auto mode - not removing automatically"
                    return 1
                fi
            else
                log "Active package manager processes found - lock is not stale"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Run command with timeout to prevent hanging
run_with_timeout() {
    local timeout_duration="$1"
    shift
    local cmd=("$@")
    
    if command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_duration" "${cmd[@]}"
    else
        # Fallback without timeout if command not available
        "${cmd[@]}"
    fi
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
    BACKUP_SKIP_THRESHOLD_DAYS="${BACKUP_SKIP_THRESHOLD_DAYS:-30}"
    RSYNC_DIR="${RSYNC_DIR:-/backup/arch}"
    
    # Feature toggles with validation
    ENABLE_FLATPAK="${ENABLE_FLATPAK:-auto}"
    ENABLE_SECURITY_SCAN="${ENABLE_SECURITY_SCAN:-true}"
    ENABLE_ORPHAN_REMOVAL="${ENABLE_ORPHAN_REMOVAL:-true}"
    ENABLE_CACHE_CLEANUP="${ENABLE_CACHE_CLEANUP:-true}"
    ENABLE_BTRFS_MAINTENANCE="${ENABLE_BTRFS_MAINTENANCE:-auto}"
    ENABLE_SSD_TRIM="${ENABLE_SSD_TRIM:-auto}"
    SHOW_NEWS="${SHOW_NEWS:-true}"
    ENABLE_SYSTEM_REPORT="${ENABLE_SYSTEM_REPORT:-true}"
    
    # Advanced features
    ENABLE_ARCH_OPTIMIZATIONS="${ENABLE_ARCH_OPTIMIZATIONS:-true}"
    ENABLE_PERFORMANCE_MONITORING="${ENABLE_PERFORMANCE_MONITORING:-true}"
    ENABLE_ERROR_RECOVERY="${ENABLE_ERROR_RECOVERY:-true}"
    
    # Validate boolean values
    validate_boolean "AUTO_MODE" "$AUTO_MODE"
    validate_boolean "ASK_EACH_STEP" "$ASK_EACH_STEP"
    validate_boolean "ENABLE_SECURITY_SCAN" "$ENABLE_SECURITY_SCAN"
    validate_boolean "ENABLE_ORPHAN_REMOVAL" "$ENABLE_ORPHAN_REMOVAL"
    validate_boolean "ENABLE_CACHE_CLEANUP" "$ENABLE_CACHE_CLEANUP"
    
    # Validate choice values
    validate_choice "BACKUP_METHOD" "$BACKUP_METHOD" "auto" "timeshift" "snapper" "rsync" "none"
    validate_choice "ENABLE_FLATPAK" "$ENABLE_FLATPAK" "auto" "true" "false"
    validate_choice "ENABLE_BTRFS_MAINTENANCE" "$ENABLE_BTRFS_MAINTENANCE" "auto" "true" "false"
    validate_choice "ENABLE_SSD_TRIM" "$ENABLE_SSD_TRIM" "auto" "true" "false"
    
    # Validate numeric values
    validate_numeric "MAX_LOG_SIZE" "$MAX_LOG_SIZE" 1 1000
    validate_numeric "BACKUP_SKIP_THRESHOLD_DAYS" "$BACKUP_SKIP_THRESHOLD_DAYS" 1 365
    
    # Validate file paths
    validate_path "LOG_FILE" "$LOG_FILE"
    if [[ "$BACKUP_METHOD" == "rsync" ]]; then
        validate_path "RSYNC_DIR" "$RSYNC_DIR"
    fi
}

# Validate numeric values with range checking
validate_numeric() {
    local var_name="$1"
    local value="$2"
    local min="$3"
    local max="$4"
    
    if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < min || value > max )); then
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

# Validate file paths
validate_path() {
    local var_name="$1"
    local path="$2"
    
    # Expand tilde and environment variables
    path="${path/#\~/$HOME}"
    path="${path//\$HOME/$HOME}"
    
    local dir
    dir=$(dirname "$path")
    if [[ ! -d "$dir" ]]; then
        log "Creating directory for $var_name: $dir"
        mkdir -p "$dir" || {
            error "Cannot create directory for $var_name: $dir"
            return 1
        }
    fi
}

# Display current configuration
display_config() {
    printf "\n%bCurrent Configuration:%b\n" "$BLUE" "$NC"
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

# Run custom pre/post maintenance scripts
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

# === ARCH LINUX OPTIMIZATIONS ===

# Advanced pacman optimizations
configure_pacman_optimizations() {
    local backup_suffix
    backup_suffix=".backup-$(date +%Y%m%d)"
    
    if [[ -f /etc/pacman.conf ]]; then
        ${SUDO} cp /etc/pacman.conf "/etc/pacman.conf${backup_suffix}"
    fi
    
    log "Configuring advanced pacman optimizations..."
    
    # Enable parallel downloads (default in pacman 7.0+, but ensure it's set)
    if ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
        echo "ParallelDownloads = 5" | ${SUDO} tee -a /etc/pacman.conf >/dev/null
        log "Enabled parallel downloads (5 concurrent)"
    fi
    
    # Enable colored output for better readability
    if ! grep -q "^Color" /etc/pacman.conf; then
        echo "Color" | ${SUDO} tee -a /etc/pacman.conf >/dev/null
        log "Enabled colored pacman output"
    fi
    
    # Enable verbose package lists
    if ! grep -q "^VerbosePkgLists" /etc/pacman.conf; then
        echo "VerbosePkgLists" | ${SUDO} tee -a /etc/pacman.conf >/dev/null
        log "Enabled verbose package lists"
    fi
    
    # Configure signature checking
    if ! grep -q "^SigLevel.*Required" /etc/pacman.conf; then
        ${SUDO} sed -i 's/^#SigLevel.*/SigLevel = Required DatabaseOptional/' /etc/pacman.conf
        log "Configured signature verification"
    fi
}

# Install and configure Arch Linux news hooks
install_news_hooks() {
    log "Setting up Arch Linux news notification hooks..."
    
    # Check if informant is available
    if pacman -Ss informant >/dev/null 2>&1; then
        if ! pacman -Qq informant >/dev/null 2>&1; then
            if command -v paru >/dev/null 2>&1; then
                paru -S --noconfirm informant || log "Failed to install informant"
            fi
        fi
    fi
    
    # Check if newscheck is available as alternative
    if ! command -v informant >/dev/null 2>&1 && pacman -Ss arch-audit >/dev/null 2>&1; then
        log "Creating custom Arch news checker"
        create_news_checker
    fi
}

# Create custom news checking script
create_news_checker() {
    # Create the news checking script
    cat << 'EOF' | ${SUDO} tee /usr/local/bin/check-arch-news.sh >/dev/null
#!/bin/bash
# Simple Arch Linux news checker
NEWS_URL="https://archlinux.org/feeds/news/"
# Use secure temporary file for cache instead of predictable location
CACHE_FILE=$(mktemp -t arch-news-cache.XXXXXX)
LAST_CHECK_FILE="$HOME/.arch-news-last-check"

# Get current timestamp
CURRENT_TIME=$(date +%s)

# Check if we need to fetch news (check every 24 hours)
if [[ -f "$LAST_CHECK_FILE" ]]; then
    LAST_CHECK=$(cat "$LAST_CHECK_FILE")
    TIME_DIFF=$((CURRENT_TIME - LAST_CHECK))
    
    # Skip if checked within last 24 hours
    if [[ $TIME_DIFF -lt 86400 ]]; then
        exit 0
    fi
fi

# Fetch and display recent news with secure SSL/TLS
if command -v curl >/dev/null; then
    echo "Checking for recent Arch Linux news..."
    # Use secure curl options: fail on error, show errors, follow redirects, require TLS 1.2+
    curl --fail --show-error --location --tlsv1.2 --silent "$NEWS_URL" | \
        grep -o '<title>[^<]*</title>' | head -5 | sed 's/<[^>]*>//g'
    echo "Visit https://archlinux.org/news/ for full details"
    echo "$CURRENT_TIME" > "$LAST_CHECK_FILE"
fi
EOF
    
    ${SUDO} chmod +x /usr/local/bin/check-arch-news.sh
    log "Created custom Arch Linux news checking hook"
}

# Enhanced package maintenance using latest techniques
advanced_package_maintenance() {
    log "Performing advanced package maintenance..."
    
    # Use checkupdates from pacman-contrib for safe update checking
    if command -v checkupdates >/dev/null; then
        log "Checking for available updates safely..."
        local updates
        updates=$(checkupdates | wc -l)
        if [[ $updates -gt 0 ]]; then
            log "$updates packages can be updated"
            if [[ "${AUTO_MODE:-false}" != "true" ]]; then
                read -p "Show available updates? (y/N): " -r
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    checkupdates
                fi
            fi
        fi
    fi
    
    # Advanced orphan detection and removal
    log "Checking for orphaned packages..."
    local orphans
    orphans=$(pacman -Qdtq 2>/dev/null | wc -l)
    if [[ $orphans -gt 0 ]]; then
        log "Found orphaned packages: $orphans"
        if [[ "${ENABLE_ORPHAN_REMOVAL:-true}" == "true" ]]; then
            log "Removing orphaned packages..."
            # shellcheck disable=SC2046
            ${SUDO} pacman -Rns --noconfirm $(pacman -Qdtq) 2>/dev/null || true
        fi
    fi
    
    # Check for modified configuration files
    log "Checking for modified configuration files..."
    if command -v pacman >/dev/null; then
        local modified_configs
        modified_configs=$(pacman -Qii | grep -c "MODIFIED" || echo "0")
        if [[ $modified_configs -gt 0 ]]; then
            log "Found $modified_configs modified configuration files"
            if [[ "${AUTO_MODE:-false}" != "true" ]]; then
                read -p "Show modified configs? (y/N): " -r
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    pacman -Qii | grep "MODIFIED"
                fi
            fi
        fi
    fi
    
    # Package integrity verification
    log "Verifying package integrity..."
    local integrity_issues
    integrity_issues=$(pacman -Qk 2>&1 | grep -cE "(warning|error)" || echo "0")
    if [[ $integrity_issues -gt 0 ]]; then
        warning "Found $integrity_issues package integrity issues"
    else
        log "Package integrity verification passed"
    fi
}

# Install essential Arch Linux tools
install_essential_tools() {
    log "Installing essential Arch Linux tools..."
    
    local essential_tools=(
        "pacman-contrib"    # paccache, checkupdates, rankmirrors
        "pkgfile"          # Fast file-to-package mapping
        "arch-audit"       # CVE vulnerability scanning
        "rebuild-detector" # Library dependency analysis
        "reflector"        # Intelligent mirror optimization
    )
    
    local missing_tools=()
    for tool in "${essential_tools[@]}"; do
        if ! pacman -Qq "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if (( ${#missing_tools[@]} > 0 )); then
        log "Installing missing essential packages: ${missing_tools[*]}"
        ${SUDO} pacman -S --needed --noconfirm "${missing_tools[@]}"
        
        # Update pkgfile database if installed
        if pacman -Qq pkgfile >/dev/null 2>&1; then
            log "Updating pkgfile database..."
            ${SUDO} pkgfile --update
        fi
    else
        log "All essential tools are already installed"
    fi
}

# Optimize mirrors using reflector
optimize_mirrors() {
    if ! command -v reflector >/dev/null 2>&1; then
        log "Reflector not available, skipping mirror optimization"
        return 0
    fi
    
    log "Optimizing package mirrors..."
    
    # Backup current mirrorlist
    ${SUDO} cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    
    # Generate optimized mirrorlist
    ${SUDO} reflector \
        --age 12 \
        --protocol https \
        --sort rate \
        --save /etc/pacman.d/mirrorlist \
        --country "United States,Canada,Germany,France,United Kingdom" \
        --latest 20 \
        --fastest 10
    
    log "Mirror optimization completed"
}

# Apply security enhancements
enhance_security() {
    log "Applying security enhancements..."
    
    # CVE vulnerability scanning with arch-audit
    if command -v arch-audit >/dev/null; then
        log "Scanning for known vulnerabilities..."
        local security_issues
        security_issues=$(arch-audit --format="%n" 2>/dev/null | wc -l)
        if [[ $security_issues -gt 0 ]]; then
            log "Found $security_issues packages with known vulnerabilities"
            arch-audit --upgradable --format="%n %c" 2>/dev/null | head -10
        else
            log "No known security vulnerabilities found"
        fi
    fi
    
    # Check for packages needing rebuild after library updates
    if command -v rebuild-detector >/dev/null; then
        log "Checking for packages needing rebuild..."
        local rebuild_needed
        rebuild_needed=$(rebuild-detector 2>/dev/null | wc -l)
        if [[ $rebuild_needed -gt 0 ]]; then
            log "$rebuild_needed packages may need rebuilding"
            rebuild-detector 2>/dev/null | head -5
        fi
    fi
}

# Clean unowned files
clean_unowned_files() {
    log "Checking for unowned files..."
    
    if command -v lostfiles >/dev/null; then
        local unowned_files
        unowned_files=$(lostfiles 2>/dev/null | wc -l)
        if [[ $unowned_files -gt 0 ]]; then
            log "Found $unowned_files unowned files"
            if [[ "${AUTO_MODE:-false}" != "true" ]]; then
                read -p "Show unowned files? (y/N): " -r
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    lostfiles 2>/dev/null | head -20
                fi
            fi
        else
            log "No unowned files found"
        fi
    fi
}

# System performance optimizations
optimize_system_performance() {
    log "Applying system performance optimizations..."
    
    # SSD I/O scheduler optimization
    if [[ -n "${DETECTED_STORAGE[*]}" ]]; then
        for storage in "${DETECTED_STORAGE[@]}"; do
            if [[ "$storage" =~ SSD ]]; then
                local device
                device=$(echo "$storage" | cut -d' ' -f1)
                log "SSD detected: $device - optimizing I/O scheduler"
                echo "mq-deadline" | ${SUDO} tee "/sys/block/$device/queue/scheduler" >/dev/null 2>&1 || true
            fi
        done
    fi
    
    # Swappiness adjustment for better desktop performance
    local current_swappiness
    current_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
    if [[ $current_swappiness -gt 10 ]]; then
        log "Adjusting swappiness for better desktop performance"
        echo 10 | ${SUDO} tee /proc/sys/vm/swappiness >/dev/null 2>&1 || true
    fi
}

# Configure automatic maintenance hooks
setup_maintenance_hooks() {
    log "Setting up automatic maintenance hooks..."
    
    local hook_dir="/etc/pacman.d/hooks"
    ${SUDO} mkdir -p "$hook_dir"
    
    # Orphan detection hook
    cat << 'EOF' | ${SUDO} tee "$hook_dir/orphan-check.hook" >/dev/null
[Trigger]
Operation = Remove
Type = Package
Target = *

[Action]
Description = Checking for orphaned packages...
When = PostTransaction
Exec = /usr/bin/bash -c '/usr/bin/pacman -Qdt || /usr/bin/echo "No orphaned packages found"'
EOF
    
    # Pacdiff hook for configuration file management
    if command -v pacdiff >/dev/null; then
        cat << 'EOF' | ${SUDO} tee "$hook_dir/pacdiff-check.hook" >/dev/null
[Trigger]
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = Checking for .pacnew and .pacsave files...
When = PostTransaction
Exec = /usr/bin/bash -c 'if /usr/bin/pacdiff --output; then echo "Run pacdiff to merge configuration files"; fi'
EOF
    fi
    
    log "Maintenance hooks configured"
}

# Main function to run all Arch optimizations
run_arch_optimizations() {
    if [[ "${ENABLE_ARCH_OPTIMIZATIONS:-true}" == "true" ]]; then
        log "Running latest Arch Linux optimizations..."
        
        configure_pacman_optimizations
        install_news_hooks
        install_essential_tools
        optimize_mirrors
        advanced_package_maintenance
        optimize_system_performance
        enhance_security
        clean_unowned_files
        setup_maintenance_hooks
        
        log "Arch Linux optimizations completed"
    else
        log "Arch Linux optimizations disabled in configuration"
    fi
}

# === CORE MAINTENANCE OPERATIONS ===

# Mirror refresh
refresh_mirrors() {
    print_banner "Refresh Mirrors"
    if ! check_network; then
        summary "No network, skipping mirror refresh."
        return
    fi
    
    # Check for pacman lock before proceeding
    if ! check_pacman_lock; then
        warning "Skipping mirror refresh due to pacman lock"
        return 1
    fi
    
    log "Refreshing mirrorlist before any installs or upgrades..."
    if ! run_with_timeout 120 "${SUDO}" pacman -Sy --noconfirm reflector; then
        warning "Reflector installation timed out, using existing mirrors"
    fi
    optimize_mirrors
    if ! run_with_timeout 60 "${SUDO}" pacman -Sy --noconfirm; then
        warning "Mirror refresh timed out, continuing with existing mirrors"
    fi
    summary "Package mirrors refreshed and optimized."
}

# System package update
system_update() {
    print_banner "System Update"
    
    # Check for pacman lock before proceeding
    if ! check_pacman_lock; then
        warning "Skipping system update due to pacman lock"
        return 1
    fi
    
    log "Starting system update with timeout protection..."
    if [[ ${PKG_MGR} == pacman ]]; then
        if ! run_with_timeout 300 "${SUDO}" pacman -Syu --noconfirm; then
            warning "System update timed out or failed, continuing with other operations"
            return 1
        fi
    else
        if ! run_with_timeout 300 pkg_mgr_run -Syu --noconfirm; then
            warning "System update timed out or failed, continuing with other operations"
            return 1
        fi
    fi
    summary "System packages updated."
}

# Flatpak update
flatpak_update() {
    if [[ "${ENABLE_FLATPAK:-auto}" == "false" ]]; then
        return 0
    fi
    
    if command -v flatpak &>/dev/null; then
        print_banner "Flatpak Update"
        flatpak update --noninteractive -y
        summary "Flatpak packages updated."
    elif [[ "${ENABLE_FLATPAK:-auto}" == "true" ]]; then
        warning "Flatpak enabled but not installed"
    fi
}

# Remove orphaned packages
remove_orphans() {
    print_banner "Remove Orphans"
    
    if [[ "${ENABLE_ORPHAN_REMOVAL:-true}" != "true" ]]; then
        summary "Orphan removal disabled in configuration"
        return 0
    fi
    
    mapfile -t orphans < <(${SUDO} pacman -Qtdq 2>/dev/null || true)
    if (( ${#orphans[@]} )); then
        ${SUDO} pacman -Rns --noconfirm "${orphans[@]}"
        summary "Removed ${#orphans[@]} orphaned packages."
    else
        summary "No orphan packages found."
    fi
}

# Cache cleanup
cache_cleanup() {
    print_banner "Cache Cleanup"
    
    if [[ "${ENABLE_CACHE_CLEANUP:-true}" != "true" ]]; then
        summary "Cache cleanup disabled in configuration"
        return 0
    fi
    
    if command -v paccache &>/dev/null; then
        ${SUDO} paccache -r
        summary "Pacman cache cleaned."
    fi
    
    if [[ ${AUTO_MODE} != true ]]; then
        read -rp $'\nClean ~/.cache directory? [y/N] ' clean_home
    else
        clean_home=""
    fi
    
    if [[ ${clean_home,,} =~ ^y ]]; then
        # Remove all files, including dotfiles, while preventing globbing issues
        shopt -s dotglob
        rm -rf -- ~/.cache/*
        shopt -u dotglob
        summary "Home cache cleaned."
    fi
    
    ${SUDO} journalctl --vacuum-time=7d
    summary "Journal logs rotated."
}

# Security scan
security_scan() {
    print_banner "Security Scan"
    
    if [[ "${ENABLE_SECURITY_SCAN:-true}" != "true" ]]; then
        summary "Security scan disabled in configuration"
        return 0
    fi
    
    if [[ ! " ${DISABLED_FEATURES[*]} " =~ " arch-audit " ]]; then
        if arch-audit | grep -q CVE; then
            summary "⚠️ Vulnerable packages found."
        else
            summary "No vulnerabilities detected."
        fi
    fi

    if [[ ! " ${DISABLED_FEATURES[*]} " =~ " rkhunter " ]]; then
        update_tool_if_outdated rkhunter
        ${SUDO} rkhunter --update
        if ${SUDO} rkhunter --check --skip-keypress --rwo | grep -q Warning; then
            summary "⚠️ rkhunter reported warnings."
        else
            summary "rkhunter scan clean."
        fi
    fi
}

# Backup operations
pre_backup() {
    print_banner "System Backup"
    
    if [[ "${BACKUP_METHOD:-auto}" == "none" ]]; then
        summary "Backup disabled in configuration"
        return 0
    fi
    
    local now
    now=$(date +%s)
    local threshold=$((${BACKUP_SKIP_THRESHOLD_DAYS:-30} * 24 * 60 * 60))

    # Timeshift backup
    if [[ "${BACKUP_METHOD:-auto}" == "auto" || "${BACKUP_METHOD:-auto}" == "timeshift" ]]; then
        if command -v timeshift &>/dev/null; then
            local last_ts
            last_ts=$(${SUDO} find /timeshift/snapshots -maxdepth 1 -type d \
                -name '????-??-??_*' -printf '%T@\n' 2>/dev/null | sort -rn | head -n1)
            if [[ -n $last_ts ]] && (( now - ${last_ts%.*} < threshold )); then
                summary "Recent Timeshift snapshot found. Skipping backup step."
                return
            fi
            ${SUDO} timeshift --create --comments "Pre-maintenance backup" --tags D
            summary "System backup created using Timeshift."
            return
        fi
    fi
    
    # Snapper backup
    if [[ "${BACKUP_METHOD:-auto}" == "auto" || "${BACKUP_METHOD:-auto}" == "snapper" ]]; then
        if command -v snapper &>/dev/null; then
            local last_snap
            last_snap=$(${SUDO} snapper list 2>/dev/null | awk 'NR>2 {print $5" "$6}' | tail -n1)
            if [[ -n $last_snap ]]; then
                local snap_ts
                snap_ts=$(date -d "$last_snap" +%s 2>/dev/null || echo 0)
                if (( now - snap_ts < threshold )); then
                    summary "Recent Snapper snapshot found. Skipping backup step."
                    return
                fi
            fi
            ${SUDO} snapper create -d "Pre-maintenance backup"
            summary "System backup created using Snapper."
            return
        fi
    fi

    # Rsync backup
    if [[ "${BACKUP_METHOD:-auto}" == "rsync" ]]; then
        rsync_backup
        return
    fi
    
    if [[ "${BACKUP_METHOD:-auto}" == "auto" ]]; then
        summary "No backup tools found - skipping backup step."
    fi
}

# Rsync backup implementation
rsync_backup() {
    local rsync_dir="${RSYNC_DIR:-/backup/arch}"
    
    if [[ ! -d "$rsync_dir" ]]; then
        if [[ "${AUTO_MODE:-false}" == "true" ]]; then
            summary "Rsync backup directory does not exist - skipping."
            return
        fi
        read -rp "Create rsync backup directory at $rsync_dir? [y/N] " create_dir
        if [[ ${create_dir,,} =~ ^y ]]; then
            ${SUDO} mkdir -p "$rsync_dir"
        else
            summary "Rsync backup skipped."
            return
        fi
    fi
    
    log "Creating rsync backup to $rsync_dir"
    ${SUDO} rsync -aAXv / "$rsync_dir" \
        --exclude={/dev/*,/proc/*,/sys/*,/tmp/*,/run/*,/mnt/*,/media/*,/lost+found} \
        2>/dev/null || {
        warning "Rsync backup encountered errors"
        return 1
    }
    summary "Rsync backup completed to ${rsync_dir}"
}

# Display Arch news
display_arch_news() {
    print_banner "Arch News"
    
    if [[ "${SHOW_NEWS:-true}" != "true" ]]; then
        summary "Arch news display disabled in configuration"
        return 0
    fi
    
    if ! check_network; then
        summary "No network, skipping Arch news."
        return
    fi
    
    if command -v curl &>/dev/null && command -v xmlstarlet &>/dev/null; then
        curl -s https://archlinux.org/feeds/news/ \
            | xmlstarlet sel -t -m '//item/title' -v . -n \
            | head -n 5
        summary "Latest Arch news displayed."
    elif command -v /usr/local/bin/check-arch-news.sh &>/dev/null; then
        /usr/local/bin/check-arch-news.sh
        summary "Arch news checked."
    else
        summary "News tools not available - install curl and xmlstarlet for news display."
    fi
}

# Export maintenance functions
export -f load_config validate_config display_config run_custom_script
export -f configure_pacman_optimizations install_news_hooks advanced_package_maintenance
export -f install_essential_tools optimize_mirrors enhance_security clean_unowned_files
export -f optimize_system_performance setup_maintenance_hooks run_arch_optimizations
export -f refresh_mirrors system_update flatpak_update remove_orphans cache_cleanup
export -f security_scan pre_backup rsync_backup display_arch_news
export -f validate_numeric validate_boolean validate_choice validate_path
