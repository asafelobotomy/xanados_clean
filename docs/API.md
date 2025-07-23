# xanadOS Arch Cleanup API Documentation

## Core Functions

### System Requirements and Validation

#### `require_pacman()`
**Purpose**: Validates that pacman package manager is available  
**Parameters**: None  
**Returns**: 0 on success, 1 if pacman not found  
**Usage**: Called at script startup to ensure Arch Linux environment

#### `check_network()`
**Purpose**: Tests network connectivity  
**Parameters**: None  
**Returns**: 0 if network available, 1 if offline  
**Usage**: Called before network-dependent operations

### Logging and Output

#### `log(message)`
**Purpose**: Outputs formatted informational messages  
**Parameters**: 
- `message` (string): Message to display
**Returns**: Always 0  
**Usage**: `log "System update completed"`

#### `error(message)`
**Purpose**: Outputs formatted error messages to stderr  
**Parameters**: 
- `message` (string): Error message to display
**Returns**: Always 0  
**Usage**: `error "Failed to connect to repository"`

#### `summary(message)`
**Purpose**: Adds message to summary log and displays it  
**Parameters**: 
- `message` (string): Summary message
**Returns**: Always 0  
**Usage**: `summary "Installed 15 packages"`

#### `show_progress(description)`
**Purpose**: Displays progress bar for current operation  
**Parameters**: 
- `description` (string): Description of current step
**Returns**: Always 0  
**Side Effects**: Increments `CURRENT_STEP` counter

### Package Management

#### `choose_pkg_manager()`
**Purpose**: Selects appropriate package manager (Arch only)  
**Parameters**: None  
**Returns**: 0 on success  
**Side Effects**: Sets `PKG_MGR` variable to "pacman" or "paru"  
**Behavior**: 
- Detects existing paru installation
- Offers to install paru if not found (interactive mode)
- Falls back to pacman in auto mode

#### `pkg_mgr_run(args...)`
**Purpose**: Executes package manager commands with correct privileges  
**Parameters**: Variable arguments passed to package manager  
**Returns**: Exit code of package manager command  
**Usage**: `pkg_mgr_run -S --noconfirm package-name`

#### `update_tool_if_outdated(package_name)`
**Purpose**: Updates a package only if newer version is available  
**Parameters**: 
- `package_name` (string): Name of package to check/update
**Returns**: 0 on success or no update needed  
**Usage**: `update_tool_if_outdated "git"`

### System Maintenance

#### `refresh_mirrors()` (Arch)
**Purpose**: Updates package repository mirrors for optimal speed  
**Parameters**: None  
**Returns**: 0 on success  
**Dependencies**: reflector, network connectivity  
**Usage**: Called before system updates

#### `system_update()`
**Purpose**: Performs full system package update  
**Parameters**: None  
**Returns**: 0 on success  
**Behavior**: Updates all packages using pacman/paru

#### `remove_orphans()`
**Purpose**: Removes orphaned packages no longer needed  
**Parameters**: None  
**Returns**: 0 on success  
**Configuration**: Controlled by `ENABLE_ORPHAN_REMOVAL` setting

#### `cache_cleanup()`
**Purpose**: Cleans package cache and temporary files  
**Parameters**: None  
**Returns**: 0 on success  
**Configuration**: Controlled by `ENABLE_CACHE_CLEANUP` setting

### Backup Operations

#### `pre_backup()`
**Purpose**: Creates system backup before maintenance  
**Parameters**: None  
**Returns**: 0 on success or skip  
**Behavior**: 
- Checks for recent backups within threshold
- Uses Timeshift, Snapper, or rsync based on availability
- Can be skipped if recent backup exists

#### `rsync_backup()`
**Purpose**: Performs full system backup using rsync  
**Parameters**: None  
**Returns**: 0 on success  
**Configuration**: Destination set by `RSYNC_BACKUP_DIR`  
**Usage**: Called by `pre_backup()` if other backup tools unavailable

### Security Operations

