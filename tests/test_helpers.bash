#!/usr/bin/env bash
# Consolidated test configuration and helper functions
# Replaces and enhances setup_suite.bash functionality

# Test environment configuration
setup_test_environment() {
    # Create temporary test directory with proper cleanup
    local temp_dir
    temp_dir="$(mktemp -d -t xanados_test.XXXXXX)"
    export TEST_TEMP_DIR="$temp_dir"
    
    # Register cleanup trap
    trap cleanup_test_environment EXIT
    
    # Set project paths
    local test_dirname
    test_dirname="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    export BATS_TEST_DIRNAME="$test_dirname"
    
    local project_root
    project_root="$(dirname "$BATS_TEST_DIRNAME")"
    export PROJECT_ROOT="$project_root"
    
    # Create test log directory
    export TEST_LOG_DIR="$TEST_TEMP_DIR/logs"
    mkdir -p "$TEST_LOG_DIR"
    
    # Set test mode environment variables
    export TEST_MODE=true
    export LOG_FILE="$TEST_LOG_DIR/test_system_maint.log"
    export LOG_DIR="$TEST_LOG_DIR"
    export AUTO_MODE=true
    export SUDO=""  # Disable sudo in tests
    
    # Create mock commands directory
    export MOCK_BIN_DIR="$TEST_TEMP_DIR/mock_bin"
    mkdir -p "$MOCK_BIN_DIR"
    
    # Prepend mock directory to PATH
    export PATH="$MOCK_BIN_DIR:$PATH"
    
    # Create essential mock commands
    create_essential_mocks
    
    # Source the main libraries for testing
    source_project_libraries
}

# Cleanup test environment
cleanup_test_environment() {
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Create essential mock commands needed by most tests
create_essential_mocks() {
    # Mock sudo that just executes commands without privilege escalation
    cat > "$MOCK_BIN_DIR/sudo" <<'EOF'
#!/bin/bash
# Mock sudo for testing - just pass through commands
if [[ "$1" == "-u" ]]; then
    shift 2  # Remove -u and username
fi
exec "$@"
EOF
    chmod +x "$MOCK_BIN_DIR/sudo"
    
    # Mock pacman with basic responses
    cat > "$MOCK_BIN_DIR/pacman" <<'EOF'
#!/bin/bash
case "$1" in
    "-Qi")
        echo "Name            : $2"
        echo "Version         : 1.0.0-1"
        echo "Description     : Mock package"
        ;;
    "-Si")
        echo "Repository      : core"
        echo "Name            : $2"
        echo "Version         : 1.0.0-1"
        ;;
    "-Qtdq")
        # Return no orphans by default
        exit 0
        ;;
    "-Sy"|"-Syu"|"-S")
        echo "mock: package operation $*"
        ;;
    *)
        echo "mock pacman: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/pacman"
    
    # Mock ping
    cat > "$MOCK_BIN_DIR/ping" <<'EOF'
#!/bin/bash
# Mock ping - default to success
echo "PING $3 (1.1.1.1): 56 data bytes"
echo "64 bytes from 1.1.1.1: seq=0 ttl=64 time=10.0 ms"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/ping"
    
    # Mock systemctl
    cat > "$MOCK_BIN_DIR/systemctl" <<'EOF'
#!/bin/bash
case "$1" in
    "--failed")
        echo "0 loaded units listed."
        ;;
    "status")
        echo "● $2.service"
        echo "   Active: active (running)"
        ;;
    *)
        echo "mock systemctl: $*"
        ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/systemctl"
}

# Create a custom mock command
create_mock_command() {
    local cmd_name="$1"
    local exit_code="${2:-0}"
    local output="${3:-}"
    local behavior="${4:-simple}"
    
    local cmd_path="$MOCK_BIN_DIR/$cmd_name"
    
    case "$behavior" in
        "simple")
            cat > "$cmd_path" <<EOF
#!/bin/bash
echo "$output"
exit $exit_code
EOF
            ;;
        "args")
            cat > "$cmd_path" <<EOF
#!/bin/bash
echo "Command: $cmd_name, Args: \$*"
echo "$output"
exit $exit_code
EOF
            ;;
        "conditional")
            cat > "$cmd_path" <<EOF
#!/bin/bash
if [[ "\$1" == "--version" ]]; then
    echo "$cmd_name version 1.0.0"
else
    echo "$output"
fi
exit $exit_code
EOF
            ;;
        *)
            # Custom behavior - output is treated as script content
            cat > "$cmd_path" <<EOF
#!/bin/bash
$output
exit $exit_code
EOF
            ;;
    esac
    
    chmod +x "$cmd_path"
}

# Source project libraries with error handling
source_project_libraries() {
    local lib_dir="$PROJECT_ROOT/lib"
    
    # Source libraries in dependency order
    local libraries=(
        "$lib_dir/core.sh"
        "$lib_dir/system.sh" 
        "$lib_dir/maintenance.sh"
        "$lib_dir/extensions.sh"
    )
    
    for lib in "${libraries[@]}"; do
        if [[ -f "$lib" ]]; then
            # shellcheck source=/dev/null
            source "$lib" 2>/dev/null || {
                echo "Warning: Failed to source $lib" >&2
            }
        fi
    done
}

# Load functions from main script for testing
source_script_functions() {
    local script_path="$1"
    
    if [[ ! -f "$script_path" ]]; then
        echo "Error: Script not found: $script_path" >&2
        return 1
    fi
    
    # Extract and source only the function definitions
    # This is a simple approach - in practice you might want more sophisticated parsing
    
    # First source the libraries that the script depends on
    source_project_libraries
    
    # Set up variables that the script expects
    export SCRIPT_DIR="$(dirname "$script_path")"
    export GREEN='\033[0;32m'
    export BLUE='\033[1;34m'
    export CYAN='\033[1;36m'
    export RED='\033[0;31m'
    export NC='\033[0m'
    export SUMMARY_LOG=()
    export CURRENT_STEP=0
    export TOTAL_STEPS=15
    export AUTO_MODE=true
    export TEST_MODE=true
    export PKG_MGR="pacman"
    export USER_CMD=()
    export DISABLED_FEATURES=()
}

# Verify that a function exists and is callable
verify_function_exists() {
    local func_name="$1"
    
    if ! declare -F "$func_name" >/dev/null 2>&1; then
        echo "Function $func_name is not defined" >&2
        return 1
    fi
    
    return 0
}

# Helper to check if command produces expected output
assert_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: '$expected'"
        echo "Actual output: '$output'"
        return 1
    fi
}

# Helper to check if command produces expected pattern
assert_output_matches() {
    local pattern="$1"
    if [[ ! "$output" =~ $pattern ]]; then
        echo "Expected output to match pattern: '$pattern'"
        echo "Actual output: '$output'"
        return 1
    fi
}

# Helper to check exit status
assert_status() {
    local expected_status="$1"
    if [[ "$status" -ne "$expected_status" ]]; then
        echo "Expected exit status: $expected_status"
        echo "Actual exit status: $status"
        return 1
    fi
}

# Setup function for BATS tests
setup() {
    setup_test_environment
}

# Teardown function for BATS tests  
teardown() {
    cleanup_test_environment
}

# Suite-level setup (called once before all tests in a file)
setup_suite() {
    # Global test setup can go here
    :
}

# Suite-level teardown (called once after all tests in a file)
teardown_suite() {
    # Global test cleanup can go here
    :
}

# Export functions for use in tests
export -f setup_test_environment cleanup_test_environment create_essential_mocks
export -f create_mock_command source_project_libraries source_script_functions
export -f verify_function_exists assert_output_contains assert_output_matches assert_status
