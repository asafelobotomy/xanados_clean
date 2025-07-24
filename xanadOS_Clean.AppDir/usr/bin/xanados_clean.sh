#!/usr/bin/env bash
# AppImage wrapper for xanadOS Clean

# Set up library path for AppImage environment
if [[ -n "${APPDIR:-}" ]]; then
    export XANADOS_LIB_DIR="$APPDIR/usr/share/xanados_clean/lib"
    exec "$APPDIR/usr/share/xanados_clean/xanados_clean.sh" "$@"
else
    # Fallback for direct execution
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    export XANADOS_LIB_DIR="$SCRIPT_DIR/../share/xanados_clean/lib"
    exec "$SCRIPT_DIR/../share/xanados_clean/xanados_clean.sh" "$@"
fi
