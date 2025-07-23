#!/bin/bash
# build_zenity_appimage.sh - Build AppImage with Zenity GUI
# Creates a native GUI AppImage using Zenity dialogs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/xanadOS_Clean.AppDir"
APP_NAME="xanadOS_Clean"
VERSION="2.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    printf "${GREEN}[+]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[!]${NC} %s\n" "$1" >&2
}

info() {
    printf "${BLUE}[i]${NC} %s\n" "$1"
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local missing=()
    
    if ! command -v appimagetool >/dev/null 2>&1; then
        missing+=("appimagetool")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        error "Please install appimagetool to build AppImages"
        exit 1
    fi
}

# Clean up previous build
cleanup_build() {
    if [[ -d "$BUILD_DIR" ]]; then
        log "Cleaning up previous build..."
        rm -rf "$BUILD_DIR"
    fi
}

# Create AppDir structure
create_appdir_structure() {
    log "Creating AppDir structure..."
    
    # Create directory structure
    mkdir -p "$BUILD_DIR"/usr/{bin,share/{applications,icons/hicolor/256x256/apps,xanados_clean/{lib,config,docs,gui}}}
    
    # Copy main script
    cp "$SCRIPT_DIR/xanados_clean.sh" "$BUILD_DIR/usr/share/xanados_clean/"
    chmod +x "$BUILD_DIR/usr/share/xanados_clean/xanados_clean.sh"
    
    # Copy library files
    cp -r "$SCRIPT_DIR/lib"/* "$BUILD_DIR/usr/share/xanados_clean/lib/"
    
    # Copy configuration
    cp -r "$SCRIPT_DIR/config"/* "$BUILD_DIR/usr/share/xanados_clean/config/"
    
    # Copy documentation
    cp -r "$SCRIPT_DIR/docs"/* "$BUILD_DIR/usr/share/xanados_clean/docs/"
    
    # Copy zenity GUI script
    cp "$SCRIPT_DIR/gui/zenity_gui.sh" "$BUILD_DIR/usr/share/xanados_clean/gui/"
    chmod +x "$BUILD_DIR/usr/share/xanados_clean/gui/zenity_gui.sh"
    
    # Copy other important files
    cp "$SCRIPT_DIR/README.md" "$BUILD_DIR/usr/share/xanados_clean/"
    cp "$SCRIPT_DIR/LICENSE" "$BUILD_DIR/usr/share/xanados_clean/"
}

# Create desktop entry
create_desktop_entry() {
    log "Creating desktop entry..."
    
    cat > "$BUILD_DIR/usr/share/applications/xanados_clean.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=xanadOS Clean
Comment=Professional Arch Linux system maintenance tool
Exec=xanados_clean %f
Icon=xanados_clean
Categories=System;Settings;
Keywords=system;maintenance;cleanup;arch;linux;
Terminal=false
StartupNotify=true
EOF

    # Create symlink for desktop file
    ln -sf usr/share/applications/xanados_clean.desktop "$BUILD_DIR/xanados_clean.desktop"
}

# Create application icon
create_application_icon() {
    log "Creating application icon..."
    
    # Create a simple icon using ImageMagick if available, otherwise use a basic one
    if command -v convert >/dev/null 2>&1; then
        # Create an attractive icon with ImageMagick
        convert -size 256x256 xc:transparent \
            -fill "#2E86C1" -draw "circle 128,128 128,40" \
            -fill white -pointsize 60 -font sans-bold \
            -gravity center -annotate +0-20 "xOS" \
            -fill white -pointsize 24 -font sans \
            -gravity center -annotate +0+25 "CLEAN" \
            "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps/xanados_clean.png"
    else
        # Fallback: Create icon using Python if available
        if command -v python3 >/dev/null 2>&1 && python3 -c "import PIL" 2>/dev/null; then
            python3 - << 'EOF'
from PIL import Image, ImageDraw, ImageFont
import os

# Create a 256x256 image
img = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Draw background circle
draw.ellipse([20, 20, 236, 236], fill='#2E86C1', outline='#1B4F72', width=4)

# Try to use a system font, fallback to default
try:
    font_large = ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans-Bold.ttf', 48)
    font_small = ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans.ttf', 20)
except:
    try:
        font_large = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 48)
        font_small = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 20)
    except:
        font_large = ImageFont.load_default()
        font_small = ImageFont.load_default()

# Draw text
draw.text((128, 110), 'xOS', font=font_large, anchor='mm', fill='white')
draw.text((128, 150), 'CLEAN', font=font_small, anchor='mm', fill='white')

# Save the image
os.makedirs('xanadOS_Clean.AppDir/usr/share/icons/hicolor/256x256/apps', exist_ok=True)
img.save('xanadOS_Clean.AppDir/usr/share/icons/hicolor/256x256/apps/xanados_clean.png')
EOF
        else
            # Ultimate fallback: Create a simple text-based icon
            cat > "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps/xanados_clean.svg" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="256" height="256" xmlns="http://www.w3.org/2000/svg">
  <circle cx="128" cy="128" r="108" fill="#2E86C1" stroke="#1B4F72" stroke-width="4"/>
  <text x="128" y="120" font-family="sans-serif" font-size="40" font-weight="bold" text-anchor="middle" fill="white">xOS</text>
  <text x="128" y="150" font-family="sans-serif" font-size="16" text-anchor="middle" fill="white">CLEAN</text>
</svg>
EOF
            # Convert SVG to PNG if possible
            if command -v inkscape >/dev/null 2>&1; then
                inkscape --export-type=png --export-width=256 --export-height=256 \
                    "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps/xanados_clean.svg" \
                    --export-filename="$BUILD_DIR/usr/share/icons/hicolor/256x256/apps/xanados_clean.png"
                rm "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps/xanados_clean.svg"
            else
                # Keep SVG if can't convert
                log "Keeping SVG icon (inkscape not available for conversion)"
            fi
        fi
    fi
    
    # Create symlink for icon
    if [[ -f "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps/xanados_clean.png" ]]; then
        ln -sf usr/share/icons/hicolor/256x256/apps/xanados_clean.png "$BUILD_DIR/xanados_clean.png"
    elif [[ -f "$BUILD_DIR/usr/share/icons/hicolor/256x256/apps/xanados_clean.svg" ]]; then
        ln -sf usr/share/icons/hicolor/256x256/apps/xanados_clean.svg "$BUILD_DIR/xanados_clean.svg"
    fi
}

# Create AppRun script
create_apprun() {
    log "Creating AppRun launcher..."
    
    cat > "$BUILD_DIR/AppRun" << 'EOF'
#!/bin/bash
# AppRun for xanadOS Clean

SELF="$(readlink -f "$0")"
HERE="${SELF%/*}"
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH:-}"

# Set environment variables for the script
export XANADOS_SCRIPT_PATH="${HERE}/usr/share/xanados_clean/xanados_clean.sh"
export XANADOS_GUI_PATH="${HERE}/usr/share/xanados_clean/gui/zenity_gui.sh"

# Check command line arguments
case "${1:-}" in
    --gui|"")
        # Launch GUI mode (default)
        if command -v zenity >/dev/null 2>&1; then
            exec "${HERE}/usr/share/xanados_clean/gui/zenity_gui.sh" "${@:2}"
        else
            zenity --error \
                --title="Missing Dependency" \
                --text="Zenity is required for the GUI but is not installed.

Please install zenity:
sudo pacman -S zenity

Or run in CLI mode:
$0 --cli" 2>/dev/null || \
            echo "Error: Zenity is required for GUI mode. Install with: sudo pacman -S zenity"
            exit 1
        fi
        ;;
    --cli)
        # CLI mode
        exec "${HERE}/usr/share/xanados_clean/xanados_clean.sh" "${@:2}"
        ;;
    --help|-h)
        # Show help for both modes
        echo "xanadOS Clean v2.0.0 - Professional Arch Linux system maintenance"
        echo ""
        echo "USAGE:"
        echo "  $0                    Launch GUI (default)"
        echo "  $0 --gui             Launch GUI explicitly"  
        echo "  $0 --cli [OPTIONS]   Launch CLI mode"
        echo ""
        echo "GUI MODE:"
        echo "  Interactive dialogs for easy system maintenance"
        echo "  Native system integration with Zenity"
        echo ""
        echo "CLI MODE OPTIONS:"
        "${HERE}/usr/share/xanados_clean/xanados_clean.sh" --help | tail -n +3
        ;;
    *)
        # Pass all other arguments to CLI
        exec "${HERE}/usr/share/xanados_clean/xanados_clean.sh" "$@"
        ;;
esac
EOF

    chmod +x "$BUILD_DIR/AppRun"
}

# Build the AppImage
build_appimage() {
    log "Building AppImage..."
    
    if ! ARCH=x86_64 appimagetool "$BUILD_DIR" "${APP_NAME}-${VERSION}-x86_64.AppImage"; then
        error "Failed to build AppImage"
        exit 1
    fi
    
    log "AppImage created: ${APP_NAME}-${VERSION}-x86_64.AppImage"
    
    # Show file size
    local size
    size=$(du -h "${APP_NAME}-${VERSION}-x86_64.AppImage" | cut -f1)
    info "AppImage size: $size"
}

# Show usage instructions
show_usage() {
    log "Build complete!"
    echo ""
    echo "Usage:"
    echo "  ./${APP_NAME}-${VERSION}-x86_64.AppImage                    # Launch GUI"
    echo "  ./${APP_NAME}-${VERSION}-x86_64.AppImage --gui              # Launch GUI explicitly"
    echo "  ./${APP_NAME}-${VERSION}-x86_64.AppImage --cli --help       # Show CLI help"
    echo "  ./${APP_NAME}-${VERSION}-x86_64.AppImage --cli --auto       # Run CLI in auto mode"
    echo ""
    echo "GUI Features:"
    echo "  • Native Zenity dialogs"
    echo "  • Configuration forms"
    echo "  • Progress monitoring"
    echo "  • Real-time log viewing"
    echo "  • System integration"
}

# Main execution
main() {
    echo "Building xanadOS Clean AppImage with Zenity GUI..."
    
    check_dependencies
    cleanup_build
    create_appdir_structure
    create_desktop_entry
    create_application_icon
    create_apprun
    build_appimage
    show_usage
}

# Run main function
main "$@"
