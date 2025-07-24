#!/bin/bash
# GUI authentication wrapper that uses the best available method

# Check what GUI authentication method to use
if command -v pkexec >/dev/null 2>&1; then
    # pkexec is available - best option for GUI
    exec pkexec "$@"
elif command -v kdesu >/dev/null 2>&1; then
    # KDE's GUI sudo
    exec kdesu -c "$(printf '%q ' "$@")"
elif command -v gksu >/dev/null 2>&1; then
    # GNOME's GUI sudo
    exec gksu "$(printf '%q ' "$@")"
else
    # Fallback to regular sudo (will prompt in terminal)
    exec sudo "$@"
fi
