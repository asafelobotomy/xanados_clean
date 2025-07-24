# xanadOS Clean - Developer Guide

## Architecture Overview

xanadOS Clean is a modular Bash-based system maintenance tool designed for Arch Linux. It features a plugin architecture with separate libraries for configuration, recovery, performance monitoring, and Arch-specific optimizations.

### Project Structure

```
xanados_clean/
├── xanados_clean.sh           # Main executable script
├── lib/                       # Core libraries
│   ├── config.sh             # Configuration management
│   ├── recovery.sh           # Error recovery & checkpoints
│   ├── performance.sh        # Performance monitoring
│   ├── arch_optimizations.sh # Arch-specific features
│   └── enhancements.sh       # Integration layer
├── config/
│   └── default.conf          # Default configuration
├── tests/                    # Test suite
│   ├── setup_suite.bash     # Test framework
│   ├── test_*.bats          # BATS test files
│   └── run_tests.sh         # Test runner
└── docs/                     # Documentation
```

## API Reference

### Core Functions

#### Logging Functions

**`log(message)`**
- **Purpose**: Display informational messages with formatting
- **Parameters**: message (string) - Text to display
- **Output**: `[+] message` in green

**`error(message)`**
- **Purpose**: Display error messages with formatting  
- **Parameters**: message (string) - Error text to display
- **Output**: `[!] message` in red to stderr

**`summary(message)`**
- **Purpose**: Add message to summary log and display
- **Parameters**: message (string) - Summary text
- **Side Effects**: Appends to SUMMARY_LOG array

#### Progress Management

**`show_progress(description)`**
- **Purpose**: Display progress bar with step counter
- **Parameters**: description (string) - Current operation name
- **Behavior**: Increments CURRENT_STEP, shows visual progress bar

**`print_banner(title)`**
- **Purpose**: Display formatted section header with ASCII art
- **Parameters**: title (string) - Section title
- **Output**: Colored banner with xanadOS branding

#### Step Execution

**`run_step(function, description)`**
- **Purpose**: Execute a maintenance step with progress tracking
- **Parameters**: 
  - function (string): Name of function to call
  - description (string): Human-readable description
- **Returns**: Return code of called function
- **Features**: Progress display, user prompts, error handling

### System Detection Functions

**`require_pacman()`**
- **Purpose**: Verify pacman package manager is available
- **Returns**: 0 if found, exits with error if not
- **Usage**: Called early to ensure Arch Linux compatibility

**`choose_pkg_manager()`**
- **Purpose**: Select between pacman and AUR helpers (paru/yay)
- **Side Effects**: Sets PKG_MGR global variable
- **Behavior**: Auto-detects in AUTO_MODE, prompts user otherwise

**`check_network()`**
- **Purpose**: Verify internet connectivity
- **Returns**: 0 if connected, 1 if offline
- **Method**: Pings archlinux.org with 1 packet, 2 second timeout

### Maintenance Operations

**`system_update()`**
- **Purpose**: Update all system packages
- **Method**: Uses selected package manager (PKG_MGR)
- **Flags**: --noconfirm for automatic execution

**`remove_orphans()`**
- **Purpose**: Remove packages no longer needed by any installed package
- **Method**: `pacman -Qtdq` to find orphans, `pacman -Rns` to remove
- **Safety**: Only removes if orphans found

**`cache_cleanup()`**
- **Purpose**: Clean package cache and user cache directories
- **Tools**: paccache for package cache, manual cleanup for ~/.cache
- **Behavior**: Prompts for user cache cleanup unless AUTO_MODE

**`security_scan()`**
- **Purpose**: Scan for vulnerabilities and rootkits
- **Tools**: arch-audit for CVE scanning, rkhunter for rootkit detection
- **Features**: Automatic tool updates, result summaries

### Configuration System

#### Configuration Loading

**`load_config()`**
- **Purpose**: Load configuration from file hierarchy
- **Search Order**:
  1. `${XDG_CONFIG_HOME}/xanados_clean/config.conf`
  2. `${HOME}/.xanados_clean.conf`
  3. `/etc/xanados_clean/config.conf`
  4. `config/default.conf`
- **Error Handling**: Graceful fallback to defaults

**`validate_config()`**
- **Purpose**: Validate all configuration values
- **Checks**: Type validation, range checking, path verification
- **Behavior**: Sets defaults for missing values

