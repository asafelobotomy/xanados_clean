# Troubleshooting Guide for xanadOS Clean

## Common Issues and Solutions

### Installation and Setup Issues

#### "pacman is required"

**Cause**: Script running on non-Arch Linux system  
**Solution**:
  - Use this script only on Arch Linux and derivatives
  - Ensure you're running on a supported system

#### "Please run this script as a regular user with sudo access"

**Problem**: Script detects it's running as root without sudo context.

**Solution**:

- Run the script as a regular user: `./xanados_clean.sh`
- Ensure your user has sudo privileges: `sudo -v`
- Do not use `su` to switch to root before running

#### Permission denied errors

**Problem**: Script cannot write to log file or access certain directories.

**Solution**:

- Check that the log directory is writable: `ls -la ~/Documents/`
- If using custom log location, ensure the directory exists and is writable
- Verify sudo privileges are working: `sudo -v`

### Network and Repository Issues

#### "No network, skipping mirror refresh"

**Problem**: Network connectivity test fails.

**Solution**:

- Check internet connection: `ping -c1 google.com`
- Verify DNS resolution: `nslookup archlinux.org`
- Check firewall settings that might block outgoing connections
- Try running with `--auto` flag to skip interactive network tests

#### Mirror refresh fails or times out

**Problem**: Reflector hangs or fails to update mirrors.

**Solution**:

- Check if reflector is installed: `pacman -Qi reflector`
- Manually update mirrors: `sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist`
- Use different mirror selection: edit `/etc/pacman.d/mirrorlist` manually
- Check if your region has sufficient mirrors

#### Package update failures

**Problem**: System update fails with signature, dependency, or download errors.

**Solution**:

- Update package database: `sudo pacman -Syy`
- Check for conflicting packages: `pacman -Dk`
- Clear package cache: `sudo pacman -Scc`
- Update keyring first: `sudo pacman -S archlinux-keyring`
- For partial upgrades, try: `sudo pacman -Syu --ignore problematic-package`

### AUR and Package Manager Issues

#### Paru/Yay installation fails

**Problem**: AUR helper installation fails during dependency check.

**Solution**:

- Ensure base-devel is installed: `sudo pacman -S base-devel`
- Check git is available: `pacman -Qi git`
- Manually install paru:

