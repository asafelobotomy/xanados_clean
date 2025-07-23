#!/usr/bin/env bash
# Test suite setup for xanadOS Clean

setup_suite() {
    # Create temporary test directory
    local temp_dir
    temp_dir="$(mktemp -d)"
    export TEST_TEMP_DIR="$temp_dir"
    
    local test_dirname
    test_dirname="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    export BATS_TEST_DIRNAME="$test_dirname"
    
    local project_root
    project_root="$(dirname "$BATS_TEST_DIRNAME")"
    export PROJECT_ROOT="$project_root"
    
    # Create mock log directory
    export TEST_LOG_DIR="$TEST_TEMP_DIR/logs"
    mkdir -p "$TEST_LOG_DIR"
    
    # Export test environment variables
    export TEST_MODE=true
    export LOG_FILE="$TEST_LOG_DIR/test_system_maint.log"
    
    # Create mock system commands directory
    export MOCK_BIN_DIR="$TEST_TEMP_DIR/mock_bin"
    mkdir -p "$MOCK_BIN_DIR"
    export PATH="$MOCK_BIN_DIR:$PATH"
    
    # Setup mock sudo that doesn't require authentication
    cat > "$MOCK_BIN_DIR/sudo" <<'EOF'
#!/bin/bash
# Mock sudo for testing
if [[ "$1" == "-u" ]]; then
    shift 2  # Remove -u and username
fi
exec "$@"
EOF
    chmod +x "$MOCK_BIN_DIR/sudo"
}

teardown_suite() {
    # Clean up temporary test directory
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Helper function to create mock commands
create_mock_command() {
    local cmd_name="$1"
    local exit_code="${2:-0}"
    local output="${3:-}"
    
    cat > "$MOCK_BIN_DIR/$cmd_name" <<EOF
#!/bin/bash
echo "$output"
exit $exit_code
EOF
    chmod +x "$MOCK_BIN_DIR/$cmd_name"
}

# Helper function to source script functions for testing
source_script_functions() {
    local script_path="$1"
    
    # Create a test-safe version of the script
    local test_script
    test_script="$TEST_TEMP_DIR/test_$(basename "$script_path")"
    
    # Remove the main function call and add test mode detection
    sed '/^main "\$@"$/d' "$script_path" > "$test_script"
    echo 'TEST_MODE=${TEST_MODE:-false}' >> "$test_script"
    
    # Source the modified script
    # shellcheck source=/dev/null
    source "$test_script"
}
