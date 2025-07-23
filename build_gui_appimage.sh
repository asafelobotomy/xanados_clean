#!/usr/bin/env bash
set -euo pipefail

APP="xanadOS_Clean"
VERSION="2.0.0"
APPDIR="${APP}.AppDir"
SCRIPT=${1:-xanados_clean.sh}
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2"

check_network() {
  # Use secure curl options for network check
  if ! curl --fail --show-error --location --tlsv1.2 --silent --head https://github.com >/dev/null; then
    echo "Error: network unavailable" >&2
    exit 1
  fi
}

download_appimagetool() {
  if [[ ! -f appimagetool ]]; then
    echo "Downloading appimagetool..."
    
    # Try the releases API to get the latest download URL with secure curl
    LATEST_URL=$(curl --fail --show-error --location --tlsv1.2 --silent \
                      "https://api.github.com/repos/AppImage/AppImageKit/releases/latest" | \
                 grep -o '"browser_download_url": "[^"]*appimagetool-x86_64.AppImage"' | \
                 cut -d'"' -f4 | head -1)
    
    if [[ -n "$LATEST_URL" ]]; then
      curl --fail --show-error --location --tlsv1.2 "$LATEST_URL" -o appimagetool
    else
      # Fallback to the continuous build
      curl --fail --show-error --location --tlsv1.2 "$APPIMAGETOOL_URL" -o appimagetool
    fi
    
    # Make executable without checksum verification for now
    chmod +x appimagetool
    
    # Verify it's a valid AppImage
    if ! ./appimagetool --help >/dev/null 2>&1; then
      echo "Downloaded appimagetool is not valid, removing..."
      rm -f appimagetool
      return 1
    fi
  fi
}

create_appdir_structure() {
  echo "Creating AppDir structure..."
  rm -rf "$APPDIR"
  
  # Create directory structure
  mkdir -p "$APPDIR"/{usr/bin,usr/share/xanados_clean,usr/share/applications,usr/share/icons/hicolor/256x256/apps}
  
  # Copy main script and create a wrapper for AppImage
  cp "$SCRIPT" "$APPDIR/usr/share/xanados_clean/xanados_clean.sh"
  
  # Create wrapper script that sets correct paths
  cat > "$APPDIR/usr/bin/xanados_clean.sh" <<'WRAPPER'
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
WRAPPER
  
  chmod +x "$APPDIR/usr/bin/xanados_clean.sh"
  
  # Modify the actual script to use environment variable for lib path
  sed -i 's|# Load new consolidated library system|# Load library system with configurable path\nLIB_DIR="${XANADOS_LIB_DIR:-$SCRIPT_DIR/lib}"\n# Load new consolidated library system|' "$APPDIR/usr/share/xanados_clean/xanados_clean.sh"
  sed -i 's|\$SCRIPT_DIR/lib/|\$LIB_DIR/|g' "$APPDIR/usr/share/xanados_clean/xanados_clean.sh"
  
  # Copy library files
  if [[ -d "lib" ]]; then
    cp -r lib "$APPDIR/usr/share/xanados_clean/"
  fi
  
  # Copy configuration files
  if [[ -d "config" ]]; then
    cp -r config "$APPDIR/usr/share/xanados_clean/"
  fi
  
  # Copy GUI files
  if [[ -d "gui" ]]; then
    cp -r gui "$APPDIR/usr/share/xanados_clean/"
    # Make launcher executable
    chmod +x "$APPDIR/usr/share/xanados_clean/gui/launch_gui.sh"
  fi
  
  # Create GUI launcher in bin
  cat > "$APPDIR/usr/bin/xanados_gui" <<'EOF'
#!/bin/bash
APPDIR="${APPDIR:-$(dirname "$(dirname "$(readlink -f "$0")")")}"
export XANADOS_SCRIPT_PATH="$APPDIR/usr/bin/xanados_clean.sh"
exec "$APPDIR/usr/share/xanados_clean/gui/launch_gui.sh" "$@"
EOF
  chmod +x "$APPDIR/usr/bin/xanados_gui"
}

create_desktop_entry() {
  echo "Creating desktop entry..."
  cat > "$APPDIR/${APP}.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=xanadOS Clean
GenericName=Arch Linux Maintenance
Exec=xanados_gui
Icon=${APP}
Categories=System;
Comment=Professional Arch Linux maintenance automation with GUI
Keywords=arch;linux;maintenance;system;administration;automation;package;management;security;backup;pacman;aur;
StartupNotify=true
Terminal=false
DESK

  # Also create in applications directory
  cp "$APPDIR/${APP}.desktop" "$APPDIR/usr/share/applications/"
}

create_icon() {
  echo "Creating application icon..."
  if [[ -f "gui/xanados_icon.png" ]]; then
    cp "gui/xanados_icon.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/${APP}.png"
    cp "gui/xanados_icon.png" "$APPDIR/${APP}.png"
  else
    # Download placeholder icon if custom icon doesn't exist
    ICON_URL="https://via.placeholder.com/256/1793D1/FFFFFF?text=XC"
    check_network
    # Use secure curl instead of wget
    curl --fail --show-error --location --tlsv1.2 --silent -o "$APPDIR/${APP}.png" "$ICON_URL" || {
      # Create a simple fallback icon
      echo "Creating fallback icon..."
      cat > "$APPDIR/${APP}.svg" <<'SVG'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="256" height="256" viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">
  <circle cx="128" cy="128" r="120" fill="#1793D1"/>
  <text x="128" y="150" font-family="Arial" font-size="120" font-weight="bold" text-anchor="middle" fill="white">X</text>
</svg>
SVG
      cp "$APPDIR/${APP}.svg" "$APPDIR/${APP}.png"
    }
  fi
}

create_apprun() {
  echo "Creating AppRun..."
  cat > "$APPDIR/AppRun" <<'RUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"

# Set up environment
export APPDIR="$HERE"
export PATH="$HERE/usr/bin:$PATH"

# Check if GUI should be launched (default behavior)
if [[ $# -eq 0 ]] || [[ "$1" == "--gui" ]]; then
    # Launch GUI by default
    exec "$HERE/usr/bin/xanados_gui" "${@:2}"
else
    # Launch command line version for other arguments
    exec "$HERE/usr/bin/xanados_clean.sh" "$@"
fi
RUN
  chmod +x "$APPDIR/AppRun"
}

build_appimage() {
  echo "Building AppImage..."
  check_network
  download_appimagetool
  
  # Set version info and architecture
  export VERSION="$VERSION"
  export ARCH="x86_64"
  
  ./appimagetool "$APPDIR" "${APP}-${VERSION}-x86_64.AppImage"
  
  echo "AppImage created: ${APP}-${VERSION}-x86_64.AppImage"
  echo ""
  echo "Usage:"
  echo "  ./${APP}-${VERSION}-x86_64.AppImage                    # Launch GUI"
  echo "  ./${APP}-${VERSION}-x86_64.AppImage --gui              # Launch GUI explicitly"  
  echo "  ./${APP}-${VERSION}-x86_64.AppImage --help             # Show CLI help"
  echo "  ./${APP}-${VERSION}-x86_64.AppImage --auto             # Run CLI in auto mode"
}

main() {
  echo "Building xanadOS Clean AppImage with GUI..."
  
  # Check dependencies
  if ! command -v python3 >/dev/null; then
    echo "Warning: Python 3 not found. GUI may not work on target systems without Python 3."
  fi
  
  create_appdir_structure
  create_desktop_entry
  create_icon
  create_apprun
  build_appimage
  
  echo "Build complete!"
}

main "$@"
