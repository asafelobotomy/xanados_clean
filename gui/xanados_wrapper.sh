#!/usr/bin/env bash
# GUI-friendly wrapper for xanadOS Clean that handles elevated privileges properly

set -euo pipefail

# Function to check if running in GUI mode
is_gui_mode() {
    [[ "${GUI_MODE:-false}" == "true" ]] || [[ -n "${DISPLAY:-}" && -z "${SSH_TTY:-}" ]]
}

# Function to get elevated privileges for GUI
get_gui_privileges() {
    local command="$1"
    
    # Try pkexec first (best for GUI)
    if command -v pkexec >/dev/null 2>&1; then
        pkexec bash -c "$command"
    # Fallback to sudo with askpass
    elif command -v sudo >/dev/null 2>&1; then
        if [[ -n "${DISPLAY:-}" ]]; then
            # Try to find a GUI sudo helper
            for helper in "/usr/bin/kdesu" "/usr/bin/gksu" "/usr/bin/pkexec"; do
                if [[ -x "$helper" ]]; then
                    case "$helper" in
                        *pkexec) pkexec bash -c "$command" ;;
                        *kdesu) kdesu -c "$command" ;;
                        *gksu) gksu "$command" ;;
                    esac
                    return $?
                fi
            done
        fi
        # Fallback to regular sudo
        sudo bash -c "$command"
    else
        echo "Error: No privilege escalation method available" >&2
        return 1
    fi
}

# Function to run commands with appropriate privilege escalation
run_with_privileges() {
    local command="$1"
    
    if is_gui_mode; then
        get_gui_privileges "$command"
    else
        sudo bash -c "$command"
    fi
}

# Export the function for use by the main script
export -f run_with_privileges

# Set GUI mode if launched from GUI
if [[ -n "${DISPLAY:-}" && -z "${SSH_TTY:-}" && -t 1 ]]; then
    export GUI_MODE="true"
fi

# Get the directory where this wrapper is located
WRAPPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find the actual script to run
if [[ -n "${APPDIR:-}" ]]; then
    # Running as AppImage
    MAIN_SCRIPT="$APPDIR/usr/share/xanados_clean/xanados_clean.sh"
else
    # Running standalone
    MAIN_SCRIPT="$WRAPPER_DIR/../share/xanados_clean/xanados_clean.sh"
    if [[ ! -f "$MAIN_SCRIPT" ]]; then
        MAIN_SCRIPT="$WRAPPER_DIR/xanados_clean.sh"
    fi
fi

# Check if main script exists
if [[ ! -f "$MAIN_SCRIPT" ]]; then
    echo "Error: Cannot find xanados_clean.sh" >&2
    echo "Looked for: $MAIN_SCRIPT" >&2
    exit 1
fi

# Execute the main script with all arguments
exec "$MAIN_SCRIPT" "$@"
