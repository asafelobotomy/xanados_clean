# xanadOS Clean - Arch Linux System Maintenance

**Version 2.0.0** - Professional-grade maintenance automation for Arch Linux systems with configuration management, error recovery, and comprehensive testing.

This repository provides a comprehensive system maintenance script designed specifically for Arch Linux and its derivatives (Manjaro, EndeavourOS, etc.). The script combines package management, security scanning, backup operations, and system optimization into a single, reliable maintenance workflow.

## ✨ Key Features

### Core Functionality

- **Smart Package Management**: Automatic package updates with AUR helper support (paru/yay)
- **Intelligent Mirroring**: Optimized repository mirrors for faster downloads with reflector
- **Multi-Backup Support**: Timeshift, Snapper, or rsync backup options with smart scheduling
- **Security Scanning**: rkhunter and arch-audit vulnerability assessment
- **Filesystem Maintenance**: Btrfs optimization and SSD TRIM support
- **System Monitoring**: Failed services detection and journal error analysis
- **Arch News**: Latest updates from Arch Linux newsfeeds

### Enhanced Features (v2.0)

- **🔧 Configuration Management**: Flexible settings via config files
- **🛡️ Error Recovery System**: Checkpoint/resume and automatic rollback
- **📋 Comprehensive Testing**: BATS unit testing framework
- **📚 Enhanced Documentation**: API docs and troubleshooting guides
- **⚡ Performance Optimizations**: Faster execution with progress tracking
- **🔒 Security Hardening**: Input validation and privilege management

## Usage

### Basic Usage

Run the maintenance script:

```bash
# Basic interactive mode
./archlinux_clean.sh

# Automatic mode (non-interactive)
./archlinux_clean.sh --auto
```

### Command Line Options

```bash
# Show help
./archlinux_clean.sh --help

# Run automatically (non-interactive)
./archlinux_clean.sh --auto

# Use custom configuration
./archlinux_clean.sh --config ~/.my-config.conf

# Show current configuration
./archlinux_clean.sh --show-config

# Create default configuration file
./archlinux_clean.sh --create-config

# Test mode (dry run)
./archlinux_clean.sh --test-mode
```

### Configuration

Create a personalized configuration:

```bash
# Create default config in ~/.config/xanados_clean/
./archlinux_clean.sh --create-config

# Edit the configuration
nano ~/.config/xanados_clean/config.conf
```

Key configuration options:

```bash
# Enable/disable features
ENABLE_FLATPAK=true
ENABLE_SECURITY_SCAN=true
ENABLE_BTRFS_MAINTENANCE=auto

# Backup settings
BACKUP_METHOD=timeshift
BACKUP_SKIP_THRESHOLD_DAYS=7

# Custom scripts
PRE_MAINTENANCE_SCRIPT="/path/to/pre-script.sh"
POST_MAINTENANCE_SCRIPT="/path/to/post-script.sh"
```

### Error Recovery

If a maintenance operation fails:

1. **Automatic Recovery**: The script will offer recovery options
2. **Manual Recovery**: Check `docs/TROUBLESHOOTING.md` for specific guidance
3. **Resume from Checkpoint**: Restart interrupted sessions automatically

### Testing

Run the comprehensive test suite:

```bash
# Install BATS testing framework first
# Arch: sudo pacman -S bats
# Fedora: sudo dnf install bats

# Run all tests
cd tests && ./run_tests.sh

# Run specific test suite
./tests/run_tests.sh test_archlinux_clean.bats
```

Logs are stored in `~/Documents/system_maint.log` by default.

## Documentation

### Comprehensive Documentation Suite

- **[API Documentation](docs/API.md)** - Complete function reference and usage
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Solutions for common issues
- **[Configuration Reference](config/default.conf)** - All available settings
- **[Testing Guide](tests/README.md)** - How to run and write tests

### Quick Start Guides

- **[AGENTS.md](AGENTS.md)** - Repository contribution guidelines
- **[AGENTS_CI.md](AGENTS_CI.md)** - CI/CD pipeline documentation  
- **[AGENTS_SYSTEM.md](AGENTS_SYSTEM.md)** - System requirements
- **[AGENTS_SECURITY.md](AGENTS_SECURITY.md)** - Security and backup tools

## Architecture

### Project Structure

```text
xanados_clean/
├── archlinux_clean.sh      # Main Arch maintenance script
├── build_appimage.sh       # AppImage packaging script
├── lib/                    # Shared libraries
│   ├── config.sh          # Configuration management
│   ├── recovery.sh        # Error recovery system
│   ├── performance.sh     # Performance monitoring
│   └── enhancements.sh    # Integration layer
├── config/                 # Configuration files
│   └── default.conf       # Default configuration template
├── tests/                  # Test suite
│   ├── run_tests.sh       # Test runner
│   ├── setup_suite.bash   # Test framework setup
│   └── test_*.bats        # Unit test files
├── docs/                   # Documentation
│   ├── API.md             # Function documentation
│   └── TROUBLESHOOTING.md # Problem resolution guide
└── .github/workflows/     # CI/CD pipeline
    └── lint.yml           # Automated testing and linting
```
