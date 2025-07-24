#!/usr/bin/env bash
# Test runner for xanadOS Clean
# Usage: ./run_tests.sh [test_file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if BATS is installed
if ! command -v bats >/dev/null 2>&1; then
    echo "BATS (Bash Automated Testing System) is not installed."
    echo "Please install it first:"
    echo "  - On Arch: sudo pacman -S bats"
    echo "  - From source: git clone https://github.com/bats-core/bats-core.git && cd bats-core && ./install.sh /usr/local"
    exit 1
fi

# Default to running all tests
if [[ $# -eq 0 ]]; then
    echo "Running all tests..."
    bats "$SCRIPT_DIR"/*.bats
else
    # Handle legacy test file reference
    if [[ "$1" == "test_xanados_clean.bats" ]]; then
        echo "Note: test_xanados_clean.bats has been replaced with test_core.bats"
        echo "Running test_core.bats instead..."
        bats "$SCRIPT_DIR/test_core.bats"
    else
        echo "Running specific test: $1"
        bats "$SCRIPT_DIR/$1"
    fi
fi
