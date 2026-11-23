#!/usr/bin/env bash
# Toggle mute on the default PipeWire source. Same action as the bar's Mic chip
# and the SUPER+M bind.
set -u

wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED; then
    notify-send -u low "Microphone" "Muted"
else
    notify-send -u low "Microphone" "Live"
fi
