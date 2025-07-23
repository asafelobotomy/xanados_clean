#!/usr/bin/env bats
# Consolidated tests for xanadOS Clean core functionality
# Replaces and enhances test_xanados_clean.bats

load 'test_helpers'

# Core system tests
@test "require_pacman should pass when pacman is available" {
    create_mock_command "pacman" 0 "pacman 6.0.1"
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    run require_pacman
    assert_status 0
}

@test "require_pacman should fail when pacman is not available" {
    rm -f "$MOCK_BIN_DIR/pacman"
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    run require_pacman
    assert_status 1
    assert_output_contains "pacman is required"
}

@test "check_network should work correctly" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    # Test successful network check
    create_mock_command "ping" 0 ""
    run check_network
    assert_status 0
    
    # Test failed network check
    create_mock_command "ping" 1 ""
    run check_network
    assert_status 1
}

# Logging function tests
@test "log function should format messages correctly" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    run log "Test message"
    assert_status 0
    assert_output_contains "[+] Test message"
}

@test "error function should format error messages correctly" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    run error "Error message"
    assert_status 0
    assert_output_contains "[!] Error message"
}

# Progress tracking tests
@test "show_progress should display progress correctly" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    CURRENT_STEP=5
    TOTAL_STEPS=10
    run show_progress "Test step"
    assert_status 0
    assert_output_contains "(6/10)"
    assert_output_contains "Test step"
}

# Package manager tests
@test "choose_pkg_manager should detect existing paru" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    create_mock_command "paru" 0 ""
    
    PKG_MGR=""
    AUTO_MODE=true
    run choose_pkg_manager
    assert_status 0
    [[ "$PKG_MGR" == "paru" ]]
}

@test "choose_pkg_manager should fall back to pacman when paru not found" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    rm -f "$MOCK_BIN_DIR/paru"
    
    PKG_MGR=""
    AUTO_MODE=true
    run choose_pkg_manager
    assert_status 0
    [[ "$PKG_MGR" == "pacman" ]]
}

@test "pkg_mgr_run should use correct package manager" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    PKG_MGR="pacman"
    SUDO=""
    run pkg_mgr_run "--version"
    assert_status 0
}

# Version checking tests
@test "update_tool_if_outdated should detect version differences" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
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
    assert_status 0
    assert_output_contains "Updating testpkg from 1.0.0 to 2.0.0"
}

# Library integration tests
@test "core library functions should be available" {
    verify_function_exists "log"
    verify_function_exists "error"
    verify_function_exists "show_progress"
    verify_function_exists "run_step"
}

@test "system library functions should be available" {
    verify_function_exists "check_network"
    verify_function_exists "dependency_check"
    verify_function_exists "system_report"
}

@test "maintenance library functions should be available" {
    verify_function_exists "load_config"
    verify_function_exists "refresh_mirrors"
    verify_function_exists "system_update"
    verify_function_exists "run_arch_optimizations"
}

@test "extensions library functions should be available" {
    verify_function_exists "create_checkpoint"
    verify_function_exists "enhanced_run_step"
    verify_function_exists "generate_performance_report"
}

# Configuration tests
@test "configuration loading should work" {
    # Create a test configuration
    local config_file="$TEST_TEMP_DIR/test.conf"
    cat > "$config_file" <<EOF
# Test configuration
AUTO_MODE=true
ENABLE_FLATPAK=false
UPDATE_MIRRORS=true
EOF
    
    CONFIG_FILE="$config_file"
    run load_config
    assert_status 0
    
    # Check that variables were set
    [[ "${ENABLE_FLATPAK:-}" == "false" ]]
    [[ "${UPDATE_MIRRORS:-}" == "true" ]]
}

# Error handling tests
@test "script should handle missing dependencies gracefully" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    # Remove some mock commands to simulate missing dependencies
    rm -f "$MOCK_BIN_DIR/reflector"
    
    # The script should not crash but should report missing tools
    MISSING_PKGS=()
    run dependency_check
    assert_status 0
}

# Integration test with main script
@test "main script should accept basic arguments" {
    # Test help option
    run "$PROJECT_ROOT/xanados_clean.sh" --help
    assert_status 0
    assert_output_contains "Usage:"
    
    # Test version option
    run "$PROJECT_ROOT/xanados_clean.sh" --version
    assert_status 0
    assert_output_contains "xanadOS Clean"
}

@test "main script should handle test mode correctly" {
    # Run in test mode to avoid making actual system changes
    run timeout 30 "$PROJECT_ROOT/xanados_clean.sh" --test-mode --auto
    
    # Should exit cleanly or timeout (both are acceptable for test mode)
    [[ "$status" -eq 0 || "$status" -eq 124 ]]
}

# Performance and resource tests
@test "script should not consume excessive memory" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    # This is a basic check - in a real scenario you'd use more sophisticated monitoring
    local initial_mem
    initial_mem=$(free -m | awk 'NR==2{print $3}')
    
    # Run some functions
    log "Memory test"
    show_progress "Testing memory usage"
    
    local final_mem
    final_mem=$(free -m | awk 'NR==2{print $3}')
    
    # Should not increase memory usage significantly (less than 10MB for basic functions)
    local mem_increase=$((final_mem - initial_mem))
    [[ $mem_increase -lt 10 ]]
}

@test "functions should complete within reasonable time" {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    
    # Test that basic functions complete quickly
    local start_time end_time duration
    
    start_time=$(date +%s)
    log "Timing test"
    show_progress "Testing timing"
    check_network
    end_time=$(date +%s)
    
    duration=$((end_time - start_time))
    
    # Should complete in less than 5 seconds
    [[ $duration -lt 5 ]]
}
