#!/usr/bin/env bash
CURRENT_PROFILE=$(powerprofilesctl get 2>/dev/null || echo "unknown")

OPTIONS="Lock Screen\nSuspend\nPower Profile: Performance\nPower Profile: Balanced\nPower Profile: Power-Saver\nExit Hyprland\nReboot\nShutdown"

CHOICE=$(printf "$OPTIONS" | rofi -dmenu -i -p "Power [$CURRENT_PROFILE]")

case "$CHOICE" in
    *"Lock Screen"*) loginctl lock-session ;;
    *"Suspend"*) loginctl lock-session && loginctl suspend ;;
    *"Performance"*) powerprofilesctl set performance && notify-send "Power Profile" "Performance" ;;
    *"Balanced"*) powerprofilesctl set balanced && notify-send "Power Profile" "Balanced" ;;
    *"Power-Saver"*) powerprofilesctl set power-saver && notify-send "Power Profile" "Power Saver" ;;
    *"Exit Hyprland"*) hyprctl dispatch exit ;;
    *"Reboot"*) loginctl reboot || sudo reboot ;;
    *"Shutdown"*) loginctl poweroff || sudo poweroff ;;
esac
