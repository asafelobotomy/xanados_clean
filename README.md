# xanadOS Clean

This repository contains `xanadOS_clean.sh`, a comprehensive Bash script for Arch Linux maintenance. It provides:

- Mirror refresh using Reflector
- Optional system backups via Timeshift, Snapper, or rsync
- Dependency checking for common utilities
- System and Flatpak updates
- Orphan package removal and cache cleanup
- Security scanning with arch-audit and rkhunter
- Btrfs maintenance and SSD trimming
- Checks for failed systemd services and recent journal errors
- System reporting with GPU, firewall, and SMART status
- Interactive or unattended execution with a simple menu

## Usage

Run the script directly:

```bash
bash xanadOS_clean.sh
```

Logs are stored in `~/Documents/system_maint.log` by default.

## Building an AppImage

An example `build_appimage.sh` script is included to package the maintenance script as an AppImage. The steps are:

1. Execute the build script:

```bash
bash build_appimage.sh
```

2. The resulting `xanadOS_clean-1.0.AppImage` can then be distributed and run on new systems.

The build script downloads `appimagetool` if necessary and creates a minimal AppDir containing the script, desktop entry, and placeholder icon.

