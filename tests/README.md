# xanadOS Clean Test Suite

Comprehensive test suite for the xanadOS Clean Arch Linux maintenance tool.

## Overview

This test suite has been optimized and consolidated to provide:
- **Fast execution** with parallel test capabilities
- **Comprehensive coverage** of all major functionality
- **Easy maintenance** with consolidated test helpers
- **Flexible execution** with multiple test categories

## Test Structure

### Files

- `test_runner.sh` - Main test runner with advanced options
- `test_helpers.bash` - Consolidated test configuration and helper functions
- `test_core.bats` - Core functionality tests
- Legacy files (maintained for compatibility):
  - `run_tests.sh` - Simple test runner
  - `setup_suite.bash` - Original test setup

### Test Categories

- **Core Tests** (`test_core.bats`): Essential functionality, logging, progress tracking
- **Library Tests**: Individual library function testing
- **Integration Tests**: End-to-end functionality testing
- **Performance Tests**: Resource usage and timing validation

## Quick Start

### Install Dependencies

```bash
# Install test dependencies (Arch Linux)
sudo pacman -S bats shellcheck bc

# Or use the automated setup
./test_runner.sh --setup
```

### Run Tests

```bash
# Run all tests
./test_runner.sh

# Run specific test category
./test_runner.sh core
./test_runner.sh libraries
./test_runner.sh integration

# Run with options
./test_runner.sh --parallel --verbose all
./test_runner.sh --quick                    # Fast critical tests only
./test_runner.sh --coverage                 # Generate coverage report

# Run specific test file
./test_runner.sh test_core.bats
```

## Test Runner Options

### Basic Usage
```bash
./test_runner.sh [OPTIONS] [TEST_PATTERN]
```

### Options
- `-h, --help` - Show help message
- `-v, --verbose` - Enable verbose output
- `-p, --parallel` - Run tests in parallel (faster)
- `-c, --coverage` - Generate coverage report
- `-q, --quick` - Run only fast/critical tests
- `-l, --list` - List available tests
- `--setup` - Setup test dependencies
- `--clean` - Clean test artifacts

### Test Patterns
- `all` - Run all tests (default)
- `core` - Core functionality tests
- `libraries` - Library function tests
- `integration` - Integration tests
- `performance` - Performance tests
- `[filename]` - Run specific test file

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bats
# Test file description

load 'test_helpers'

@test "test description" {
    # Setup
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    create_mock_command "command" 0 "output"
    
    # Execute
    run function_to_test "arguments"
    
    # Assert
    assert_status 0
    assert_output_contains "expected text"
}
```

### Helper Functions

```bash
# Environment setup
setup_test_environment          # Automatic in load 'test_helpers'
cleanup_test_environment        # Automatic cleanup

# Mock commands
create_mock_command "cmd" exit_code "output" [behavior]
create_essential_mocks          # Creates common mocks (sudo, pacman, etc.)

# Source project code
source_script_functions "path/to/script.sh"
source_project_libraries        # Source all lib/*.sh files

# Assertions
assert_status expected_code      # Check exit status
assert_output_contains "text"    # Check output contains text
assert_output_matches "pattern"  # Check output matches regex pattern
verify_function_exists "func"    # Verify function is defined
```

### Mock Command Behaviors

```bash
# Simple mock (returns output and exit code)
create_mock_command "ping" 0 "PING OK"

# Args behavior (shows command arguments)
create_mock_command "pacman" 0 "mock output" "args"

# Conditional behavior (responds to --version)
create_mock_command "tool" 0 "tool output" "conditional"

# Custom behavior (custom script content)
create_mock_command "complex" 0 "
case \$1 in
    install) echo 'Installing...' ;;
    remove) echo 'Removing...' ;;
esac" "custom"
```

## Test Environment

### Isolation
- Each test runs in isolated temporary directory
- Mock commands override system commands
- No actual system changes are made
- Automatic cleanup after tests

### Variables
- `TEST_MODE=true` - Indicates test environment
- `AUTO_MODE=true` - Runs in non-interactive mode
- `SUDO=""` - Disabled sudo for tests
- `PROJECT_ROOT` - Path to project root
- `TEST_TEMP_DIR` - Temporary test directory
- `MOCK_BIN_DIR` - Mock commands directory

## Coverage Reporting

```bash
# Generate coverage report
./test_runner.sh --coverage

# View report
cat tests/coverage/report.txt
```

Coverage report includes:
- Total vs tested functions
- Estimated coverage percentage
- Test file statistics
- Recommendations for improvement

## Performance Testing

The test suite includes basic performance validation:
- Memory usage monitoring
- Execution time tracking
- Resource consumption checks

```bash
# Run performance tests
./test_runner.sh performance

# Quick performance check
./test_runner.sh --quick
```

## Maintenance

### Adding New Tests

1. Create test file: `test_[feature].bats`
2. Add to appropriate category in `test_runner.sh`
3. Use `test_helpers.bash` for setup and assertions
4. Follow existing test patterns

### Updating Mock Commands

1. Edit `create_essential_mocks()` in `test_helpers.bash`
2. Add new mock behaviors as needed
3. Test mock commands independently

### Troubleshooting

```bash
# Clean test artifacts
./test_runner.sh --clean

# Verbose output for debugging
./test_runner.sh --verbose test_name

# List available tests
./test_runner.sh --list

# Check dependencies
./test_runner.sh --setup
```

## Integration with CI/CD

The test runner is designed for CI/CD integration:

```bash
# CI-friendly execution
./test_runner.sh --parallel --coverage all

# Exit codes
# 0 = All tests passed
# 1 = Some tests failed
```

## Legacy Compatibility

Original test files are maintained for backward compatibility:
- `run_tests.sh` - Simple BATS runner
- `setup_suite.bash` - Original test setup
- `test_xanados_clean.bats` - Original test file

New tests should use the optimized structure with `test_runner.sh` and `test_helpers.bash`.

## Examples

### Run Quick Validation
```bash
./test_runner.sh --quick
```

### Full Test Suite with Coverage
```bash
./test_runner.sh --parallel --coverage --verbose all
```

### Test Specific Functionality
```bash
./test_runner.sh core
./test_runner.sh test_core.bats
```

### Development Workflow
```bash
# During development
./test_runner.sh --quick

# Before commit
./test_runner.sh --parallel all

# For release
./test_runner.sh --coverage --parallel all
```
