#!/usr/bin/env bash
# Launcher script for xanadOS Clean GUI
# This script handles both standalone and AppImage execution

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we're running inside an AppImage
if [[ -n "${APPIMAGE:-}" ]]; then
    # Running as AppImage
    export APPDIR="${APPDIR:-$(dirname "$0")}"
    PYTHON_SCRIPT="$APPDIR/usr/share/xanados_clean/gui/xanados_gui.py"
    MAINTENANCE_SCRIPT="$APPDIR/usr/bin/xanados_clean.sh"
else
    # Running as standalone
    PYTHON_SCRIPT="$SCRIPT_DIR/xanados_gui.py"
    MAINTENANCE_SCRIPT="$SCRIPT_DIR/../xanados_clean.sh"
fi

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not found." >&2
    echo "Please install Python 3 to use the GUI." >&2
    exit 1
fi

# Check for tkinter
if ! python3 -c "import tkinter" 2>/dev/null; then
    echo "Error: Python tkinter module is required but not found." >&2
    echo "Please install python-tkinter or python3-tk package." >&2
    echo "On Arch Linux: sudo pacman -S tk" >&2
    exit 1
fi

# Set the maintenance script path for the GUI
export XANADOS_SCRIPT_PATH="$MAINTENANCE_SCRIPT"

# Launch the GUI
exec python3 "$PYTHON_SCRIPT" "$@"
