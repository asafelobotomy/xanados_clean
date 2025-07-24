#!/usr/bin/env bash
# Simple test script to verify the system update fix

set -euo pipefail

echo "Testing xanados_clean simple mode initialization..."

# Set environment variables for testing
export SIMPLE_MODE=true
export TEST_MODE=true
export AUTO_MODE=true

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Mock functions to avoid actual system operations
mock_system_update() {
    echo "[TEST] system_update called successfully"
    echo "[TEST] PKG_MGR: ${PKG_MGR:-not set}"
    echo "[TEST] SUDO: '${SUDO:-not set}'"
    return 0
}

mock_remove_orphans() {
    echo "[TEST] remove_orphans called"
    return 0
}

mock_cache_cleanup() {
    echo "[TEST] cache_cleanup called"
    return 0
}

mock_check_failed_services() {
    echo "[TEST] check_failed_services called"
    return 0
}

# Export mock functions
export -f mock_system_update mock_remove_orphans mock_cache_cleanup mock_check_failed_services

# Test the initialization by checking if setup_package_manager would be called
cd "$SCRIPT_DIR"

# Source core functions first
source lib/core.sh

# Mock has_sudo to return true
has_sudo() { return 0; }
export -f has_sudo

# Test setup_package_manager directly
echo "Testing setup_package_manager..."
if setup_package_manager 2>/dev/null; then
    echo "[PASS] setup_package_manager executed successfully"
    echo "PKG_MGR: ${PKG_MGR}"
    echo "SUDO: '${SUDO}'"
else
    echo "[FAIL] setup_package_manager failed"
    exit 1
fi

echo "Test completed successfully!"
