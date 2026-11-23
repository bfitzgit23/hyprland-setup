#!/usr/bin/env bash
# System update, as run by the bar's Update chip and SUPER+U (inside kitty).
# It stops before changing USE flags silently: --ask is left on so the plan is
# visible, and the window stays open afterwards to read the result.
set -u

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "== syncing trees =="
$SUDO emaint sync -a || echo "sync reported an error, continuing"

echo
echo "== update plan =="
$SUDO emerge -avuDN @world
status=$?

echo
echo "== news =="
eselect news read --quiet new 2>/dev/null | tail -20

echo
echo "== preserved-rebuild =="
$SUDO emerge @preserved-rebuild -p 2>/dev/null | tail -5

echo
echo "exit status: ${status}"
read -r -p "press enter to close" _
