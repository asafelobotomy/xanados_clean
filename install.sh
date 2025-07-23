#!/usr/bin/env bash
# install.sh - Installation and setup script for xanadOS Clean
# Provides automated installation with systemd integration like arch-maintenance

set -euo pipefail

# Color definitions
readonly GREEN='\033[0;32m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Installation paths
readonly INSTALL_DIR="/opt/xanados-clean"
readonly BIN_DIR="/usr/local/bin"
readonly SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
readonly SYSTEMD_SYSTEM_DIR="/etc/systemd/system"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log() {
    printf "${GREEN}[+] %s${NC}\n" "$1"
}

error() {
    printf "${RED}[!] %s${NC}\n" "$1" >&2
}

warning() {
    printf "${YELLOW}[!] %s${NC}\n" "$1"
}

info() {
    printf "${CYAN}[i] %s${NC}\n" "$1"
}

prompt() {
    printf "${BLUE}[?] %s${NC}" "$1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root!"
        error "Run as a regular user with sudo access."
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing_deps=()
    
    # Check for sudo access
    if ! sudo -n true 2>/dev/null; then
        if ! sudo -v; then
            error "sudo access required for installation"
            exit 1
        fi
    fi
    
    # Check for systemd
    if ! command -v systemctl >/dev/null 2>&1; then
        missing_deps+=("systemd")
    fi
    
    # Check for pacman (we're on Arch)
    if ! command -v pacman >/dev/null 2>&1; then
        error "This script is designed for Arch Linux systems"
        exit 1
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    log "All dependencies satisfied"
}

# Create installation directories
create_directories() {
    log "Creating installation directories..."
    
    sudo mkdir -p "$INSTALL_DIR"
    sudo mkdir -p "$BIN_DIR"
    mkdir -p "$SYSTEMD_USER_DIR"
    
    log "Directories created"
}

# Install xanadOS Clean files
install_files() {
    log "Installing xanadOS Clean files..."
    
    # Copy main script and libraries
    sudo cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/xanados_clean.sh"
    
    # Create symlink in PATH
    sudo ln -sf "$INSTALL_DIR/xanados_clean.sh" "$BIN_DIR/xanados-clean"
    
    # Set appropriate permissions
    sudo chown -R root:root "$INSTALL_DIR"
    sudo chmod -R 755 "$INSTALL_DIR"
    
    log "Files installed to $INSTALL_DIR"
    log "Symlink created: $BIN_DIR/xanados-clean"
}

# Create configuration file
create_config() {
    log "Creating default configuration..."
    
    if [[ -f "${HOME}/.config/xanados-clean.conf" ]]; then
        warning "Configuration file already exists at ${HOME}/.config/xanados-clean.conf"
        prompt "Overwrite? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log "Keeping existing configuration"
            return
        fi
    fi
    
    mkdir -p "${HOME}/.config"
    
    "$INSTALL_DIR/xanados_clean.sh" --create-config
    
    log "Configuration created at ${HOME}/.config/xanados-clean.conf"
}

# Create systemd service files
create_systemd_service() {
    log "Creating systemd service files..."
    
    # User service (recommended)
    cat > "$SYSTEMD_USER_DIR/xanados-clean.service" << EOF
[Unit]
Description=xanadOS Clean - Arch Linux System Maintenance
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$BIN_DIR/xanados-clean --auto
User=%i
Group=%i

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=%h/Documents %h/.cache %h/.config

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=xanados-clean

[Install]
WantedBy=default.target
EOF

    # Timer for user service
    cat > "$SYSTEMD_USER_DIR/xanados-clean.timer" << EOF
[Unit]
Description=Run xanadOS Clean weekly
Requires=xanados-clean.service

[Timer]
# Run every Sunday at 10:00 AM
OnCalendar=Sun 10:00
# Run 15 minutes after boot if we missed the scheduled time
OnBootSec=15min
# Add randomization to prevent all systems from running simultaneously
RandomizedDelaySec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # System service (alternative for system-wide installation)
    sudo tee "$SYSTEMD_SYSTEM_DIR/xanados-clean@.service" > /dev/null << EOF
[Unit]
Description=xanadOS Clean - Arch Linux System Maintenance (System)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$BIN_DIR/xanados-clean --auto
User=%i
Group=%i

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=xanados-clean

[Install]
WantedBy=multi-user.target
EOF

    log "Systemd service files created"
}

# Configure systemd automation
setup_automation() {
    log "Setting up automated execution..."
    
    info "Available automation options:"
    echo "1) User service (recommended) - runs as your user"
    echo "2) System service - runs system-wide"
    echo "3) Skip automation setup"
    
    prompt "Choose option [1]: "
    read -r choice
    choice=${choice:-1}
    
    case "$choice" in
        1)
            # Enable user service
            systemctl --user daemon-reload
            systemctl --user enable xanados-clean.timer
            systemctl --user start xanados-clean.timer
            
            log "User timer enabled and started"
            info "Next run: $(systemctl --user list-timers xanados-clean.timer --no-pager | grep xanados-clean | awk '{print $1, $2}')"
            ;;
        2)
            # Enable system service for current user
            sudo systemctl daemon-reload
            sudo systemctl enable "xanados-clean@${USER}.timer" 2>/dev/null || {
                warning "System timer not available, falling back to user timer"
                systemctl --user daemon-reload
                systemctl --user enable xanados-clean.timer
                systemctl --user start xanados-clean.timer
            }
            ;;
        3)
            log "Skipping automation setup"
            info "You can manually run: xanados-clean"
            ;;
        *)
            warning "Invalid choice, skipping automation"
            ;;
    esac
}

