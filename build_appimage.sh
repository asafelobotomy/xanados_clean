#!/usr/bin/env bash
set -euo pipefail

APP=xanadOS_clean
VERSION=1.0
APPDIR="${APP}.AppDir"

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
cp xanadOS_clean.sh "$APPDIR/usr/bin/$APP"
chmod +x "$APPDIR/usr/bin/$APP"

cat > "$APPDIR/$APP.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=XanadOS Clean
Exec=$APP
Icon=$APP
Categories=System;
DESK

# placeholder icon
ICON_URL="https://via.placeholder.com/256.png?text=XanadOS"
wget -q -O "$APPDIR/$APP.png" "$ICON_URL"

cat > "$APPDIR/AppRun" <<'RUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/xanadOS_clean" "$@"
RUN
chmod +x "$APPDIR/AppRun"

if [[ ! -f appimagetool ]]; then
  wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O appimagetool
  chmod +x appimagetool
fi

./appimagetool "$APPDIR" "${APP}-${VERSION}.AppImage"

