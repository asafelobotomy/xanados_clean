#!/usr/bin/env bash
# Comprehensive test runner for xanadOS Clean
# Consolidates and optimizes all testing functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color definitions for output
readonly GREEN='\033[0;32m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test configuration
VERBOSE=${VERBOSE:-false}
PARALLEL=${PARALLEL:-false}
COVERAGE=${COVERAGE:-false}
QUICK_MODE=${QUICK_MODE:-false}

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    printf "%b%s%b\n" "$color" "$message" "$NC"
}

# Display help information
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_PATTERN]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -p, --parallel      Run tests in parallel (faster)
    -c, --coverage      Enable coverage reporting
    -q, --quick         Run only fast/critical tests
    -l, --list          List available tests
    --setup             Setup test dependencies
    --clean             Clean test artifacts

TEST_PATTERN:
    all                 Run all tests (default)
    core                Run core functionality tests
    libraries           Run library tests  
    integration         Run integration tests
    performance         Run performance tests
    [filename]          Run specific test file

EXAMPLES:
    $0                  Run all tests
    $0 --quick          Run quick test suite
    $0 core             Run core tests only
    $0 --parallel all   Run all tests in parallel
    $0 test_core.bats   Run specific test file

EOF
}

# Check and install test dependencies
setup_test_dependencies() {
    print_color "$BLUE" "Setting up test dependencies..."
    
    local missing_deps=()
    
    # Check for BATS
    if ! command -v bats >/dev/null 2>&1; then
        missing_deps+=("bats")
    fi
    
    # Check for shellcheck
    if ! command -v shellcheck >/dev/null 2>&1; then
        missing_deps+=("shellcheck")
    fi
    
    # Check for bc for performance calculations
    if ! command -v bc >/dev/null 2>&1; then
        missing_deps+=("bc")
    fi
    
    if (( ${#missing_deps[@]} > 0 )); then
        print_color "$YELLOW" "Missing dependencies: ${missing_deps[*]}"
        
        if command -v pacman >/dev/null 2>&1; then
            print_color "$CYAN" "Installing with pacman..."
            sudo pacman -S --needed --noconfirm "${missing_deps[@]}"
        else
            print_color "$RED" "Please install manually: ${missing_deps[*]}"
            return 1
        fi
    fi
    
    print_color "$GREEN" "✓ Test dependencies are ready"
}

# List available tests
list_tests() {
    print_color "$BLUE" "Available test suites:"
    
    echo "Core tests:"
    find "$SCRIPT_DIR" -name "*core*.bats" -o -name "*main*.bats" | sed 's|.*/||' | sed 's|\.bats||' | sort | sed 's/^/  - /'
    
    echo "Library tests:"
    find "$SCRIPT_DIR" -name "*lib*.bats" -o -name "*function*.bats" | sed 's|.*/||' | sed 's|\.bats||' | sort | sed 's/^/  - /'
    
    echo "Integration tests:"
    find "$SCRIPT_DIR" -name "*integration*.bats" -o -name "*end*.bats" | sed 's|.*/||' | sed 's|\.bats||' | sort | sed 's/^/  - /'
    
    echo "All test files:"
    find "$SCRIPT_DIR" -name "*.bats" | sed 's|.*/||' | sort | sed 's/^/  - /'
}

# Clean test artifacts
clean_test_artifacts() {
    print_color "$BLUE" "Cleaning test artifacts..."
    
    # Remove temporary test directories
    find /tmp -name "*xanados_test*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Remove coverage reports
    rm -rf "$SCRIPT_DIR/coverage" 2>/dev/null || true
    
    # Remove test logs
    rm -f "$SCRIPT_DIR"/*.log 2>/dev/null || true
    
    print_color "$GREEN" "✓ Test artifacts cleaned"
}

# Run shellcheck on all shell scripts
run_shellcheck() {
    print_color "$BLUE" "Running shellcheck on project files..."
    
    local shellcheck_failed=false
    local files_to_check=()
    
    # Find shell scripts in project
    mapfile -t files_to_check < <(find "$PROJECT_ROOT" -name "*.sh" -o -name "*.bash" | grep -v tests/setup_suite.bash || true)
    
    if (( ${#files_to_check[@]} == 0 )); then
        print_color "$YELLOW" "No shell scripts found to check"
        return 0
    fi
    
    for file in "${files_to_check[@]}"; do
        if ! shellcheck "$file"; then
            shellcheck_failed=true
        fi
    done
    
    if [[ "$shellcheck_failed" == "true" ]]; then
        print_color "$RED" "✗ Shellcheck found issues"
        return 1
    else
        print_color "$GREEN" "✓ Shellcheck passed"
        return 0
    fi
}

# Run specific test category
run_test_category() {
    local category="$1"
    local test_files=()
    
    case "$category" in
        "core")
            mapfile -t test_files < <(find "$SCRIPT_DIR" -name "*core*.bats" -o -name "*main*.bats" -o -name "test_xanados_clean.bats")
            ;;
        "libraries"|"lib")
            mapfile -t test_files < <(find "$SCRIPT_DIR" -name "*lib*.bats" -o -name "*function*.bats")
            ;;
        "integration")
            mapfile -t test_files < <(find "$SCRIPT_DIR" -name "*integration*.bats" -o -name "*end*.bats")
            ;;
        "performance"|"perf")
            mapfile -t test_files < <(find "$SCRIPT_DIR" -name "*perf*.bats" -o -name "*benchmark*.bats")
            ;;
        "all")
            mapfile -t test_files < <(find "$SCRIPT_DIR" -name "*.bats")
            ;;
        *)
            if [[ -f "$SCRIPT_DIR/$category" ]]; then
                test_files=("$SCRIPT_DIR/$category")
            elif [[ -f "$SCRIPT_DIR/${category}.bats" ]]; then
                test_files=("$SCRIPT_DIR/${category}.bats")
            else
                print_color "$RED" "Unknown test category or file: $category"
                return 1
            fi
            ;;
    esac
    
    if (( ${#test_files[@]} == 0 )); then
        print_color "$YELLOW" "No test files found for category: $category"
        return 0
    fi
    
    print_color "$BLUE" "Running tests for category: $category"
    printf "Test files: %s\n" "${test_files[*]}"
    
    local bats_args=()
    
    if [[ "$VERBOSE" == "true" ]]; then
        bats_args+=("--verbose-run")
    fi
    
    if [[ "$PARALLEL" == "true" ]] && (( ${#test_files[@]} > 1 )); then
        bats_args+=("--jobs" "$(nproc)")
    fi
    
    # Add timing information
    bats_args+=("--timing")
    
    # Run the tests
    local start_time end_time duration
    start_time=$(date +%s)
    
    if bats "${bats_args[@]}" "${test_files[@]}"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        print_color "$GREEN" "✓ Tests passed for $category (${duration}s)"
        return 0
    else
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        print_color "$RED" "✗ Tests failed for $category (${duration}s)"
        return 1
    fi
}

# Run quick test suite (fast tests only)
run_quick_tests() {
    print_color "$BLUE" "Running quick test suite..."
    
    # Focus on critical functionality tests
    local quick_tests=(
        "test_core_functions"
        "test_argument_parsing"
        "test_configuration"
    )
    
    local quick_failed=false
    
    for test_pattern in "${quick_tests[@]}"; do
        local test_files=()
        mapfile -t test_files < <(find "$SCRIPT_DIR" -name "*${test_pattern}*.bats" 2>/dev/null || true)
        
        if (( ${#test_files[@]} > 0 )); then
            if ! bats --timing "${test_files[@]}"; then
                quick_failed=true
            fi
        fi
    done
    
    if [[ "$quick_failed" == "true" ]]; then
        print_color "$RED" "✗ Quick tests failed"
        return 1
    else
        print_color "$GREEN" "✓ Quick tests passed"
        return 0
    fi
}

# Generate test coverage report
generate_coverage_report() {
    print_color "$BLUE" "Generating coverage report..."
    
    # This is a simplified coverage implementation
    # In a real scenario, you'd use tools like kcov or bash-coverage
    
    local coverage_dir="$SCRIPT_DIR/coverage"
    mkdir -p "$coverage_dir"
    
    # Count tested vs total functions
    local total_functions tested_functions
    total_functions=$(grep -r "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$PROJECT_ROOT"/lib/*.sh "$PROJECT_ROOT"/*.sh 2>/dev/null | wc -l || echo "0")
    tested_functions=$(grep -r "@test" "$SCRIPT_DIR"/*.bats 2>/dev/null | wc -l || echo "0")
    
    local coverage_percent=0
    if (( total_functions > 0 )); then
        coverage_percent=$((tested_functions * 100 / total_functions))
    fi
    
    cat > "$coverage_dir/report.txt" <<EOF
Test Coverage Report
Generated: $(date)

Total Functions: $total_functions
Tested Functions: $tested_functions
Coverage: ${coverage_percent}%

Test Files:
$(find "$SCRIPT_DIR" -name "*.bats" | wc -l) BATS test files found

EOF
    
    print_color "$CYAN" "Coverage report saved to: $coverage_dir/report.txt"
    print_color "$CYAN" "Estimated coverage: ${coverage_percent}%"
    
    if (( coverage_percent < 50 )); then
        print_color "$YELLOW" "⚠ Low test coverage detected"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -p|--parallel)
                PARALLEL=true
                shift
                ;;
            -c|--coverage)
                COVERAGE=true
                shift
                ;;
            -q|--quick)
                QUICK_MODE=true
                shift
                ;;
            -l|--list)
                list_tests
                exit 0
                ;;
            --setup)
                setup_test_dependencies
                exit $?
                ;;
            --clean)
                clean_test_artifacts
                exit $?
                ;;
            -*)
                print_color "$RED" "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                # This is the test pattern
                TEST_PATTERN="$1"
                shift
                ;;
        esac
    done
}

# Main execution function
main() {
    local TEST_PATTERN="${TEST_PATTERN:-all}"
    local overall_start_time overall_end_time total_duration
    local tests_failed=false
    
    overall_start_time=$(date +%s)
    
    print_color "$BLUE" "xanadOS Clean Test Runner"
    print_color "$CYAN" "Project: $PROJECT_ROOT"
    print_color "$CYAN" "Test directory: $SCRIPT_DIR"
    echo
    
    # Check for BATS installation
    if ! command -v bats >/dev/null 2>&1; then
        print_color "$RED" "BATS is not installed. Run with --setup to install dependencies."
        exit 1
    fi
    
    # Run shellcheck first (unless in quick mode)
    if [[ "$QUICK_MODE" != "true" ]]; then
        if ! run_shellcheck; then
            tests_failed=true
        fi
    fi
    
    # Run the appropriate test suite
    if [[ "$QUICK_MODE" == "true" ]]; then
        if ! run_quick_tests; then
            tests_failed=true
        fi
    else
        if ! run_test_category "$TEST_PATTERN"; then
            tests_failed=true
        fi
    fi
    
    # Generate coverage report if requested
    if [[ "$COVERAGE" == "true" ]]; then
        generate_coverage_report
    fi
    
    # Final summary
    overall_end_time=$(date +%s)
    total_duration=$((overall_end_time - overall_start_time))
    
    echo
    print_color "$BLUE" "Test Summary"
    printf "Total execution time: %d seconds\n" "$total_duration"
    
    if [[ "$tests_failed" == "true" ]]; then
        print_color "$RED" "✗ Some tests failed"
        exit 1
    else
        print_color "$GREEN" "✓ All tests passed successfully"
        exit 0
    fi
}

# Parse arguments and run main function
parse_args "$@"
main
