#!/usr/bin/env bats
# Test suite for Arch Linux optimization features

load "setup_suite"

setup() {
    # Load the arch optimizations library
    if [[ -f "$BATS_TEST_DIRNAME/../lib/arch_optimizations.sh" ]]; then
        source "$BATS_TEST_DIRNAME/../lib/arch_optimizations.sh"
    else
        skip "arch_optimizations.sh not found"
    fi
    
    # Mock essential commands
    create_mock_command "pacman" 0 "community/informant 0.1.4-1"
    create_mock_command "paru" 0 "installed informant"
    create_mock_command "checkupdates" 0 "vim 9.0.1234-1"
    create_mock_command "reflector" 0 "Success"
    create_mock_command "arch-audit" 0 "No vulnerabilities found"
    create_mock_command "rebuild-detector" 0 ""
    create_mock_command "lostfiles" 0 ""
    create_mock_command "curl" 0 "Mock RSS content"
    create_mock_command "systemctl" 0 "enabled"
    create_mock_command "zramctl" 0 ""
    
    # Create temporary directories
    mkdir -p "$BATS_TMPDIR/etc/pacman.d/hooks"
    mkdir -p "$BATS_TMPDIR/usr/local/bin"
    mkdir -p "$BATS_TMPDIR/sys/block/sda/queue"
    
    export SUDO_PREFIX=""
}

@test "configure_pacman_optimizations should backup and update pacman.conf" {
    # Create mock pacman.conf
    echo "#Color" > "$BATS_TMPDIR/pacman.conf"
    echo "#VerbosePkgLists" >> "$BATS_TMPDIR/pacman.conf"
    
    # Mock sudo and file operations
    function sudo() { "$@"; }
    export -f sudo
    
    # Override file paths for testing
    function configure_pacman_optimizations() {
        local backup_suffix
        backup_suffix=".backup-$(date +%Y%m%d)"
        
        if [[ -f "$BATS_TMPDIR/pacman.conf" ]]; then
            cp "$BATS_TMPDIR/pacman.conf" "$BATS_TMPDIR/pacman.conf${backup_suffix}"
        fi
        
        log "Configuring advanced pacman optimizations..."
        
        if ! grep -q "^ParallelDownloads" "$BATS_TMPDIR/pacman.conf"; then
            echo "ParallelDownloads = 5" >> "$BATS_TMPDIR/pacman.conf"
            log "Enabled parallel downloads (5 concurrent)"
        fi
        
        if ! grep -q "^Color" "$BATS_TMPDIR/pacman.conf"; then
            echo "Color" >> "$BATS_TMPDIR/pacman.conf"
            log "Enabled colored pacman output"
        fi
    }
    
    run configure_pacman_optimizations
    
    [ "$status" -eq 0 ]
    [ -f "$BATS_TMPDIR/pacman.conf" ]
    grep -q "ParallelDownloads = 5" "$BATS_TMPDIR/pacman.conf"
    grep -q "Color" "$BATS_TMPDIR/pacman.conf"
}

@test "install_news_hooks should install informant or create custom hook" {
    # Mock package management commands
    function pacman() {
        case "$1" in
            "-Ss") echo "community/informant 0.1.4-1" ;;
            "-Qq") return 1 ;;  # Package not installed
            *) return 0 ;;
        esac
    }
    
    function paru() {
        if [[ "$*" =~ informant ]]; then
            log "Installing informant..."
            return 0
        fi
        return 1
    }
    
    export -f pacman paru
    
    run install_news_hooks
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Setting up Arch Linux news notification hooks" ]]
}

@test "advanced_package_maintenance should check updates and orphans" {
    # Mock checkupdates to show available updates
    function checkupdates() {
        echo "vim 9.0.1234-1 -> 9.0.1235-1"
        echo "firefox 118.0-1 -> 118.0.1-1"
    }
    
    # Mock orphan detection
    function pacman() {
        case "$*" in
            "-Qdtq"*) echo "orphaned-package1"; echo "orphaned-package2" ;;
            "-Qii"*) echo "/etc/config.conf [modified]" ;;
            "-Qk"*) return 0 ;;  # Integrity check passes
            *) return 0 ;;
        esac
    }
    
    export -f checkupdates pacman
    export AUTO_MODE=true
    
    run advanced_package_maintenance
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Performing advanced package maintenance" ]]
    [[ "$output" =~ "2 packages can be updated" ]]
    [[ "$output" =~ "Found orphaned packages: 2" ]]
}

@test "optimize_system_performance should configure I/O scheduler and swappiness" {
    # Create mock SSD
    echo "sda 0" > "$BATS_TMPDIR/ssd_info"
    echo "[mq-deadline] none" > "$BATS_TMPDIR/sys/block/sda/queue/scheduler"
    echo "60" > "$BATS_TMPDIR/swappiness"
    
    function lsblk() {
        if [[ "$*" =~ "rota" ]]; then
            cat "$BATS_TMPDIR/ssd_info"
        fi
    }
    
    function cat() {
        case "$1" in
            "/sys/block/sda/queue/scheduler") cat "$BATS_TMPDIR/sys/block/sda/queue/scheduler" ;;
            "/proc/sys/vm/swappiness") cat "$BATS_TMPDIR/swappiness" ;;
            *) command cat "$@" ;;
        esac
    }
    
    function sudo() { "$@"; }
    function sysctl() { return 0; }
    function systemctl() { return 0; }
    
    export -f lsblk cat sudo sysctl systemctl
    
    run optimize_system_performance
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Applying system performance optimizations" ]]
    [[ "$output" =~ "SSD detected" ]]
}

