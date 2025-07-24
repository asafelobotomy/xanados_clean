#!/usr/bin/env bash
# Test script to verify pkg_mgr_run functionality

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the core library
source "$SCRIPT_DIR/lib/core.sh"

echo "Testing package manager setup..."

# Test setup_package_manager
setup_package_manager

echo "PKG_MGR: $PKG_MGR"
echo "SUDO: '$SUDO'"

# Test pkg_mgr_run with a safe command
echo "Testing pkg_mgr_run with --version:"
pkg_mgr_run --version

echo "Package manager setup test completed successfully!"
