#!/usr/bin/env bash
# Current weather for the bar. Prints "weatherCode|tempF|description" and
# nothing else. The location is pinned to Louisville, KY instead of letting
# wttr.in geolocate by public address, and `u` forces US customary units so the
# chip reads in Fahrenheit.
set -u

json=$(curl -s --max-time 12 'https://wttr.in/Louisville,KY?format=j1&u' 2>/dev/null)
[ -z "$json" ] && exit 1

printf '%s\n' "$json" | jq -r '
    .["current_condition"][0]
    | "\(.weatherCode)|\(.temp_F)|\(.weatherDesc[0].value)"' 2>/dev/null
