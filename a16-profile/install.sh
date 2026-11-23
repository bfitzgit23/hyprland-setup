#!/usr/bin/env bash
# Install this profile into the current user's config on the A16.
# Run as the desktop user (not root), from anywhere:
#     ./install.sh
#
# Existing files are kept: anything already present is skipped, so a second run
# never overwrites hand edits. Delete the target file first to reinstall it.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
ICONS="$HOME/.local/share/icons"

install -d "$CONFIG/hypr" "$CONFIG/quickshell" "$CONFIG/xdg-desktop-portal" "$BIN" "$ICONS"

copy() {  # copy <src> <dst> without clobbering
    if [ -e "$2" ]; then
        echo "keep   $2"
    else
        install -m "${3:-644}" "$1" "$2"
        echo "add    $2"
    fi
}

copy "$HERE/hypr/hyprland.lua"   "$CONFIG/hypr/hyprland.lua"
copy "$HERE/hypr/hypridle.conf"  "$CONFIG/hypr/hypridle.conf"
copy "$HERE/quickshell/shell.qml" "$CONFIG/quickshell/shell.qml"
copy "$HERE/icons/gentoo-symbolic.svg" "$ICONS/gentoo-symbolic.svg"

for script in "$HERE"/local-bin/*; do
    copy "$script" "$BIN/$(basename "$script")" 755
done

cat <<'EOF'

Profile files installed. Still manual, because they need root and your choices:

  1. packages        see README.md ("Prerequisites")
  2. cmus USE flags  cp portage/package.use.cmus /etc/portage/package.use/cmus
  3. RustDesk fix    see rustdesk/rustdesk-wayland.md   (service env + portal)
  4. portal routing  OPTIONAL - only for RustDesk's user-mode GUI, and only
                     after xdg-desktop-portal-luminous is installed:
                     cp portal/hyprland-portals.conf ~/.config/xdg-desktop-portal/
  5. fingerprint     fprint/fprint-enable.sh, after `fprintd-enroll`

Then log out of Hyprland and back in.
EOF
