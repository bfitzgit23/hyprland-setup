"""Snapshot the Dell desktop's configuration into dell/ in this folder.

Uses SSH (paramiko) because the box has password auth only. Run:

    python pull_dell.py [host] [user] [password]

Writes dell-snapshot.tar.gz and extracts it under dell/, so the restore script
has a faithful copy of what was actually running.
"""
import os
import shlex
import sys
import tarfile

import paramiko

HOST = sys.argv[1] if len(sys.argv) > 1 else "10.0.0.37"
USER = sys.argv[2] if len(sys.argv) > 2 else "root"
PWD = sys.argv[3] if len(sys.argv) > 3 else "1"

PATHS = [
    # desktop user's live config
    "/home/bennji/.config/hypr/hyprland.lua",
    "/home/bennji/.config/hypr/hypridle.conf",
    "/home/bennji/.config/quickshell/shell.qml",
    "/home/bennji/.local/bin",
    "/home/bennji/.local/share/icons/gentoo-symbolic.svg",
    "/home/bennji/.config/xdg-desktop-portal",
    # session entry point
    "/usr/local/bin/start-hyprland-wayland",
    # system config changed for this machine
    "/etc/conf.d/rustdesk",
    "/etc/init.d/rustdesk",
    "/etc/NetworkManager/conf.d",
    "/etc/modprobe.d/20-broadcom-sta.conf",
    "/etc/modprobe.d/wl.conf",
    "/etc/udev/rules.d/61-broadcom-cv2-5834.rules",
    "/etc/polkit-1/rules.d/49-desktop-power.rules",
    "/etc/portage/package.use",
    "/etc/portage/package.accept_keywords/libfprint-tod",
    "/etc/portage/package.accept_keywords/rustdesk",
    "/etc/portage/package.unmask",
    # local overlay holding the libfprint TOD ebuild and rustdesk-bin
    "/var/db/repos/bennji-overlay/sys-auth/libfprint",
    "/var/db/repos/bennji-overlay/net-misc",
    # package selection
    "/var/lib/portage/world",
]

OUT = os.environ.get("OUT", "dell")
ARCHIVE = f"{OUT}-snapshot.tar.gz"


def main():
    t = paramiko.Transport((HOST, 22))
    t.banner_timeout = 15
    t.connect(username=USER, password=PWD)
    ch = t.open_session()
    ch.set_combine_stderr(False)
    cmd = "tar -czf - " + " ".join(shlex.quote(p) for p in PATHS) + " 2>/dev/null"
    ch.exec_command(cmd)
    data = ch.makefile("rb").read()
    ch.makefile_stderr("rb").read()
    t.close()

    with open(ARCHIVE, "wb") as fh:
        fh.write(data)
    print(f"downloaded {len(data)} bytes -> {ARCHIVE}")
    if len(data) < 1000:
        print("archive suspiciously small; aborting extract")
        return 1

    os.makedirs(OUT, exist_ok=True)
    with tarfile.open(ARCHIVE) as tf:
        tf.extractall(OUT, filter="data")
    count = sum(len(files) for _, _, files in os.walk(OUT))
    print(f"extracted {count} files under {OUT}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
