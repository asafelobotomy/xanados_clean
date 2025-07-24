#!/bin/bash
# GUI-friendly sudo password prompt using Zenity
# This script is called by sudo when SUDO_ASKPASS is set
# License: GPL-3.0
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Check if zenity is available
if ! command -v zenity >/dev/null 2>&1; then
    echo "Error: zenity not found" >&2
    exit 1
fi

# Use zenity to prompt for password
zenity --password \
    --title="Authentication Required" \
    --text="Administrator password required for system maintenance:

$SUDO_PROMPT" \
    --width=400 \
    --timeout=60

# Exit with the same code as zenity
exit $?