#### Configuration Variables

**General Settings**
- `LOG_FILE`: Path to log file (default: ~/Documents/system_maint.log)
- `AUTO_MODE`: Boolean for non-interactive operation
- `ASK_EACH_STEP`: Boolean to prompt before each step
- `MAX_LOG_SIZE`: Maximum log file size in MB
- `LOG_ROTATION_COUNT`: Number of log files to keep

**Feature Toggles**
- `ENABLE_FLATPAK`: Enable Flatpak updates (auto/true/false)
- `ENABLE_SECURITY_SCAN`: Enable vulnerability scanning
- `ENABLE_ORPHAN_REMOVAL`: Enable orphan package removal
- `ENABLE_CACHE_CLEANUP`: Enable cache cleanup operations
- `ENABLE_BTRFS_MAINTENANCE`: Enable Btrfs optimization
- `ENABLE_SSD_TRIM`: Enable SSD TRIM operations

**Backup Settings**
- `BACKUP_METHOD`: Backup tool to use (auto/timeshift/snapper/rsync/none)
- `BACKUP_SKIP_THRESHOLD_DAYS`: Skip backup if recent one exists
- `RSYNC_DIR`: Directory for rsync backups

### Recovery System

#### Checkpoint Management

**`create_checkpoint(step_name)`**
- **Purpose**: Create system checkpoint before critical operations
- **Storage**: Saves package list, mirrorlist, configuration state
- **Location**: `${LOG_DIR}/xanados_checkpoint.state`

**`resume_from_checkpoint()`**
- **Purpose**: Resume maintenance from last checkpoint
- **Returns**: 0 if checkpoint found and loaded, 1 otherwise
- **Behavior**: Restores system state and continues from failed step

**`cleanup_checkpoint()`**
- **Purpose**: Remove checkpoint files after successful completion
- **Cleanup**: Removes state file and associated backup files

#### Error Recovery

**`run_step_with_recovery(function, description, allow_failure)`**
- **Purpose**: Execute step with automatic recovery capabilities
- **Features**: Checkpoint creation, failure tracking, recovery options
- **Recovery Options**: Retry, skip, automatic recovery, manual guidance

**`offer_recovery(failed_step)`**
- **Purpose**: Present recovery options to user after step failure
- **Options**:
  1. Retry failed operation
  2. Skip and continue
  3. Attempt automatic recovery
  4. Show recovery instructions
  5. Abort maintenance

**`attempt_automatic_recovery(step_name)`**
- **Purpose**: Try automated recovery for known failure scenarios
- **Methods**: Function-specific recovery procedures
- **Examples**: Restore mirrorlist, downgrade packages, cleanup incomplete operations

### Performance Monitoring

#### Metrics Collection

**`init_performance_monitoring()`**
- **Purpose**: Initialize performance tracking system
- **Metrics**: Start time, memory usage, disk I/O, system load
- **Storage**: Global SYSTEM_METRICS and STEP_METRICS arrays

**`record_step_performance(step_name, start_time, end_time, peak_memory)`**
- **Purpose**: Record performance data for completed step
- **Calculations**: Duration, memory delta, resource usage
- **Warnings**: Automatic alerts for slow operations or high memory usage

**`run_step_monitored(function, description, allow_failure)`**
- **Purpose**: Execute step with comprehensive performance monitoring
- **Monitoring**: Background memory tracking, I/O monitoring, timing
- **Integration**: Combines performance tracking with recovery system

#### Performance Reports

**`generate_performance_report()`**
- **Purpose**: Create detailed performance analysis
- **Content**: 
  - Total execution time and resource usage
  - Per-step performance breakdown
  - System optimization recommendations
  - Resource usage trends

**`check_system_resources()`**
- **Purpose**: Verify system has adequate resources before starting
- **Checks**: Available memory, disk space, system load
- **Behavior**: Warns user and optionally aborts on resource constraints

### Arch Linux Optimizations

#### Pacman Configuration

**`configure_pacman_optimizations()`**
- **Purpose**: Apply latest pacman performance enhancements
- **Features**:
  - Parallel downloads (5 concurrent)
  - Colored output for readability
  - Verbose package lists
  - Enhanced signature verification

#### News Integration

