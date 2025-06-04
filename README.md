# xanadOS Clean

This repository contains `xanadOS_clean.sh`, a comprehensive Bash script for Arch Linux maintenance. It provides:

- Mirror refresh using Reflector
- Prompted installation of the `paru` AUR helper or fallback to pacman
- Optional system backups via Timeshift, Snapper, or user-defined `rsync`
- Dependency checking with interactive installation of recommended packages
- System updates using pacman or paru and optional Flatpak updates
- Orphan package removal and cache cleanup with journal rotation
- Security scanning with arch-audit and rkhunter
- Btrfs maintenance tasks and SSD trimming
- Checks for failed systemd services and recent journal errors
- Display of recent Arch news headlines
- System reporting with GPU, firewall, SMART status, and sensors
- Interactive menu for full or step-by-step maintenance

## Usage

Run the script directly:

```bash
bash xanadOS_clean.sh
```

Run it as a normal user with sudo privileges. Executing the script as root will
cause AUR helpers like `paru` to fail.

Logs are stored in `~/Documents/system_maint.log` by default.

## Building an AppImage

An example `build_appimage.sh` script is included to package the maintenance script as an AppImage. The steps are:

1. Execute the build script:

```bash
bash build_appimage.sh
```

2. The resulting `xanadOS_clean-1.0.AppImage` can then be distributed and run on new systems.

The build script downloads `appimagetool` if necessary and creates a minimal AppDir containing the script, desktop entry, and placeholder icon.