# Simple mode setup
setup_simple_mode() {
    log "Creating simple mode alias..."
    
    # Create a simple mode wrapper
    sudo tee "$BIN_DIR/xanados-clean-simple" > /dev/null << 'EOF'
#!/usr/bin/env bash
# xanados-clean-simple - Simple mode wrapper for casual users
exec /opt/xanados-clean/xanados_clean.sh --simple "$@"
EOF
    
    sudo chmod +x "$BIN_DIR/xanados-clean-simple"
    
    log "Simple mode available as: xanados-clean-simple"
}

# Uninstall function
uninstall() {
    log "Uninstalling xanadOS Clean..."
    
    # Stop and disable services
    systemctl --user stop xanados-clean.timer 2>/dev/null || true
    systemctl --user disable xanados-clean.timer 2>/dev/null || true
    sudo systemctl stop "xanados-clean@${USER}.timer" 2>/dev/null || true
    sudo systemctl disable "xanados-clean@${USER}.timer" 2>/dev/null || true
    
    # Remove files
    sudo rm -rf "$INSTALL_DIR"
    sudo rm -f "$BIN_DIR/xanados-clean"
    sudo rm -f "$BIN_DIR/xanados-clean-simple"
    rm -f "$SYSTEMD_USER_DIR/xanados-clean.service"
    rm -f "$SYSTEMD_USER_DIR/xanados-clean.timer"
    sudo rm -f "$SYSTEMD_SYSTEM_DIR/xanados-clean@.service"
    
    # Reload systemd
    systemctl --user daemon-reload 2>/dev/null || true
    sudo systemctl daemon-reload
    
    log "xanadOS Clean uninstalled"
    
    prompt "Remove configuration file? [y/N]: "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm -f "${HOME}/.config/xanados-clean.conf"
        log "Configuration removed"
    fi
}

# Show status
show_status() {
    log "xanadOS Clean Status:"
    
    if [[ -f "$INSTALL_DIR/xanados_clean.sh" ]]; then
        info "Installation: ✓ Installed at $INSTALL_DIR"
        info "Version: $($INSTALL_DIR/xanados_clean.sh --version)"
    else
        warning "Installation: ✗ Not installed"
        return 1
    fi
    
    if [[ -L "$BIN_DIR/xanados-clean" ]]; then
        info "Command: ✓ Available as 'xanados-clean'"
    else
        warning "Command: ✗ Not in PATH"
    fi
    
    if [[ -f "${HOME}/.config/xanados-clean.conf" ]]; then
        info "Configuration: ✓ ${HOME}/.config/xanados-clean.conf"
    else
        warning "Configuration: ✗ Not configured"
    fi
    
    # Check systemd status
    if systemctl --user is-enabled xanados-clean.timer >/dev/null 2>&1; then
        info "Automation: ✓ User timer enabled"
        local next_run
        next_run=$(systemctl --user list-timers xanados-clean.timer --no-pager 2>/dev/null | grep xanados-clean | awk '{print $1, $2}' || echo "Unknown")
        info "Next run: $next_run"
    elif sudo systemctl is-enabled "xanados-clean@${USER}.timer" >/dev/null 2>&1; then
        info "Automation: ✓ System timer enabled"
    else
        warning "Automation: ✗ Not configured"
    fi
}

# Main installation function
install() {
    log "Installing xanadOS Clean..."
    
    check_root
    check_dependencies
    create_directories
    install_files
    create_config
    create_systemd_service
    setup_automation
    setup_simple_mode
    
    log "Installation complete!"
    echo
    info "Available commands:"
    echo "  xanados-clean           - Full featured maintenance"
    echo "  xanados-clean-simple    - Simple mode for casual users"
    echo "  xanados-clean --help    - Show all options"
    echo
    info "Configuration: ${HOME}/.config/xanados-clean.conf"
    info "Logs: ~/Documents/system_maint.log"
    echo
    show_status
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [COMMAND]

xanadOS Clean Installation Script

COMMANDS:
    install         Install xanadOS Clean (default)
    uninstall       Remove xanadOS Clean
    status          Show installation status
    help            Show this help message

EXAMPLES:
    $0              # Install with interactive setup
    $0 install      # Same as above
    $0 status       # Check installation status
    $0 uninstall    # Remove installation

EOF
}

# Main script logic
main() {
    case "${1:-install}" in
        install)
            install
            ;;
        uninstall)
            uninstall
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
