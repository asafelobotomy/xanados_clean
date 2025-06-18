# xanadOS Clean

This repository contains `xanadOS_clean.sh`, a comprehensive Bash script for
Arch Linux maintenance. It provides:

- Mirror refresh using Reflector
- Prompted installation of the `paru` AUR helper or fallback to pacman
- Optional system backups via Timeshift, Snapper, or user-defined `rsync` \
  (skipped if a snapshot exists from the last 30 days)
- Dependency checking with interactive installation of recommended packages
- System updates using `paru -Syu` or `sudo pacman -Syu` if paru isn't
  installed, with optional Flatpak updates
- Orphan package removal and cache cleanup with journal rotation
- Security scanning with arch-audit and rkhunter
- Btrfs maintenance tasks with usage-aware balancing and SSD trimming
- Checks for failed systemd services and recent journal errors
- Display of recent Arch news headlines parsed with xmlstarlet
- System reporting with GPU, firewall, SMART status, and sensors
- Interactive menu for full or step-by-step maintenance
- `--auto` flag for unattended execution

## Usage

Run the script directly:

```bash
bash xanadOS_clean.sh
```

For unattended runs, use the `--auto` flag:

```bash
bash xanadOS_clean.sh --auto
```

Run it as a normal user with sudo privileges. Executing the script as root will
cause AUR helpers like `paru` to fail.

Logs are stored in `~/Documents/system_maint.log` by default.

## Building an AppImage

An example `build_appimage.sh` script is included to package the maintenance
script as an AppImage. The steps are:

1. Execute the build script:

```bash
bash build_appimage.sh
```

1. The resulting `xanadOS_clean-1.0.AppImage` can then be distributed and run
   on new systems.

The build script downloads `appimagetool` if necessary and creates a minimal
AppDir containing the script, desktop entry, and placeholder icon.

## GitHub Actions

This repository uses a single GitHub Actions workflow stored in
`.github/workflows/lint.yml`.

The workflow runs multiple linters in parallel using a matrix strategy:

- **markdownlint** – ensures Markdown files follow common style rules using
  [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2).
- **proselint** – checks prose in our documentation with
  [proselint](https://github.com/amperser/proselint).
- **ShellCheck** – lints all shell scripts using
  [ShellCheck](https://github.com/koalaman/shellcheck).
- **yamllint** – validates YAML files with
  [yamllint](https://github.com/adrienverge/yamllint).

The workflow runs automatically on pushes and pull requests to keep the
repository tidy and consistent.
