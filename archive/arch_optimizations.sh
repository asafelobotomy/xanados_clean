#!/usr/bin/env bash
# lib/arch_optimizations.sh - Latest Arch Linux optimization techniques
# Based on ArchWiki recommendations and community best practices (2024-2025)

# Advanced pacman optimizations
configure_pacman_optimizations() {
    local backup_suffix
    backup_suffix=".backup-$(date +%Y%m%d)"
    
    if [[ -f /etc/pacman.conf ]]; then
        sudo cp /etc/pacman.conf "/etc/pacman.conf${backup_suffix}"
    fi
    
    log "Configuring advanced pacman optimizations..."
    
    # Enable parallel downloads (default in pacman 7.0+, but ensure it's set)
    if ! grep -q "^ParallelDownloads" /etc/pacman.conf; then
        echo "ParallelDownloads = 5" | sudo tee -a /etc/pacman.conf >/dev/null
        log "Enabled parallel downloads (5 concurrent)"
    fi
    
    # Enable colored output for better readability
    if ! grep -q "^Color" /etc/pacman.conf; then
        echo "Color" | sudo tee -a /etc/pacman.conf >/dev/null
        log "Enabled colored pacman output"
    fi
    
    # Enable verbose package lists
    if ! grep -q "^VerbosePkgLists" /etc/pacman.conf; then
        echo "VerbosePkgLists" | sudo tee -a /etc/pacman.conf >/dev/null
        log "Enabled verbose package lists"
    fi
    
    # Configure signature checking
    if ! grep -q "^SigLevel.*Required" /etc/pacman.conf; then
        sudo sed -i 's/^#SigLevel.*/SigLevel = Required DatabaseOptional/' /etc/pacman.conf
        log "Configured signature verification"
    fi
}

# Install and configure Arch Linux news hooks
install_news_hooks() {
    log "Setting up Arch Linux news notification hooks..."
    
    # Check if informant is available
    if pacman -Ss informant >/dev/null 2>&1; then
        if ! pacman -Qq informant >/dev/null 2>&1; then
            paru -S --noconfirm informant || log "Failed to install informant"
        fi
    fi
    
    # Check if newscheck is available as alternative
    if pacman -Ss newscheck >/dev/null 2>&1; then
        if ! pacman -Qq newscheck >/dev/null 2>&1; then
            paru -S --noconfirm newscheck || log "newscheck not available"
        fi
    fi
    
    # Create custom arch news hook if tools not available
    if ! pacman -Qq informant newscheck >/dev/null 2>&1; then
        create_custom_news_hook
    fi
}

# Create custom news checking hook
create_custom_news_hook() {
    local hook_dir="/etc/pacman.d/hooks"
    local hook_file="${hook_dir}/arch-news-check.hook"
    
    if [[ ! -d "$hook_dir" ]]; then
        sudo mkdir -p "$hook_dir"
    fi
    
    cat << 'EOF' | sudo tee "$hook_file" >/dev/null
[Trigger]
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = Checking Arch Linux news...
When = PreTransaction
Exec = /usr/local/bin/check-arch-news.sh
EOF
    
    # Create the news checking script
    cat << 'EOF' | sudo tee /usr/local/bin/check-arch-news.sh >/dev/null
#!/bin/bash
# Simple Arch Linux news checker
NEWS_URL="https://archlinux.org/feeds/news/"
CACHE_FILE="/tmp/arch-news-cache"
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

# Fetch and display recent news
if command -v curl >/dev/null; then
    echo "Checking for recent Arch Linux news..."
    curl -s "$NEWS_URL" | grep -o '<title>[^<]*</title>' | head -5 | sed 's/<[^>]*>//g'
    echo "Visit https://archlinux.org/news/ for full details"
    echo "$CURRENT_TIME" > "$LAST_CHECK_FILE"
fi
EOF
    
    sudo chmod +x /usr/local/bin/check-arch-news.sh
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
    orphans=$(pacman -Qdtq 2>/dev/null || true)
    if [[ -n "$orphans" ]]; then
        log "Found orphaned packages: $(echo "$orphans" | wc -l)"
        if [[ "${AUTO_MODE:-false}" == "true" ]]; then
            echo "$orphans" | sudo pacman -Rns --noconfirm -
        else
            echo "$orphans"
            read -p "Remove these orphaned packages? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "$orphans" | sudo pacman -Rns --noconfirm -
            fi
        fi
    fi
    
    # Check for broken dependencies
    log "Checking for broken dependencies..."
    if pacman -Qk >/dev/null 2>&1; then
        log "Package integrity check passed"
    else
        error "Some packages have integrity issues"
    fi
    
    # List changed configuration files
    log "Checking for modified configuration files..."
    local modified_configs
    modified_configs=$(pacman -Qii 2>/dev/null | awk '/\[modified\]/ {print $(NF - 1)}' || true)
    if [[ -n "$modified_configs" ]]; then
        log "Modified configuration files found:"
        echo "$modified_configs"
    fi
}

