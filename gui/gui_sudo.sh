#!/bin/bash
# GUI authentication wrapper that uses the best available method
# License: GPL-3.0
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

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
