#!/bin/sh
# protonvpn-enable.sh - store your Proton VPN account on this machine.
#
# The account is written to ~/.config/protonvpn/credentials (mode 600) and is
# deliberately NOT part of the dotfiles repo: the repo ships this script, never
# your email or password. Add the file to .gitignore work is already done.
#
#   protonvpn-enable.sh             prompt for email and password, store them
#   protonvpn-enable.sh --login     store them, then sign the app in
#   protonvpn-enable.sh --forget    delete the stored credentials
#   protonvpn-enable.sh --show      report whether details exist (no secrets)
#
# Non-interactive use (what the installer does) keeps the password off the
# command line and out of shell history:
#
#   PROTONVPN_USER=you@example.com printf '%s\n' "$PASS" | protonvpn-enable.sh --no-login
set -eu
umask 077

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/protonvpn"
CREDS="$CONF_DIR/credentials"

usage() {
    sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

case "${1:-}" in
    -h|--help) usage 0 ;;
    --forget)
        rm -f "$CREDS"
        printf 'removed %s\n' "${CREDS#"$HOME"/}"
        exit 0
        ;;
    --show)
        if [ -s "$CREDS" ]; then
            printf 'credentials: %s (%s)\n' "${CREDS#"$HOME"/}" "$(stat -c '%a %U' "$CREDS")"
            printf 'email       : %s\n' "$(awk -F= '$1=="user"{print $2; exit}' "$CREDS")"
        else
            printf 'credentials: none stored\n'
        fi
        exit 0
        ;;
    --login|--no-login|"") ;;
    *) printf 'protonvpn-enable: unknown argument: %s (try --help)\n' "$1" >&2; exit 1 ;;
esac
LOGIN=0
[ "${1:-}" = --login ] && LOGIN=1

# ------------------------------------------------------------- collect details
USER_NAME="${PROTONVPN_USER:-}"
if [ -z "$USER_NAME" ]; then
    printf 'Proton account email: '
    IFS= read -r USER_NAME
fi
[ -n "$USER_NAME" ] || { printf 'protonvpn-enable: no email given\n' >&2; exit 1; }

if [ -t 0 ] && [ -z "${PROTONVPN_PASS:-}" ]; then
    printf 'Proton password (not echoed): '
    stty -echo
    IFS= read -r PASSWORD
    stty echo
    printf '\n'
else
    # Piped on stdin: one line, no prompt.
    IFS= read -r PASSWORD || true
    PASSWORD="${PROTONVPN_PASS:-$PASSWORD}"
fi
[ -n "${PASSWORD:-}" ] || { printf 'protonvpn-enable: no password given\n' >&2; exit 1; }

mkdir -p "$CONF_DIR"
chmod 700 "$CONF_DIR"
printf 'user=%s\npassword=%s\n' "$USER_NAME" "$PASSWORD" >"$CREDS"
unset PASSWORD
chmod 600 "$CREDS"

printf 'stored %s (%s, %s)\n' "${CREDS#"$HOME"/}" \
    "$(stat -c %a "$CREDS")" "$(stat -c %U "$CREDS")"
printf 'email: %s\n' "$USER_NAME"

# ------------------------------------------------------------------- sign in
# The app keeps its session in the OS keyring, so a first sign-in is normally
# interactive. Where the packaged CLI can do it, do it here.
if [ "$LOGIN" -eq 1 ]; then
    if command -v protonvpn >/dev/null 2>&1 && protonvpn --help 2>&1 | grep -qi signin; then
        protonvpn signin
    else
        printf '\nSign in once with the app (it stores the session in the keyring):\n'
        printf '  protonvpn-app        # or the "Proton VPN" entry in your launcher\n'
        printf 'After that this machine connects headless with:\n'
        printf '  ~/.local/bin/protonvpn-toggle.sh\n'
    fi
fi
