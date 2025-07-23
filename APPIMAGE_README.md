# xanadOS Clean - AppImage with GUI

This AppImage provides both command-line and graphical interfaces for xanadOS Clean, a professional-grade maintenance automation tool for Arch Linux systems.

## Features

### Graphical User Interface (GUI)
- **User-friendly interface** built with Python tkinter
- **Real-time output** showing maintenance progress
- **Configurable options** for different maintenance modes
- **Progress tracking** with visual indicators
- **Log viewing** integration
- **Safe operation** with dry-run mode support

### Command Line Interface (CLI)
- **Full-featured** command-line access to all maintenance functions
- **Automation-friendly** with scripting support
- **Comprehensive help** and documentation
- **Configuration management** system

## Usage

### GUI Mode (Default)
```bash
# Launch GUI (default behavior)
./xanadOS_Clean-2.0.0-x86_64.AppImage

# Launch GUI explicitly
./xanadOS_Clean-2.0.0-x86_64.AppImage --gui
```

### CLI Mode
```bash
# Show help
./xanadOS_Clean-2.0.0-x86_64.AppImage --help

# Run automatic maintenance
./xanadOS_Clean-2.0.0-x86_64.AppImage --auto

# Run in simple mode
./xanadOS_Clean-2.0.0-x86_64.AppImage --simple

# Dry run (preview only)
./xanadOS_Clean-2.0.0-x86_64.AppImage --test-mode
```

## Requirements

### System Requirements
- **Arch Linux** or derivatives (Manjaro, EndeavourOS, etc.)
- **Python 3** (usually pre-installed)
- **tkinter** for GUI (`sudo pacman -S tk`)
- **Root privileges** for system maintenance operations

### Optional Dependencies
- **paru** or **yay** for AUR support
- **timeshift** for backup functionality
- **reflector** for mirror optimization
- **rkhunter** for security scanning

## GUI Interface Guide

### Main Window
1. **Maintenance Options**: Configure how the maintenance runs
   - **Auto Mode**: Fully automated maintenance (recommended)
   - **Simple Mode**: Basic maintenance only
   - **Dry Run**: Preview changes without applying them
   - **Verbose Output**: Show detailed progress information

2. **Action Buttons**:
   - **Run Maintenance**: Start the maintenance process
   - **Stop**: Abort running maintenance
   - **View Logs**: Open the maintenance log file
   - **About**: Show application information

3. **Output Area**: Real-time display of maintenance progress and results

4. **Progress Bar**: Visual indicator of maintenance progress

### Safety Features
- **Non-destructive by default**: Dry-run mode available
- **User confirmation**: Important operations require confirmation
- **Error recovery**: Automatic rollback on critical failures
- **Comprehensive logging**: All operations are logged

## Installation

### Make Executable
```bash
chmod +x xanadOS_Clean-2.0.0-x86_64.AppImage
```

### Desktop Integration (Optional)
The AppImage includes desktop entry files for integration with your desktop environment. Most file managers will offer to integrate the AppImage when double-clicked.

### Manual Desktop Entry
If you want to manually create a desktop entry:

```bash
# Copy to applications directory
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/xanados-clean.desktop <<EOF
[Desktop Entry]
Type=Application
Name=xanadOS Clean
GenericName=Arch Linux Maintenance
Exec=/path/to/xanadOS_Clean-2.0.0-x86_64.AppImage
Icon=xanadOS_Clean
Categories=System;
Comment=Professional Arch Linux maintenance automation with GUI
Terminal=false
EOF
```

## Security Notes

- **Review before running**: Always understand what maintenance operations will be performed
- **Backup first**: Consider creating system backups before major maintenance
- **Test mode**: Use `--test-mode` to preview changes
- **Regular updates**: Keep the AppImage updated for latest features and security fixes

## Troubleshooting

### GUI Won't Start
1. Check Python 3 installation: `python3 --version`
2. Install tkinter: `sudo pacman -S tk`
3. Try CLI mode: `./xanadOS_Clean-2.0.0-x86_64.AppImage --help`

### Permission Issues
- Run as regular user (the script will request sudo when needed)
- Avoid running the entire application as root

### Missing Dependencies
- Install AUR helper: `sudo pacman -S paru` or `yay`
- Install optional tools as suggested by the application

## Support

For issues, feature requests, or contributions:
- **GitHub**: https://github.com/asafelobotomy/xanados_clean
- **Documentation**: See `docs/` directory in the repository
- **Issues**: Use GitHub issue tracker

## License

GPL-3.0 - See LICENSE file for details.

---

**xanadOS Clean v2.0.0** - Professional-grade maintenance automation for Arch Linux systems.