**`install_news_hooks()`**
- **Purpose**: Set up Arch Linux breaking news monitoring
- **Tools**: informant, newscheck, or custom RSS parser
- **Features**: Pre-update news checking, 24-hour cache, breaking change alerts

**`display_arch_news()`**
- **Purpose**: Show recent Arch Linux news
- **Source**: Official Arch Linux RSS feed
- **Display**: Latest 5 news items with titles

#### Essential Tools

**`install_essential_tools()`**
- **Purpose**: Install and configure essential Arch maintenance tools
- **Tools**: pacman-contrib, pkgfile, arch-audit, rebuild-detector, reflector
- **Configuration**: Automatic database updates, hook setup

#### Security Enhancements

**`enhance_security()`**
- **Purpose**: Apply security-focused system optimizations
- **Features**:
  - CVE vulnerability scanning with arch-audit
  - Package integrity verification
  - Rebuild detection for library updates
  - Unowned file detection

#### System Performance

**`optimize_system_performance()`**
- **Purpose**: Apply performance optimizations based on hardware
- **Optimizations**:
  - SSD I/O scheduler tuning (mq-deadline)
  - Swappiness adjustment for different workloads
  - Memory management improvements
  - Filesystem optimization

### Testing Framework

#### BATS Integration

xanadOS Clean uses BATS (Bash Automated Testing System) for comprehensive unit testing.

**Test Structure**
```bash
#!/usr/bin/env bats
load 'setup_suite'

setup() {
    source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
    create_mock_command "pacman" 0 "output"
}

@test "function_name should behave correctly" {
    run function_name "parameter"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "expected" ]]
}
```

#### Mock Framework

**`create_mock_command(command, exit_code, output)`**
- **Purpose**: Create mock executable for testing
- **Parameters**: command name, exit code to return, output to produce
- **Location**: Creates executable in temporary mock directory

**`source_script_functions(script_path)`**
- **Purpose**: Load functions from script for unit testing
- **Method**: Sources script with main execution disabled
- **Usage**: Enables testing individual functions in isolation

#### Test Execution

**Running Tests**
```bash
# All tests
cd tests && ./run_tests.sh

# Specific test file
./run_tests.sh test_xanados_clean.bats

# Individual test
bats -f "test name" test_file.bats
```

**Test Categories**
- **Function Tests**: Unit tests for individual functions
- **Integration Tests**: Multi-step operation testing
- **Configuration Tests**: Config loading and validation
- **Recovery Tests**: Error handling and recovery procedures
- **Performance Tests**: Resource usage and timing validation

### Error Handling Standards

#### Error Trapping

```bash
set -euo pipefail
IFS=$'\n\t'

err_trap() {
  error "Command '$BASH_COMMAND' failed at line ${BASH_LINENO[0]}"
  exit 1
}
trap err_trap ERR
```

#### Function Return Codes

- **0**: Success
- **1**: General error
- **2**: Invalid parameters
- **3**: Missing dependencies
- **4**: Network error
- **5**: Permission error

#### Error Recovery Patterns

```bash
if ! critical_operation; then
    error "Critical operation failed"
    if [[ "${AUTO_MODE:-false}" == "true" ]]; then
        attempt_automatic_recovery "critical_operation"
    else
        offer_recovery "critical_operation"
    fi
fi
```

## Development Workflow

### Setting Up Development Environment

1. **Clone and Setup**
   ```bash
   git clone https://github.com/asafelobotomy/xanados_clean.git
   cd xanados_clean
   chmod +x xanados_clean.sh
   ```

2. **Install Development Dependencies**
   ```bash
   # Arch Linux
   sudo pacman -S bats shellcheck nodejs npm
   npm install
   ```

3. **Run Tests**
   ```bash
   npm test
   ```

### Code Quality Standards

#### Bash Best Practices

- Use `set -euo pipefail` for strict error handling
- Quote all variables: `"$variable"`
- Use arrays for multiple values: `array=("item1" "item2")`
- Validate function parameters
- Use meaningful function and variable names
- Include documentation comments

#### Linting

**Shell Script Linting**
```bash
shellcheck *.sh lib/*.sh tests/*.bash
```

**Markdown Linting**
```bash
npm run lint:md
```

**Combined Linting**
```bash
npm run lint
```

### Testing Guidelines

#### Writing Unit Tests

1. **Setup Test Environment**
   ```bash
   load 'setup_suite'
   
   setup() {
       source_script_functions "$PROJECT_ROOT/xanados_clean.sh"
       # Create necessary mocks
   }
   ```

