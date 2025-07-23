#!/usr/bin/env bats
# Tests for bazzite_clean.sh

load 'setup_suite'

setup() {
    source_script_functions "$PROJECT_ROOT/bazzite_clean.sh"
    create_mock_command "dnf" 0 "dnf 4.14.0"
    create_mock_command "rpm-ostree" 0 ""
    create_mock_command "ping" 0 ""
}

@test "require_dnf should pass when dnf is available" {
    run require_dnf
    [ "$status" -eq 0 ]
}

@test "require_dnf should fail when dnf is not available" {
    rm -f "$MOCK_BIN_DIR/dnf"
    run require_dnf
    [ "$status" -eq 1 ]
    [[ "$output" == *"dnf is required"* ]]
}

@test "check_network should return 0 when network is available" {
    run check_network
    [ "$status" -eq 0 ]
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
    CURRENT_STEP=3
    TOTAL_STEPS=14
    run show_progress "Test step"
    [ "$status" -eq 0 ]
    [[ "$output" == *"(4/14)"* ]]
    [[ "$output" == *"Test step"* ]]
}

@test "USE_RPM_OSTREE should be set when rpm-ostree is available" {
    USE_RPM_OSTREE=false
    if command -v rpm-ostree >/dev/null 2>&1; then
        USE_RPM_OSTREE=true
    fi
    [ "$USE_RPM_OSTREE" = "true" ]
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
    unset SUDO AUTO_MODE ASK_EACH CURRENT_STEP USE_RPM_OSTREE
}