#### `security_scan()`
**Purpose**: Runs comprehensive security scanning  
**Parameters**: None  
**Returns**: 0 on completion (warnings don't cause failure)  
**Tools Used**: 
- rkhunter (rootkit detection)
- arch-audit (Arch vulnerability scanner)
**Configuration**: Controlled by `ENABLE_SECURITY_SCAN` setting

### Filesystem Maintenance

#### `btrfs_maintenance()`
**Purpose**: Performs Btrfs filesystem maintenance  
**Parameters**: None  
**Returns**: 0 on success or skip if not Btrfs  
**Operations**: 
- Scrub for data integrity
- Balance based on usage
- Defragmentation if needed
**Configuration**: Controlled by `ENABLE_BTRFS_MAINTENANCE` setting

#### `ssd_trim()`
**Purpose**: Runs TRIM/discard on SSDs  
**Parameters**: None  
**Returns**: 0 on success  
**Behavior**: Automatically detects SSDs and runs fstrim  
**Configuration**: Controlled by `ENABLE_SSD_TRIM` setting

### System Monitoring

#### `check_failed_services()`
**Purpose**: Identifies and reports failed systemd services  
**Parameters**: None  
**Returns**: 0 always (informational only)  
**Output**: Lists any services in failed state

#### `check_journal_errors()`
**Purpose**: Scans systemd journal for recent errors  
**Parameters**: None  
**Returns**: 0 always (informational only)  
**Behavior**: Shows errors from last 24 hours

#### `system_report()`
**Purpose**: Generates comprehensive system status report  
**Parameters**: None  
**Returns**: 0 always  
**Information Included**: 
- CPU and memory usage
- Disk space and health
- GPU information
- Temperature sensors
- Network status
- Firewall status

### News and Information

#### `display_arch_news()`
**Purpose**: Shows recent distribution news  
**Parameters**: None  
**Returns**: 0 on success  
**Dependencies**: xmlstarlet for RSS parsing  
**Configuration**: Controlled by `SHOW_NEWS` setting

### Configuration System

#### `load_config()`
**Purpose**: Loads configuration from file or sets defaults  
**Parameters**: None  
**Returns**: 0 on success, 1 on configuration error  
**Search Paths**: 
1. `$XDG_CONFIG_HOME/xanados_clean/config.conf`
2. `$HOME/.xanados_clean.conf`
3. `/etc/xanados_clean/config.conf`
4. `./config/default.conf`

#### `validate_config()`
**Purpose**: Validates and sanitizes configuration values  
**Parameters**: None  
**Returns**: 0 on success, 1 on validation error  
**Behavior**: Sets defaults for missing values, validates ranges

#### `create_default_config()`
**Purpose**: Creates default configuration file for user  
**Parameters**: None  
**Returns**: 0 on success  
**Usage**: `./script.sh --create-config`

### Execution Control

#### `run_step(function, description)`
**Purpose**: Executes a maintenance step with progress tracking  
**Parameters**: 
- `function` (string): Name of function to call
- `description` (string): Human-readable description
**Returns**: Return code of called function  
**Behavior**: 
- Shows progress indicator
- Prompts user if `ASK_EACH` mode enabled
- Handles skipping of steps

#### `main_menu()`
**Purpose**: Displays interactive menu for operation mode selection  
**Parameters**: None  
**Returns**: 0 always  
**Side Effects**: Sets `ASK_EACH` variable based on user choice

## Global Variables

### Configuration Variables
- `AUTO_MODE`: Boolean, enables non-interactive operation
- `ASK_EACH_STEP`: Boolean, prompts before each step
- `LOG_FILE`: String, path to log file
- `PKG_MGR`: String, selected package manager ("pacman" or "paru")
- `ENABLE_*`: Boolean flags for optional features

### Progress Tracking
- `CURRENT_STEP`: Integer, current step number
- `TOTAL_STEPS`: Integer, total number of steps
- `SUMMARY_LOG`: Array, stores summary messages

### System State
- `SUDO`: String, sudo command or empty if running as root
- `USER_CMD`: Array, command prefix for user context operations
- `DISABLED_FEATURES`: Array, features disabled due to missing dependencies

## Error Handling

All functions use consistent error handling:
- Return 0 for success
- Return non-zero for failures
- Use `error()` function for error messages
- Set ERR trap for unexpected failures with line numbers

## Dependencies

### Required Commands
- `pacman` (Arch Linux package manager)
- `sudo`
- Basic POSIX utilities (grep, awk, sed, etc.)

### Optional Commands
- `paru` or `yay` (AUR helpers)
- `timeshift` or `snapper` (backup tools)
- `rkhunter` (security scanning)
- `arch-audit` (Arch security)
- `btrfs` (filesystem maintenance)
- `xmlstarlet` (news parsing)
- `smartctl` (disk health)
- `sensors` (temperature monitoring)
