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
- **📚 Enhanced Documentation**: Comprehensive user and developer guides
- **⚡ Performance Optimizations**: Faster execution with progress tracking
- **🔒 Security Hardening**: Input validation and privilege management

### Latest Optimizations (2024-2025)

- **🚀 Advanced Pacman Features**: Parallel downloads, colored output, enhanced security
- **📰 Arch News Integration**: Automated breaking news checks with informant/newscheck
- **🔧 Essential Tool Suite**: pacman-contrib, pkgfile, arch-audit, rebuild-detector
- **⚡ Performance Tuning**: SSD optimization, zram compression, memory management
- **🔒 Enhanced Security**: CVE scanning, package integrity, unowned file detection
- **🔄 Automated Hooks**: Proactive maintenance monitoring and alerts

## Quick Start

### AppImage with GUI (Easiest)

**🎯 NEW: Download and run the GUI AppImage for the easiest experience!**

1. Download the latest AppImage from [Releases](https://github.com/asafelobotomy/xanados_clean/releases)
2. Make it executable: `chmod +x xanadOS_Clean-2.0.0-x86_64.AppImage`
3. Double-click to launch the GUI, or run from terminal:

```bash
# Launch GUI
./xanadOS_Clean-2.0.0-x86_64.AppImage

# Or use command line
./xanadOS_Clean-2.0.0-x86_64.AppImage --auto
```

The AppImage includes both GUI and CLI interfaces and requires no installation.

### Traditional Installation

**Option 1: Automated Installation (Recommended)**

```bash
git clone https://github.com/asafelobotomy/xanados_clean.git
cd xanados_clean
./install.sh
```

This will:
- Install xanadOS Clean system-wide
- Create symlinks for easy access
- Set up systemd automation (optional)
- Configure both full and simple modes

**Option 2: Manual Installation**

1. Clone the repository:

   ```bash
   git clone https://github.com/asafelobotomy/xanados_clean.git
   cd xanados_clean
   chmod +x xanados_clean.sh
   ```

2. Run the script:

   ```bash
   # Interactive mode (recommended)
   ./xanados_clean.sh
   
   # Automatic mode
   ./xanados_clean.sh --auto
   ```

### Usage Modes

xanadOS Clean offers multiple modes to suit different user needs:

#### 🔧 Full Mode (Default)
Complete maintenance with all advanced features:
```bash
xanados-clean                    # Interactive
xanados-clean --auto             # Automatic
```
- Full package management (pacman + AUR)
- Security scanning (rkhunter, arch-audit)
- Performance monitoring
- Backup operations
- System reporting
- Error recovery

#### 🚀 Simple Mode (New!)
Basic maintenance for casual users (like arch-cleaner):
```bash
xanados-clean --simple           # Installed version
./xanados_clean.sh --simple      # Local version
```
- System package updates
- Orphaned package removal
- Cache cleanup
- Service status check
- Fast execution (~2-3 minutes)

#### 🏢 Automated Mode
System-wide automation via systemd:
```bash
# Set up during installation
./install.sh

# Manual timer management
systemctl --user enable xanados-clean.timer
systemctl --user start xanados-clean.timer
```

### Command Line Options

```bash
# Show help
./xanados_clean.sh --help

# Run automatically (non-interactive)
./xanados_clean.sh --auto

# Use custom configuration
./xanados_clean.sh --config ~/.my-config.conf

# Show current configuration
./xanados_clean.sh --show-config

# Create default configuration file
./xanados_clean.sh --create-config

# Test mode (dry run)
./xanados_clean.sh --test-mode
```

### Configuration

Create a personalized configuration:

```bash
# Create default config in ~/.config/xanados_clean/
./xanados_clean.sh --create-config

# Edit the configuration
nano ~/.config/xanados_clean/config.conf
```

Key configuration options:

```bash
# Enable/disable features
ENABLE_FLATPAK=true
ENABLE_SECURITY_SCAN=true
ENABLE_BTRFS_MAINTENANCE=auto
## Configuration

Create a configuration file for customized settings:

```bash
./xanados_clean.sh --create-config
```

Key configuration options:

```bash
# General settings
AUTO_MODE=false
ASK_EACH_STEP=false

# Backup settings
BACKUP_METHOD=timeshift
BACKUP_SKIP_THRESHOLD_DAYS=7

# Feature toggles
ENABLE_SECURITY_SCAN=true
ENABLE_ARCH_OPTIMIZATIONS=true
```

## Documentation

- **[User Guide](docs/USER_GUIDE.md)** - Complete setup and usage instructions
- **[Developer Guide](docs/DEVELOPER_GUIDE.md)** - API reference, testing, and development
- **[Changelog](CHANGELOG.md)** - Version history and updates

## Testing

Run the test suite to verify functionality:

```bash
# Install BATS testing framework
sudo pacman -S bats

# Run all tests
cd tests && ./run_tests.sh
```

## Project Structure

```text
xanados_clean/
├── xanados_clean.sh        # Main script
├── lib/                    # Core libraries
│   ├── config.sh          # Configuration management
│   ├── recovery.sh        # Error recovery system
│   ├── performance.sh     # Performance monitoring
│   ├── arch_optimizations.sh # Arch-specific features
│   └── enhancements.sh    # Integration layer
├── config/                 # Configuration files
├── tests/                  # Test suite
├── docs/                   # Documentation
│   ├── USER_GUIDE.md      # User documentation
│   └── DEVELOPER_GUIDE.md # Developer documentation
└── archive/                # Historical documentation
```

## Requirements

- **OS**: Arch Linux or derivatives (Manjaro, EndeavourOS)
- **Shell**: Bash 4.0+
- **Privileges**: sudo access
- **Network**: Internet connection for updates
- **Optional**: BATS (testing), Node.js (development)

## License & Support

- **License**: GPL-3.0
- **Issues**: [GitHub Issues](https://github.com/asafelobotomy/xanados_clean/issues)
- **Logs**: `~/Documents/system_maint.log`

For detailed usage instructions, see the [User Guide](docs/USER_GUIDE.md).  
For development information, see the [Developer Guide](docs/DEVELOPER_GUIDE.md).