2. **Test Function Behavior**
   ```bash
   @test "function should handle valid input" {
       run function_name "valid_input"
       [ "$status" -eq 0 ]
       [[ "$output" =~ "expected_output" ]]
   }
   ```

3. **Test Error Conditions**
   ```bash
   @test "function should fail with invalid input" {
       run function_name "invalid_input"
       [ "$status" -ne 0 ]
   }
   ```

#### Mock Strategy

- Mock all external commands (pacman, systemctl, etc.)
- Create realistic test data
- Test both success and failure scenarios
- Verify side effects (file creation, variable changes)

### Release Process

1. **Version Update**
   - Update version in `xanados_clean.sh`
   - Update `package.json` version
   - Update documentation references

2. **Testing**
   ```bash
   npm test
   npm run lint
   ```

3. **Documentation**
   - Update CHANGELOG.md
   - Verify all documentation is current
   - Update API documentation for new features

4. **Release Creation**
   - Create GitHub release
   - Generate release artifacts
   - Upload release files

### Contributing Guidelines

#### Code Contributions

1. **Fork and Branch**
   ```bash
   git fork asafelobotomy/xanados_clean
   git checkout -b feature/your-feature
   ```

2. **Development**
   - Follow coding standards
   - Add tests for new functionality
   - Update documentation
   - Ensure all tests pass

3. **Pull Request**
   - Provide clear description
   - Include test results
   - Reference any related issues

#### Bug Reports

Include the following information:
- System details (OS, version, hardware)
- xanadOS Clean version
- Complete error messages
- Log file excerpts
- Steps to reproduce
- Expected vs actual behavior

#### Feature Requests

- Describe the use case
- Explain the benefit
- Suggest implementation approach
- Consider compatibility impact

## Troubleshooting Development Issues

### Common Development Problems

**Test Failures**
```bash
# Run specific failing test with debug output
bats --verbose-run test_file.bats

# Check test environment
source tests/setup_suite.bash
setup_suite
```

**Linting Errors**
```bash
# Fix shell script issues
shellcheck --format=diff *.sh | patch -p1

# Fix markdown formatting
npm run lint:md -- --fix
```

**Mock Issues**
```bash
# Verify mock commands work
export PATH="$MOCK_BIN_DIR:$PATH"
which pacman  # Should show mock version
```

### Debugging Techniques

**Script Debugging**
```bash
# Enable debug mode
bash -x xanados_clean.sh

# Add debug output
set -x  # Enable command tracing
set +x  # Disable command tracing
```

**Function Isolation**
```bash
# Test individual functions
source xanados_clean.sh
log "test message"
```

**Performance Debugging**
```bash
# Monitor resource usage
time ./xanados_clean.sh --test-mode
htop &  # Monitor during execution
```

### Performance Optimization

#### Profile Script Execution

```bash
# Time each major operation
time ./xanados_clean.sh --auto

# Use performance monitoring
ENABLE_PERFORMANCE_MONITORING=true ./xanados_clean.sh
```

#### Memory Usage

- Monitor peak memory usage during operations
- Identify memory leaks in long-running operations
- Optimize array usage and variable cleanup

#### I/O Optimization

- Minimize disk operations
- Batch file operations
- Use efficient tools (grep vs awk vs sed)

## Security Considerations

### Input Validation

- Validate all user inputs
- Sanitize file paths
- Check command parameters
- Verify configuration values

### Privilege Management

- Run as regular user with sudo
- Minimize privileged operations
- Validate sudo access before use
- Log all privileged commands

### File Security

- Use secure temporary files
- Verify file permissions
- Check for symlink attacks
- Validate backup locations

### Network Security

- Verify SSL certificates
- Check mirror authenticity
- Validate package signatures
- Handle network timeouts gracefully

## Future Development

### Planned Features

- Enhanced logging and monitoring
- Additional backup methods
- Extended AUR support
- Containerized testing
- GUI interface option

### Architecture Improvements

- Plugin system for extensions
- Configuration schema validation
- Enhanced recovery mechanisms
- Performance optimization database
- Multi-distribution support framework

### Integration Opportunities

- System monitoring integration
- Cloud backup support
- Configuration management tools
- Automated testing pipelines
- CI/CD integration improvements
