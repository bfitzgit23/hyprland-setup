#!/usr/bin/env bash
# Device list for the bar widget. One record per line, pipe separated:
#
#   phone|android|<serial>|<model>
#   phone|iphone|<serial>|<name>
#   usb|/dev/<name>|<label>|<size>|<mountpoint>
#
# Android needs `adb` (dev-util/android-tools) and USB debugging enabled; the
# iPhone branch needs libimobiledevice (app-pda/libimobiledevice). USB storage
# comes from lsblk: HOTPLUG/RM marks the devices that are actually removable.
set -u

if command -v adb >/dev/null 2>&1; then
    adb devices -l 2>/dev/null | awk 'NR > 1 && $2 == "device" {
        model = "";
        for (i = 3; i <= NF; i++) if ($i ~ /^model:/) { model = $i; sub(/^model:/, "", model) }
        gsub(/_/, " ", model);
        printf "phone|android|%s|%s\n", $1, (model == "" ? "Android device" : model)
    }'
fi

if command -v idevice_id >/dev/null 2>&1; then
    for udid in $(idevice_id -l 2>/dev/null); do
        name=$(ideviceinfo -u "$udid" -k DeviceName 2>/dev/null)
        printf 'phone|iphone|%s|%s\n' "$udid" "${name:-iPhone}"
    done
fi

if command -v lsblk >/dev/null 2>&1; then
    lsblk -J -o NAME,LABEL,SIZE,MOUNTPOINT,TYPE,HOTPLUG,RM 2>/dev/null | jq -r '
        (.blockdevices // [])
        | map(select(.hotplug == true or .rm == true))
        | .[]
        | if .children then (.children[] | {n: .name, l: .label, s: .size, m: .mountpoint})
          else {n: .name, l: .label, s: .size, m: .mountpoint} end
        | select(.n != null)
        | "usb|/dev/\(.n)|\(.l // "USB drive")|\(.s // "?")|\(.m // "")"'
fi