# Optimize system performance based on latest recommendations
optimize_system_performance() {
    log "Applying system performance optimizations..."
    
    # Configure I/O scheduler for SSDs
    if lsblk -d -o name,rota | grep -q "0$"; then
        log "SSD detected, optimizing I/O scheduler..."
        for disk in $(lsblk -d -o name,rota | awk '$2==0 {print $1}'); do
            if [[ -f "/sys/block/$disk/queue/scheduler" ]]; then
                current_scheduler=$(cat "/sys/block/$disk/queue/scheduler" | grep -o '\[.*\]' | tr -d '[]')
                if [[ "$current_scheduler" != "none" && "$current_scheduler" != "mq-deadline" ]]; then
                    echo "mq-deadline" | sudo tee "/sys/block/$disk/queue/scheduler" >/dev/null 2>&1 || true
                    log "Set I/O scheduler to mq-deadline for $disk"
                fi
            fi
        done
    fi
    
    # Enable zram if available and not already configured
    if command -v zramctl >/dev/null && ! zramctl | grep -q zram; then
        if [[ -f /usr/lib/systemd/system/systemd-zram-setup@.service ]]; then
            sudo systemctl enable --now systemd-zram-setup@zram0.service 2>/dev/null || true
            log "Enabled zram compression"
        fi
    fi
    
    # Configure swappiness for better responsiveness
    local current_swappiness
    current_swappiness=$(cat /proc/sys/vm/swappiness)
    if [[ $current_swappiness -gt 10 ]]; then
        echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.d/99-swappiness.conf >/dev/null
        sudo sysctl vm.swappiness=10 >/dev/null 2>&1 || true
        log "Optimized swappiness for desktop use"
    fi
    
    # Enable transparent hugepages for better memory management
    if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
        local thp_setting
        thp_setting=$(cat /sys/kernel/mm/transparent_hugepage/enabled)
        if [[ ! "$thp_setting" =~ \[madvise\] ]]; then
            echo madvise | sudo tee /sys/kernel/mm/transparent_hugepage/enabled >/dev/null 2>&1 || true
            log "Configured transparent hugepages"
        fi
    fi
}

# Install essential development and maintenance tools
install_essential_tools() {
    log "Installing essential Arch Linux tools..."
    
    local essential_packages=(
        "pacman-contrib"    # Essential pacman utilities
        "pkgfile"          # File search utility
        "rebuild-detector" # Detect packages needing rebuild
        "reflector"        # Mirror ranking tool
        "downgrade"        # Package downgrade utility
        "expac"            # Data extraction tool
        "pacutils"         # Additional pacman utilities
        "arch-audit"       # Security auditing
        "lostfiles"        # Find unowned files
    )
    
    local missing_packages=()
    for package in "${essential_packages[@]}"; do
        if ! pacman -Qq "$package" >/dev/null 2>&1; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        log "Installing missing essential packages: ${missing_packages[*]}"
        if command -v paru >/dev/null; then
            paru -S --needed --noconfirm "${missing_packages[@]}" || log "Some packages may not be available"
        else
            sudo pacman -S --needed --noconfirm "${missing_packages[@]}" || log "Some packages may not be available"
        fi
    fi
    
    # Update pkgfile database
    if command -v pkgfile >/dev/null; then
        sudo pkgfile --update >/dev/null 2>&1 || true
        log "Updated pkgfile database"
    fi
}

# Advanced mirror optimization
optimize_mirrors() {
    log "Optimizing mirror configuration..."
    
    if command -v reflector >/dev/null; then
        log "Running reflector to find fastest mirrors..."
        sudo reflector --verbose --latest 20 --protocol https --sort rate \
            --save /etc/pacman.d/mirrorlist --connection-timeout 2 \
            --download-timeout 5 >/dev/null 2>&1 || {
            log "Reflector failed, keeping current mirrorlist"
        }
    else
        log "Reflector not available, skipping mirror optimization"
    fi
}

# Security enhancements
enhance_security() {
    log "Applying security enhancements..."
    
    # Run arch-audit if available
    if command -v arch-audit >/dev/null; then
        log "Running security audit..."
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

# Configure automatic maintenance hooks
setup_maintenance_hooks() {
    log "Setting up automatic maintenance hooks..."
    
    local hook_dir="/etc/pacman.d/hooks"
    sudo mkdir -p "$hook_dir"
    
    # Orphan detection hook
    cat << 'EOF' | sudo tee "$hook_dir/orphan-check.hook" >/dev/null
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
        cat << 'EOF' | sudo tee "$hook_dir/pacdiff-check.hook" >/dev/null
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

# Main function to run all optimizations
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

# Export functions for use in main script
export -f configure_pacman_optimizations
export -f install_news_hooks
export -f advanced_package_maintenance
export -f optimize_system_performance
export -f install_essential_tools
export -f optimize_mirrors
export -f enhance_security
export -f clean_unowned_files
export -f setup_maintenance_hooks
export -f run_arch_optimizations
