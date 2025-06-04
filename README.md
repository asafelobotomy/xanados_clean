# xanadOS Clean

This repository contains `xanadOS_clean.sh`, a comprehensive Bash script for
Arch Linux maintenance. It provides:

- Mirror refresh using Reflector
- Prompted installation of the `paru` AUR helper or fallback to pacman
- Optional system backups via Timeshift, Snapper, or user-defined `rsync` \
  (skipped if a snapshot exists from the last 30 days)
- Dependency checking with interactive installation of recommended packages
- System updates using `paru -Syu` or `sudo pacman -Syu` if paru isn't installed
  with optional Flatpak updates
  - **Note:** Earlier versions could mistakenly run `paru` if the package
    manager variable was unset. The script now checks for `paru` directly and
    falls back to `pacman`.
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

This repository uses several GitHub Actions workflows stored in
`.github/workflows`:

- **Markdown Lint** (`markdownlint.yml`) – runs
  [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) to ensure
  all `*.md` files follow common style rules.
- **Proselint** (`proselint.yml`) – checks the prose in our documentation with
  [proselint](https://github.com/amperser/proselint).
- **ShellCheck** (`shellcheck.yml`) – lints all shell scripts using
  [ShellCheck](https://github.com/koalaman/shellcheck).
- **YAML Lint** (`yamllint.yml`) – validates YAML files with
  [yamllint](https://github.com/adrienverge/yamllint).

These workflows run automatically on pushes and pull requests to help keep the
repository tidy and consistent.
