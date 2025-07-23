#!/usr/bin/env bash
set -euo pipefail

APP=xanadOS_archclean
VERSION=2.0
APPDIR="${APP}.AppDir"
SCRIPT=${1:-xanados_clean.sh}
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2"

check_network() {
  if ! curl -fsI https://github.com >/dev/null; then
    echo "Error: network unavailable" >&2
    exit 1
  fi
}

download_appimagetool() {
  curl -L "$APPIMAGETOOL_URL" -o appimagetool
  echo "${APPIMAGETOOL_SHA256}  appimagetool" | sha256sum -c -
  chmod +x appimagetool
}

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin"
cp "$SCRIPT" "$APPDIR/usr/bin/$APP"
chmod +x "$APPDIR/usr/bin/$APP"

cat > "$APPDIR/$APP.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=XanadOS Arch Cleanup
Exec=$APP
Icon=$APP
Categories=System;Utility;
Comment=Professional Arch Linux maintenance automation
DESK

# placeholder icon
ICON_URL="https://via.placeholder.com/256.png?text=ArchClean"
check_network
wget -q -O "$APPDIR/$APP.png" "$ICON_URL"

cat > "$APPDIR/AppRun" <<'RUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/xanadOS_archclean" "$@"
RUN
chmod +x "$APPDIR/AppRun"

if [[ ! -f appimagetool ]]; then
  check_network
  download_appimagetool
fi

./appimagetool "$APPDIR" "${APP}-${VERSION}.AppImage"

