#!/bin/sh
# Super+M — toggle the default microphone, then say which way it went.
# wpctl keeps the state, so this survives a relogin like any other source mute.
report() {
    printf '%s\n' "$1"
    if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && command -v notify-send >/dev/null 2>&1; then
        notify-send -a Microphone -t 2000 "$1" >/dev/null 2>&1 || true
    fi
}

if ! wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle >/dev/null 2>&1; then
    printf 'mic-toggle: no default audio source\n' >&2
    exit 1
fi

if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
    report "Microphone muted"
else
    report "Microphone live"
fi