```bash
cd /tmp
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

- Use pacman if AUR helper fails: script will fall back automatically

#### "No AUR helper found" in auto mode

**Problem**: Script cannot find paru or yay in automatic mode.

**Solution**:

- Install an AUR helper manually before running script
- Run script in interactive mode to install AUR helper during execution
- Edit configuration to set `AUR_HELPER=none` to use only pacman

### Backup Issues

#### Timeshift backup fails

**Problem**: Timeshift cannot create snapshot.

**Solution**:

- Check available disk space: `df -h`
- Verify Timeshift is configured: `sudo timeshift --list`
- Check if snapshot location has sufficient space
- Configure Timeshift: `sudo timeshift-gtk`

#### Snapper configuration missing

**Problem**: Snapper commands fail with "no config found".

**Solution**:

- Create snapper configuration: `sudo snapper -c root create-config /`
- Check existing configurations: `sudo snapper list-configs`
- Ensure Btrfs filesystem is properly set up for snapshots

#### Rsync backup hangs or fails

**Problem**: Rsync backup operation doesn't complete.

**Solution**:

- Check destination has sufficient space
- Verify destination path is writable
- Use incremental backup by not deleting previous backup
- Check for permission issues on source files

### Security Scanning Issues

#### Rkhunter reports warnings

**Problem**: Rkhunter scan shows potential security issues.

**Solutions**:

- Update rkhunter database: `sudo rkhunter --update`
- Review warnings carefully - many are false positives
- Update file properties database: `sudo rkhunter --propupd`
- Check specific warnings:
  - File property changes: Usually safe after updates
  - New startup files: Review what was installed recently
  - Suspicious files: Investigate paths and file contents

#### Arch-audit shows vulnerabilities

**Problem**: arch-audit reports package vulnerabilities.

**Solution**:

- Update affected packages immediately: `sudo pacman -S package-name`
- Check if updates are available: `checkupdates`
- Review CVE details for severity assessment
- Consider removing unused vulnerable packages

### Filesystem and Storage Issues

#### Btrfs maintenance fails

**Problem**: Btrfs scrub or balance operations fail.

**Solution**:

- Check filesystem errors: `sudo btrfs filesystem show`
- Ensure sufficient free space for balance operations
- Run scrub manually: `sudo btrfs scrub start /`
- Check scrub status: `sudo btrfs scrub status /`
- For balance issues, try filtered balance: `sudo btrfs balance start -dusage=50 /`

#### SSD TRIM fails

**Problem**: fstrim command fails or doesn't run.

**Solution**:

- Check if SSD supports TRIM: `lsblk -D`
- Verify filesystem is mounted with discard support
- Run manual TRIM: `sudo fstrim -av`
- Enable periodic TRIM: `sudo systemctl enable fstrim.timer`

#### Disk space warnings

**Problem**: Script reports low disk space.

**Solution**:

- Clean package cache: `sudo pacman -Scc`
- Remove orphaned packages: `sudo pacman -Rns $(pacman -Qtdq)`
- Clear journal logs: `sudo journalctl --vacuum-time=7d`
- Check large files: `du -h / | grep '^[0-9.]*G'`

### Configuration Issues

#### Configuration file not loaded

**Problem**: Custom settings are ignored.

**Solution**:

- Check configuration file path and permissions
- Verify configuration syntax (no bash syntax errors)
- Use `--show-config` to see loaded values
- Check configuration search order in documentation

#### Invalid configuration values

**Problem**: Script reports configuration validation errors.

**Solution**:

- Review error messages for specific invalid values
- Check data types (true/false for booleans, numbers for numeric values)
- Ensure choice values match allowed options
- Reset to defaults by removing invalid lines

### Performance Issues

#### Script runs very slowly

**Problem**: Operations take much longer than expected.

**Solution**:

- Check system load: `htop` or `top`
- Verify sufficient RAM available
- Check for disk I/O bottlenecks: `iotop`
- Run during off-peak hours
- Consider running with `nice` priority: `nice -n 10 ./script.sh`

#### High memory usage during operation

**Problem**: System becomes unresponsive during maintenance.

**Solution**:

- Close unnecessary applications before running
- Increase swap space if needed
- Run individual maintenance steps separately
- Use `--ask-each` mode to control execution timing

### Logging Issues

#### Log file not created

**Problem**: No log file appears in expected location.

**Solution**:

- Check if Documents directory exists: `ls -la ~/Documents/`
- Verify write permissions on log directory
- Check custom log file path in configuration
- Look for logs in fallback location: `~/system_maint.log`

#### Log rotation not working

**Problem**: Log files grow too large.

**Solution**:

- Check configuration values for log rotation
- Manually rotate logs: `logrotate -f /path/to/logrotate.conf`
- Clear old logs: `truncate -s 0 ~/Documents/system_maint.log`
- Adjust `MAX_LOG_SIZE` and `LOG_ROTATION_COUNT` in configuration

## Getting Help

### Debug Mode

Enable debug mode for verbose output:

```bash
# In configuration file
DEBUG_MODE=true

# Or set environment variable
DEBUG_MODE=true ./xanados_clean.sh
```

### Log Analysis

Check recent log entries:

```bash
tail -n 50 ~/Documents/system_maint.log
```

Search for specific errors:

```bash
grep -i error ~/Documents/system_maint.log
```

### System Information

Gather system information for bug reports:

```bash
# System details
uname -a
lsb_release -a 2>/dev/null || cat /etc/os-release

# Package manager version
pacman --version

# Disk space
df -h

# Memory usage
free -h

# Recent system logs
journalctl -p err -n 20
```

### Reporting Issues

When reporting problems, include:

1. Operating system and version
2. Script version (xanados_clean.sh v2.0)
3. Complete error messages
4. Relevant log file entries
5. System configuration details
6. Steps to reproduce the issue

### Recovery Procedures

#### If system update breaks boot

1. Boot from live USB/CD
2. Mount system partition
3. Arch: `arch-chroot /mnt`
4. Downgrade problematic packages
5. Rebuild initramfs if needed

#### If backup is needed

1. Check available backups: `sudo timeshift --list`
2. Restore from backup: `sudo timeshift --restore`
3. Or manually restore from rsync backup

#### Emergency system repair

1. Boot to recovery mode
2. Run filesystem check: `fsck /dev/sdXY`
3. Check system logs: `journalctl -p err`
4. Reinstall critical packages
5. Rebuild bootloader if necessary