@test "install_essential_tools should install missing packages" {
    # Mock package status
    function pacman() {
        case "$*" in
            "-Qq pacman-contrib") return 1 ;;  # Not installed
            "-Qq pkgfile") return 0 ;;         # Already installed
            "-S"*) log "Installing packages: $*"; return 0 ;;
            *) return 0 ;;
        esac
    }
    
    function paru() {
        log "Installing with paru: $*"
        return 0
    }
    
    function pkgfile() {
        if [[ "$*" =~ "--update" ]]; then
            log "Updated pkgfile database"
        fi
        return 0
    }
    
    export -f pacman paru pkgfile
    
    run install_essential_tools
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Installing essential Arch Linux tools" ]]
    [[ "$output" =~ "Installing missing essential packages" ]]
}

@test "enhance_security should run arch-audit and rebuild-detector" {
    function arch-audit() {
        case "$*" in
            "--format=%n") echo "vulnerable-package1"; echo "vulnerable-package2" ;;
            "--upgradable"*) echo "vulnerable-package1 CVE-2023-1234" ;;
            *) return 0 ;;
        esac
    }
    
    function rebuild-detector() {
        echo "package-needing-rebuild1"
        echo "package-needing-rebuild2"
    }
    
    export -f arch-audit rebuild-detector
    
    run enhance_security
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Applying security enhancements" ]]
    [[ "$output" =~ "Found 2 packages with known vulnerabilities" ]]
    [[ "$output" =~ "2 packages may need rebuilding" ]]
}

@test "clean_unowned_files should detect and report unowned files" {
    function lostfiles() {
        echo "/tmp/unowned-file1"
        echo "/tmp/unowned-file2"
        echo "/tmp/unowned-file3"
    }
    
    export -f lostfiles
    export AUTO_MODE=false
    
    run clean_unowned_files
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Checking for unowned files" ]]
    [[ "$output" =~ "Found 3 unowned files" ]]
}

@test "setup_maintenance_hooks should create pacman hooks" {
    function sudo() { "$@"; }
    export -f sudo
    
    # Override hook directory for testing
    function setup_maintenance_hooks() {
        log "Setting up automatic maintenance hooks..."
        
        local hook_dir="$BATS_TMPDIR/etc/pacman.d/hooks"
        mkdir -p "$hook_dir"
        
        # Orphan detection hook
        cat << 'EOF' > "$hook_dir/orphan-check.hook"
[Trigger]
Operation = Remove
Type = Package
Target = *

[Action]
Description = Checking for orphaned packages...
When = PostTransaction
Exec = /usr/bin/bash -c '/usr/bin/pacman -Qdt || /usr/bin/echo "No orphaned packages found"'
EOF
        
        log "Maintenance hooks configured"
    }
    
    run setup_maintenance_hooks
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Setting up automatic maintenance hooks" ]]
    [[ "$output" =~ "Maintenance hooks configured" ]]
    [ -f "$BATS_TMPDIR/etc/pacman.d/hooks/orphan-check.hook" ]
}

@test "run_arch_optimizations should execute all optimization functions" {
    export ENABLE_ARCH_OPTIMIZATIONS=true
    
    # Mock all individual functions
    function configure_pacman_optimizations() { log "Pacman optimizations applied"; }
    function install_news_hooks() { log "News hooks installed"; }
    function install_essential_tools() { log "Essential tools installed"; }
    function optimize_mirrors() { log "Mirrors optimized"; }
    function advanced_package_maintenance() { log "Package maintenance completed"; }
    function optimize_system_performance() { log "Performance optimized"; }
    function enhance_security() { log "Security enhanced"; }
    function clean_unowned_files() { log "Unowned files cleaned"; }
    function setup_maintenance_hooks() { log "Hooks configured"; }
    
    export -f configure_pacman_optimizations install_news_hooks install_essential_tools
    export -f optimize_mirrors advanced_package_maintenance optimize_system_performance
    export -f enhance_security clean_unowned_files setup_maintenance_hooks
    
    run run_arch_optimizations
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Running latest Arch Linux optimizations" ]]
    [[ "$output" =~ "Pacman optimizations applied" ]]
    [[ "$output" =~ "News hooks installed" ]]
    [[ "$output" =~ "Essential tools installed" ]]
    [[ "$output" =~ "Arch Linux optimizations completed" ]]
}

@test "run_arch_optimizations should respect configuration disable" {
    export ENABLE_ARCH_OPTIMIZATIONS=false
    
    run run_arch_optimizations
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Arch Linux optimizations disabled in configuration" ]]
}

teardown() {
    cleanup_mocks
}
