#!/usr/bin/env bats
# Tests for archlinux_clean.sh

load 'setup_suite'

setup() {
    source_script_functions "$PROJECT_ROOT/archlinux_clean.sh"
    create_mock_command "pacman" 0 "pacman 6.0.1"
    create_mock_command "ping" 0 ""
    create_mock_command "reflector" 0 ""
}

@test "require_pacman should pass when pacman is available" {
    run require_pacman
    [ "$status" -eq 0 ]
}

@test "require_pacman should fail when pacman is not available" {
    rm -f "$MOCK_BIN_DIR/pacman"
    run require_pacman
    [ "$status" -eq 1 ]
    [[ "$output" == *"pacman is required"* ]]
}

@test "check_network should return 0 when network is available" {
    run check_network
    [ "$status" -eq 0 ]
}

@test "check_network should return 1 when network is unavailable" {
    create_mock_command "ping" 1 ""
    run check_network
    [ "$status" -eq 1 ]
}

@test "log function should format messages correctly" {
    run log "Test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[+] Test message"* ]]
}

@test "error function should format error messages correctly" {
    run error "Error message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[!] Error message"* ]]
}

@test "show_progress should display progress bar correctly" {
    CURRENT_STEP=5
    TOTAL_STEPS=10
    run show_progress "Test step"
    [ "$status" -eq 0 ]
    [[ "$output" == *"(6/10)"* ]]
    [[ "$output" == *"Test step"* ]]
}

@test "choose_pkg_manager should detect existing paru" {
    create_mock_command "paru" 0 ""
    PKG_MGR=""
    AUTO_MODE=true
    run choose_pkg_manager
    [ "$status" -eq 0 ]
    [ "$PKG_MGR" = "paru" ]
}

@test "choose_pkg_manager should fall back to pacman when paru not found" {
    rm -f "$MOCK_BIN_DIR/paru"
    PKG_MGR=""
    AUTO_MODE=true
    run choose_pkg_manager
    [ "$status" -eq 0 ]
    [ "$PKG_MGR" = "pacman" ]
}

@test "update_tool_if_outdated should detect version differences" {
    # Mock pacman to show different versions
    cat > "$MOCK_BIN_DIR/pacman" <<'EOF'
#!/bin/bash
if [[ "$1" == "-Qi" ]]; then
    echo "Version         : 1.0.0"
elif [[ "$1" == "-Si" ]]; then
    echo "Version         : 2.0.0"
fi
EOF
    chmod +x "$MOCK_BIN_DIR/pacman"
    
    PKG_MGR="pacman"
    SUDO=""
    run update_tool_if_outdated "testpkg"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Updating testpkg from 1.0.0 to 2.0.0"* ]]
}

@test "pkg_mgr_run should use correct package manager" {
    PKG_MGR="pacman"
    SUDO=""
    run pkg_mgr_run "--version"
    [ "$status" -eq 0 ]
}

@test "run_step should execute function when not skipped" {
    ASK_EACH=false
    test_function() {
        echo "Function executed"
    }
    run run_step test_function "Test description"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Function executed"* ]]
}

teardown() {
    # Reset variables
    unset PKG_MGR SUDO AUTO_MODE ASK_EACH CURRENT_STEP
}
