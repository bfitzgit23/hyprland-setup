#!/bin/sh
# protonvpn-toggle.sh - bring the Proton VPN tunnel up or down.
#
#   protonvpn-toggle.sh            connect if down, disconnect if up
#   protonvpn-toggle.sh status     print "on <interface>" or "off"
#   protonvpn-toggle.sh connect    connect (fastest server)
#   protonvpn-toggle.sh disconnect disconnect
#
# The bar's VPN chip calls this. The app's CLI is used when it is installed;
# otherwise a NetworkManager VPN profile named like a Proton connection is
# brought up, so an imported .ovpn or .conf keeps working too.
set -eu

CREDS="${XDG_CONFIG_HOME:-$HOME/.config}/protonvpn/credentials"

# A Proton tunnel shows up as proton0/wg0/tun0, or as an active NM VPN profile.
current() {
    IFACE=$(ip -br link 2>/dev/null | awk '$1 ~ /^(proton|tun|wg)[0-9]+/ {print $1; exit}')
    if [ -n "${IFACE:-}" ]; then
        printf 'on %s\n' "$IFACE"
        return 0
    fi
    NM=$(nmcli -t -f TYPE,NAME con show --active 2>/dev/null |
         awk -F: '$1 ~ /vpn/ {print $2; exit}')
    if [ -n "${NM:-}" ]; then
        printf 'on %s\n' "$NM"
        return 0
    fi
    printf 'off\n'
}

MODE="${1:-toggle}"
case "$MODE" in
    status) current; exit 0 ;;
    connect|disconnect|toggle) ;;
    *) printf 'protonvpn-toggle: unknown argument: %s\n' "$MODE" >&2; exit 1 ;;
esac

UP=0
current | grep -q '^on ' && UP=1

if [ "$MODE" = toggle ]; then
    [ "$UP" -eq 1 ] && MODE=disconnect || MODE=connect
fi

if [ "$MODE" = connect ] && [ ! -s "$CREDS" ]; then
    printf 'protonvpn-toggle: no stored account - run protonvpn-enable.sh first\n' >&2
    exit 1
fi

# Prefer the packaged app CLI; it handles server selection and the keyring.
if command -v protonvpn >/dev/null 2>&1 && protonvpn --help 2>&1 | grep -qiE 'connect'; then
    exec protonvpn "$MODE" --non-interactive 2>/dev/null ||
        exec protonvpn "$MODE"
fi

# Fallback: a NetworkManager VPN profile (imported .ovpn or WireGuard config).
NM_NAME=$(nmcli -t -f TYPE,NAME con show 2>/dev/null | awk -F: '$1 ~ /vpn/ {print $2; exit}')
if [ -n "${NM_NAME:-}" ]; then
    if [ "$MODE" = connect ]; then
        exec nmcli connection up "$NM_NAME"
    fi
    exec nmcli connection down "$NM_NAME"
fi

printf 'protonvpn-toggle: no Proton client and no VPN profile found\n' >&2
printf '  install net-vpn/proton-vpn-gtk-app, or import a profile with:\n' >&2
printf '  nmcli connection import type openvpn file your-config.ovpn\n' >&2
exit 1
