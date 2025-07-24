# Intelligent Timeout System - No Premature Closure

## Problem Solved
**Question**: "If a process takes longer than 30s to complete, will the app know that the process is active and not just stalled?"

**Answer**: ✅ YES! The app now has an intelligent timeout system that distinguishes between active processes and stalled ones.

## How It Works

### Multi-Level Activity Detection

The app now monitors THREE levels of activity:

#### 1. **Output Activity** (Every 5 minutes)
```bash
# Tracks new lines being written to the log file
if [[ $current_line_count -gt $last_line_count ]]; then
    last_activity=$current_time  # Reset activity timer
fi
```

#### 2. **Process Status** (Continuous)
```bash
# Checks if the maintenance process is still running
if kill -0 "$maintenance_pid" 2>/dev/null; then
    process_running=true
fi
```

#### 3. **CPU Activity** (Advanced)
```bash
# Checks if process or children are using CPU
if pgrep -P "$maintenance_pid" >/dev/null 2>&1 || \
   ps -o pid,pcpu --no-headers -p "$maintenance_pid" | awk '{if ($2 > 0.1) exit 0}'; then
    process_active=true
fi
```

### Timeout Behaviors

| Scenario | Timeout | Action |
|----------|---------|--------|
| **Active Process** | ∞ | Continue monitoring indefinitely |
| **No Output, CPU Active** | ∞ | Show "Long-running operation" message |
| **No Output, I/O Wait** | ∞ | Show "Waiting for I/O" message |
| **Process Died** | Immediate | Complete gracefully |
| **Hard Maximum** | 30 minutes | Force completion |

### Status Messages

The progress bar will show different messages based on activity:

- ✅ **"Long-running operation in progress (15m) - please wait..."**
  - Process is using CPU, just taking time
  
- ⏳ **"Process waiting for I/O or external resource (8m)..."**
  - Process exists but waiting for network/disk/user input
  
- 🔄 **"Process active but no output for 3 minutes - operation in progress..."**
  - Normal for operations like package downloads

## Real-World Examples

### ✅ Will NOT timeout prematurely:
- Large package downloads (could take 10-20 minutes)
- System updates on slow connections  
- BTRFS balance operations (could take hours)
- Security scans of large file systems
- Mirror refresh on slow networks

### ✅ Will timeout appropriately:
- Process crashes and dies (immediate)
- True infinite hangs with no CPU activity (30 minutes max)
- Scripts waiting for user input that never comes

## Configuration

```bash
# Current settings in monitor_progress()
monitoring_timeout=1800     # 30 minutes absolute maximum
activity_timeout=300        # 5 minutes before warning (but continues)
```

## Result

🎯 **The app will NEVER close prematurely if processes are actively working!**

- Long operations can run for hours if they're showing activity
- Only force-closes after 30 minutes of absolute inactivity
- Provides helpful status messages during long operations
- Distinguishes between "working slowly" and "actually stuck"
