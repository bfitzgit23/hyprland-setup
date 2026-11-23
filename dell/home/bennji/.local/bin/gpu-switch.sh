#!/usr/bin/env bash
INTEL="/dev/dri/by-path/pci-0000:00:02.0-card"
AMD="/dev/dri/by-path/pci-0000:01:00.0-card"
CONF="$HOME/.config/hypr/hyprland.conf"

case "$1" in
    run)
        shift
        DRI_PRIME=1 __VK_LAYER_MESA_device_select=1002:6995 exec "$@"
        ;;
    intel)
        sed -i "s|^env = AQ_DRM_DEVICES,.*|env = AQ_DRM_DEVICES,${INTEL}:${AMD}|" "$CONF"
        notify-send "GPU Mode: Intel UHD 630" "Log out and back in to apply primary compositor switch."
        ;;
    amd)
        sed -i "s|^env = AQ_DRM_DEVICES,.*|env = AQ_DRM_DEVICES,${AMD}:${INTEL}|" "$CONF"
        notify-send "GPU Mode: AMD WX 4150" "Log out and back in to apply primary compositor switch."
        ;;
    status)
        glxinfo | grep "OpenGL renderer"
        DRI_PRIME=1 glxinfo | grep "OpenGL renderer"
        ;;
    *)
        CHOICE=$(printf "Run App on AMD WX 4150\nSwitch Primary GPU to Intel (Battery)\nSwitch Primary GPU to AMD WX 4150 (Performance)\nCheck Active GPUs" | rofi -dmenu -p "GPU Switcher")
        case "$CHOICE" in
            *"Run App"*) APP=$(rofi -show drun -run-command "echo {cmd}"); [ -n "$APP" ] && DRI_PRIME=1 exec $APP ;;
            *"Intel"*) "$0" intel ;;
            *"AMD WX 4150"*) "$0" amd ;;
            *"Check Active"*) kitty -e bash -c '"$HOME/.local/bin/gpu-switch.sh" status; read -p "Press Enter..."' ;;
        esac
        ;;
esac
