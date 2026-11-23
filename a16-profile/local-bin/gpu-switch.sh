#!/usr/bin/env bash
# The A16 has no mux switch: Intel renders the desktop, the RTX 5060 is a PRIME
# render-offload target. So this is not a switcher but a launcher/report, which
# is what the bar's GPU chip and SUPER+G call.
set -u

driver=$(cat /sys/module/nvidia/version 2>/dev/null || echo "not loaded")
choice=$(printf 'Run a command on the RTX 5060\nGPU status' | \
         rofi -dmenu -i -p "GPU: NVIDIA $driver")

case "$choice" in
    "Run a command"*)
        cmd=$(rofi -dmenu -p "command" </dev/null)
        [ -n "${cmd:-}" ] || exit 0
        setsid sh -c "__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia $cmd" \
            >/dev/null 2>&1 &
        ;;
    "GPU status")
        kitty -e sh -c '
            echo "== NVIDIA =="; nvidia-smi 2>/dev/null || echo "nvidia-smi unavailable"
            echo; echo "== renderer =="
            glxinfo -B 2>/dev/null | grep -E "OpenGL renderer|OpenGL vendor" || echo "glxinfo missing"
            echo; read -r -p "press enter to close" _
        '
        ;;
esac
