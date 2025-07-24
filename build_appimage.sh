#!/usr/bin/env bash
# build_appimage.sh - AppImage build script for xanadOS Clean
# This script builds an AppImage package for easy distribution

set -euo pipefail

# Color definitions
readonly GREEN='\033[0;32m'
readonly BLUE='\033[1;34m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Network check function
check_network() {
    if curl --silent --head --fail "https://google.com" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Download appimagetool
download_appimagetool() {
    local appimagetool_url="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    local appimagetool_path="./appimagetool"
    
    printf "%sDownloading appimagetool...%s\n" "${BLUE}" "${NC}"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L "$appimagetool_url" -o "$appimagetool_path"
    elif command -v wget >/dev/null 2>&1; then
        wget "$appimagetool_url" -O "$appimagetool_path"
    else
        printf "%sError: Neither curl nor wget found%s\n" "${RED}" "${NC}"
        return 1
    fi
    
    chmod +x "$appimagetool_path"
    printf "%sappimagetool downloaded successfully%s\n" "${GREEN}" "${NC}"
}

# Main build function
build_appimage() {
    local app_name="${1:-xanadOS_Clean}"
    local version="${2:-2.0.0}"
    
    printf "%sBuilding AppImage for %s v%s%s\n" "${BLUE}" "$app_name" "$version" "${NC}"
    
    # Check network connectivity
    if ! check_network; then
        printf "%sError: No network connection available%s\n" "${RED}" "${NC}"
        return 1
    fi
    
    # Create AppDir structure
    local app_dir="${app_name}.AppDir"
    mkdir -p "$app_dir/usr/bin"
    mkdir -p "$app_dir/usr/share/applications"
    mkdir -p "$app_dir/usr/share/icons/hicolor/256x256/apps"
    
    # Copy main script and libraries
    cp xanados_clean.sh "$app_dir/usr/bin/"
    cp -r lib "$app_dir/usr/bin/"
    cp -r gui "$app_dir/usr/bin/"
    cp -r config "$app_dir/usr/bin/"
    
    # Copy icon if it exists
    if [[ -f "gui/xanados_icon.png" ]]; then
        cp "gui/xanados_icon.png" "$app_dir/usr/share/icons/hicolor/256x256/apps/"
        # Also copy to AppDir root for appimagetool
        cp "gui/xanados_icon.png" "$app_dir/xanados_icon.png"
    fi
    
    # Create desktop file
    cat > "$app_dir/usr/share/applications/${app_name}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=xanadOS Clean
Comment=Arch Linux System Maintenance Tool
Icon=xanados_icon
Exec=xanados_clean.sh
Categories=System;Utility;
Terminal=false
EOF

    # Create desktop file in AppDir root (required by appimagetool)
    cp "$app_dir/usr/share/applications/${app_name}.desktop" "$app_dir/${app_name}.desktop"
    
    # Create AppRun
    cat > "$app_dir/AppRun" <<'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
export PATH="${HERE}/usr/bin:${PATH}"
exec "${HERE}/usr/bin/xanados_clean.sh" "$@"
EOF
    chmod +x "$app_dir/AppRun"
    
    # Download appimagetool if not present
    if [[ ! -f "./appimagetool" ]]; then
        download_appimagetool
    fi
    
    # Build AppImage
    ARCH=x86_64 ./appimagetool "$app_dir" "${app_name}-${version}-x86_64.AppImage"
    
    printf "%sAppImage built successfully: %s-%s-x86_64.AppImage%s\n" "${GREEN}" "${app_name}" "${version}" "${NC}"
}

# Run build if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    build_appimage "$@"
fi
