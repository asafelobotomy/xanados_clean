# Test Suite Documentation

## Overview

The xanadOS Clean test suite uses BATS (Bash Automated Testing System) to provide comprehensive unit testing for all shell scripts in the project.

## Prerequisites

### Install BATS

**Arch Linux:**
```bash
sudo pacman -S bats
```

**From Source:**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Install Test Dependencies

```bash
# Required for news parsing tests
sudo pacman -S xmlstarlet curl  # Arch
```

## Running Tests

### Run All Tests

```bash
cd tests
./run_tests.sh
```

### Run Specific Test Files

```bash
./run_tests.sh test_xanados_clean.bats
./run_tests.sh test_build_appimage.bats
```

### Run Individual Tests

```bash
bats -f "require_pacman should pass" test_xanados_clean.bats
```

## Test Structure

### Test Files

- `test_xanados_clean.bats` - Tests for Arch Linux maintenance script
- `test_build_appimage.bats` - Tests for AppImage build script
- `setup_suite.bash` - Common test setup and utilities

### Mock Framework

The test suite includes a comprehensive mocking system:

- **Mock Commands**: Create fake system commands for testing
- **Temporary Environment**: Isolated test environment
- **Safe Execution**: No actual system changes during tests

### Test Categories

1. **Syntax Tests**: Verify script syntax and structure
2. **Function Tests**: Unit tests for individual functions
3. **Integration Tests**: Test component interactions
4. **Configuration Tests**: Validate configuration loading
5. **Error Handling Tests**: Test failure scenarios

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bats

load 'setup_suite'

setup() {
    source_script_functions "$PROJECT_ROOT/script.sh"
    create_mock_command "command_name" 0 "output"
}

@test "function should work correctly" {
    run function_name
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}

teardown() {
    # Cleanup if needed
}
```

### Test Helpers

#### `create_mock_command(name, exit_code, output)`
Creates a mock command for testing:

```bash
create_mock_command "pacman" 0 "pacman 6.0.1"
```

#### `source_script_functions(script_path)`
Loads script functions for testing:

```bash
source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
```

### Test Assertions

Common BATS assertions:

```bash
# Exit code assertions
[ "$status" -eq 0 ]           # Success
[ "$status" -eq 1 ]           # Failure

# Output assertions
[[ "$output" == *"text"* ]]   # Contains text
[[ "$output" =~ regex ]]      # Matches regex
[ "$output" = "exact" ]       # Exact match

# File assertions
[ -f "$file" ]                # File exists
[ -x "$file" ]                # File is executable
[ -s "$file" ]                # File is not empty
```

## Test Data

### Mock System State

Tests can simulate various system states:

```bash
setup() {
    # Simulate Arch Linux
    create_mock_command "pacman" 0 "pacman 6.0.1"
    
    # Simulate network failure
    create_mock_command "ping" 1 ""
    
    # Simulate missing dependencies
    rm -f "$MOCK_BIN_DIR/paru"
}
```

### Configuration Testing

Test different configuration scenarios:

```bash
@test "should respect configuration settings" {
    ENABLE_FLATPAK=false
    run should_run_step "flatpak_update"
    [ "$status" -eq 1 ]
}
```

## Continuous Integration

Tests run automatically in CI/CD:

- **On Push**: All tests run on code changes
- **On PR**: Full test suite including integration tests
- **Scheduled**: Weekly security and regression testing

### CI Test Matrix

- **Lint Tests**: ShellCheck, markdownlint, yamllint
- **Unit Tests**: Individual function testing
- **Integration Tests**: Cross-component testing
- **Security Tests**: Vulnerability scanning

## Debugging Tests

### Verbose Output

```bash
# Run with debug output
bats --verbose-run test_file.bats

# Show test timing
bats --timing test_file.bats
```

### Test Isolation

Each test runs in isolation:

- Separate temporary directories
- Independent environment variables  
- Clean state between tests

### Manual Debugging

```bash
# Source test environment
source tests/setup_suite.bash
setup_suite

# Run individual functions
source_script_functions "xanados_clean.sh"
create_mock_command "pacman" 0 "test output"

# Test functions interactively
require_pacman
echo "Exit code: $?"
```

## Best Practices

### Test Organization

1. **Group Related Tests**: Use descriptive test file names
2. **Clear Test Names**: Describe expected behavior
3. **Setup/Teardown**: Use proper test lifecycle management
4. **Mock External Dependencies**: Avoid real system calls

### Test Coverage

Aim for comprehensive coverage:

- ✅ **Core Functions**: All main functions tested
- ✅ **Error Conditions**: Failure scenarios covered
- ✅ **Configuration**: All config options tested
- ✅ **Edge Cases**: Boundary conditions tested

### Test Documentation

- Comment complex test logic
- Use descriptive variable names
- Document mock behavior
- Explain test purpose

## Troubleshooting

### Common Issues

**BATS not found:**
```bash
# Verify installation
which bats
bats --version
```

**Permission errors:**
```bash
# Make test runner executable
chmod +x tests/run_tests.sh
```

**Mock command failures:**
```bash
# Check mock directory permissions
ls -la "$MOCK_BIN_DIR"
echo "$PATH"
```

**Test isolation problems:**
```bash
# Verify cleanup in teardown
teardown() {
    unset VARIABLE_NAME
    rm -rf "$TEST_TEMP_DIR"
}
```

### Getting Help

- Check BATS documentation: https://bats-core.readthedocs.io/
- Review existing tests for examples
- Use verbose mode for debugging
- Check CI logs for integration issues
