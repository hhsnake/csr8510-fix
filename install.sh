#!/bin/bash
# Install the patched btusb driver for fake CSR8510 A10 clones as a DKMS
# module, so it is rebuilt automatically on every kernel update.
#
# Usage: sudo ./install.sh
set -euo pipefail

PACKAGE=csr8510-fix
VERSION=$(sed -n 's/^PACKAGE_VERSION="\(.*\)"/\1/p' "$(dirname "$0")/dkms.conf")
SRC=/usr/src/$PACKAGE-$VERSION
REPO_DIR=$(cd "$(dirname "$0")" && pwd)
KVER=$(uname -r)

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo ./install.sh"

command -v dkms >/dev/null 2>&1 || \
    die "dkms is not installed. On Debian/Ubuntu: sudo apt install dkms"

[ -e "/lib/modules/$KVER/build/Makefile" ] || \
    die "kernel headers for $KVER are missing. On Debian/Ubuntu: sudo apt install linux-headers-$KVER"

# --- copy source into /usr/src -------------------------------------------
msg "Installing source to $SRC"
rm -rf "$SRC"
mkdir -p "$SRC"
cp -a "$REPO_DIR"/dkms.conf "$REPO_DIR"/Makefile "$REPO_DIR"/select-variant.sh \
      "$REPO_DIR"/src "$SRC/"
chmod +x "$SRC/select-variant.sh"

# --- (re)register with DKMS ----------------------------------------------
# Remove any previously registered version of this package so reinstalls
# and upgrades are clean.
EXISTING=$(dkms status "$PACKAGE" 2>/dev/null | \
           sed -n "s|^$PACKAGE[/,] *\([^,: ]*\).*|\1|p" | sort -u)
if [ -n "$EXISTING" ]; then
    msg "Removing previously registered $PACKAGE versions"
    for oldver in $EXISTING; do
        dkms remove -m "$PACKAGE" -v "$oldver" --all || true
    done
fi

msg "Registering and building $PACKAGE/$VERSION for kernel $KVER"
dkms add -m "$PACKAGE" -v "$VERSION"
dkms build -m "$PACKAGE" -v "$VERSION" || \
    die "build failed - see /var/lib/dkms/$PACKAGE/$VERSION/build/make.log"
dkms install -m "$PACKAGE" -v "$VERSION" --force

# --- verify the module actually landed in updates/dkms --------------------
# Older DKMS versions (e.g. 2.8.x) have occasionally been seen not to place
# the module into DEST_MODULE_LOCATION; fix it up explicitly if needed.
depmod "$KVER"
MODPATH=$(modinfo -k "$KVER" -F filename btusb 2>/dev/null || true)
if ! echo "$MODPATH" | grep -q "/updates/dkms/"; then
    warn "module did not resolve to updates/dkms ($MODPATH); copying manually"
    BUILT=/var/lib/dkms/$PACKAGE/$VERSION/$KVER/$(uname -m)/module
    mkdir -p "/lib/modules/$KVER/updates/dkms"
    cp "$BUILT"/btusb.ko* "/lib/modules/$KVER/updates/dkms/"
    depmod "$KVER"
    MODPATH=$(modinfo -k "$KVER" -F filename btusb)
    echo "$MODPATH" | grep -q "/updates/dkms/" || \
        die "module still resolves to $MODPATH - installation failed"
fi
msg "Module installed: $MODPATH"

# --- Secure Boot hint ------------------------------------------------------
if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
    if [ ! -e /var/lib/shim-signed/mok/MOK.priv ]; then
        warn "Secure Boot is enabled but no DKMS MOK signing key was found."
        warn "The module may be refused at load time. See README, section 'Secure Boot'."
    fi
fi

# --- reload the driver -----------------------------------------------------
msg "Reloading btusb (Bluetooth will briefly disconnect)"
modprobe -r btusb 2>/dev/null || warn "could not unload btusb (in use?); reboot to activate"
modprobe btusb || die "modprobe btusb failed - check 'journalctl -k'"

echo
msg "Done. Checks:"
dkms status "$PACKAGE"
echo "loaded module: $(modinfo -F filename btusb)"
echo
echo "Plug in the dongle and watch:  journalctl -kf | grep -i -e bluetooth -e csr"
