#!/bin/bash
# Remove the btusb-csr DKMS package and return to the stock kernel driver.
#
# Usage: sudo ./uninstall.sh
set -euo pipefail

PACKAGE=btusb-csr

msg() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo ./uninstall.sh"

if dkms status "$PACKAGE" 2>/dev/null | grep -q "$PACKAGE"; then
    dkms status "$PACKAGE" | sed -n "s|^$PACKAGE[/,] *\([^,: ]*\).*|\1|p" | sort -u | \
    while read -r ver; do
        [ -n "$ver" ] || continue
        msg "Removing $PACKAGE/$ver from DKMS"
        dkms remove -m "$PACKAGE" -v "$ver" --all || true
        rm -rf "/usr/src/$PACKAGE-$ver"
    done
else
    msg "No $PACKAGE package registered with DKMS"
    rm -rf /usr/src/$PACKAGE-*
fi

# Remove any leftover module files DKMS might have missed
find /lib/modules/*/updates/dkms -maxdepth 1 -name 'btusb.ko*' -delete 2>/dev/null || true

msg "Refreshing module maps"
depmod -a

msg "Reloading stock btusb"
modprobe -r btusb 2>/dev/null || true
modprobe btusb || true

echo
msg "Done. Now loaded: $(modinfo -F filename btusb 2>/dev/null || echo '(not loaded)')"
