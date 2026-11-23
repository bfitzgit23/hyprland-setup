#!/usr/bin/env bash
# Turn fingerprint auth on for login/sudo/su, once at least one finger is
# enrolled. Kept separate from the driver install because pam_fprintd in
# system-auth is only safe to add when the stack has something to succeed
# with; with no prints it can only add delay.
#
#   fprintd-enroll          # first: press/lift the finger several times
#   sudo fprint-enable.sh   # then: wire it into PAM
set -u

PAM=/etc/pam.d/system-auth
BACKUP="$PAM.bak-fprint"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root (sudo $0)." >&2
    exit 1
fi

if ! ls /lib*/security/pam_fprintd.so >/dev/null 2>&1; then
    echo "pam_fprintd.so is missing - install sys-auth/fprintd." >&2
    exit 1
fi

listing=$(fprintd-list "${SUDO_USER:-bennji}" 2>&1)
case "$listing" in
    *"has 1 finger"*|*"fingers enrolled"*) ;;
    *)
        echo "No enrolled fingers yet:" >&2
        printf '%s\n' "$listing" >&2
        echo "Run 'fprintd-enroll' first, then retry." >&2
        exit 1
        ;;
esac

if grep -q 'pam_fprintd' "$PAM"; then
    echo "Fingerprint auth already present in $PAM."
    exit 0
fi

cp -a "$PAM" "$BACKUP"
python3 - "$PAM" <<'PY'
import sys

path = sys.argv[1]
lines = open(path).read().splitlines(keepends=True)
out = []
inserted = False
for line in lines:
    if not inserted and "pam_unix.so" in line and line.lstrip().startswith("auth"):
        # Enough for one finger press; falls straight through to the password
        # when the reader is busy, missing or reports no-match.
        out.append("auth\t\tsufficient\tpam_fprintd.so max-tries=1 timeout=10\n")
        inserted = True
    out.append(line)
if not inserted:
    sys.exit("could not find the pam_unix auth line")
open(path, "w").writelines(out)
PY

echo "Enabled. Backup kept at $BACKUP."
grep -n 'pam_fprintd\|pam_unix' "$PAM"
echo
echo "Password still works if the reader fails: pam_fprintd is 'sufficient',"
echo "so the stack continues to pam_unix. Revert with:"
echo "  cp -a $BACKUP $PAM"
