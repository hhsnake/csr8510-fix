#!/bin/bash
# Remove the csr8510-fix DKMS package and return to the stock kernel driver.
#
# Usage: sudo ./uninstall.sh
set -euo pipefail

PACKAGE=csr8510-fix
ORIG_BASE=/var/lib/dkms/$PACKAGE/original_module

msg()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root: sudo ./uninstall.sh"

KERNELS=()          # kernels whose module tree we touched; each needs a depmod
note_kernel() {
    local k
    for k in ${KERNELS[@]+"${KERNELS[@]}"}; do [ "$k" = "$1" ] && return 0; done
    KERNELS+=("$1")
}

# --- collect DKMS state --------------------------------------------------
# Capture the output once instead of piping dkms into a reader. `grep -q`
# exits on the first match; dkms then takes SIGPIPE while writing the second
# line (a second kernel), and `set -o pipefail` reports the whole pipeline as
# failed. That made this script take the "nothing is registered" branch and
# delete the sources while DKMS still held the original modules, leaving the
# machine with no btusb at all.
STATUS=$(dkms status "$PACKAGE" 2>/dev/null || true)
VERSIONS=$(printf '%s\n' "$STATUS" |
           sed -n "s|^$PACKAGE[/,] *\([^,: ]*\).*|\1|p" | sort -u)

# --- hand the module tree back to DKMS -----------------------------------
stuck=0
for ver in $VERSIONS; do
    msg "Removing $PACKAGE/$ver from DKMS"
    if dkms remove -m "$PACKAGE" -v "$ver" --all; then
        rm -rf "/usr/src/$PACKAGE-$ver"
    else
        # DKMS cannot put the stock modules back - most often because an
        # earlier run deleted /usr/src while the package was still
        # registered. Restore them from its archive further down instead.
        warn "dkms remove failed for $ver; restoring the stock modules by hand"
        stuck=1
    fi
done

[ -n "$VERSIONS" ] || msg "No $PACKAGE package registered with DKMS"

# --- restore anything DKMS archived but did not put back ------------------
# Also repairs a machine left broken by an earlier run of this script.
if [ -d "$ORIG_BASE" ]; then
    while IFS= read -r origin; do
        dest=$(cat "$origin")
        [ -n "$dest" ] || continue
        src=${origin%.origin}
        kver=${origin#"$ORIG_BASE"/}; kver=${kver%%/*}
        if [ -e "$dest" ]; then
            rm -f "$src" "$origin"
            continue
        fi
        msg "Restoring stock module for $kver"
        mkdir -p "$(dirname "$dest")"
        cp -a "$src" "$dest"
        rm -f "$src" "$origin"
        note_kernel "$kver"
    done < <(find "$ORIG_BASE" -name '*.origin' 2>/dev/null)
    find "$ORIG_BASE" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    rmdir "$ORIG_BASE" 2>/dev/null || true
fi

# Nothing of value is left in the DKMS tree once the archive above is empty,
# so drop the registration that dkms itself refused to remove. Leaving it
# would keep `dkms status` reporting "broken" and block a later install.
if [ "$stuck" -eq 1 ]; then
    msg "Dropping the stale DKMS registration"
    rm -rf "/var/lib/dkms/$PACKAGE"
    for ver in $VERSIONS; do rm -rf "/usr/src/$PACKAGE-$ver"; done
fi

# --- remove leftover module files DKMS might have missed ------------------
for dir in /lib/modules/*/updates/dkms; do
    [ -d "$dir" ] || continue
    kver=${dir#/lib/modules/}; kver=${kver%%/*}
    found=$(find "$dir" -maxdepth 1 -name 'btusb.ko*' 2>/dev/null)
    [ -n "$found" ] || continue
    msg "Removing leftover $dir/btusb.ko*"
    find "$dir" -maxdepth 1 -name 'btusb.ko*' -delete
    note_kernel "$kver"
done

# --- refresh module maps, per kernel -------------------------------------
# `depmod -a` only covers the running kernel; every kernel we touched needs
# its own run or its modules.dep keeps a dangling updates/dkms entry.
note_kernel "$(uname -r)"
msg "Refreshing module maps"
for kver in "${KERNELS[@]}"; do
    [ -d "/lib/modules/$kver" ] || continue
    depmod "$kver" || warn "depmod $kver failed"
done

# --- verify every kernel can still resolve btusb --------------------------
failed=0
for kver in "${KERNELS[@]}"; do
    [ -d "/lib/modules/$kver" ] || continue
    if path=$(modinfo -k "$kver" -F filename btusb 2>/dev/null) && [ -n "$path" ]; then
        printf '    %s -> %s\n' "$kver" "$path"
    else
        warn "$kver has no btusb module at all"
        failed=1
    fi
done
[ "$failed" -eq 0 ] || die "stock btusb is missing; do not reboot before fixing this"

# --- reload the stock driver ---------------------------------------------
msg "Reloading stock btusb"
if ! modprobe -r btusb 2>/dev/null; then
    warn "could not unload btusb (in use?); the patched module stays live until reboot"
fi
modprobe btusb || warn "modprobe btusb failed - check 'journalctl -k'"

# Compare what is in memory with what is on disk: modinfo alone would report
# the on-disk file and call a still-resident patched module a success.
echo
disk=$(modinfo -F srcversion btusb 2>/dev/null || true)
live=$(cat /sys/module/btusb/srcversion 2>/dev/null || true)
msg "Done. On disk: $(modinfo -F filename btusb 2>/dev/null || echo '(missing)')"
if [ -z "$live" ]; then
    echo "    btusb is not loaded"
elif [ "$live" = "$disk" ]; then
    echo "    loaded module matches the stock one on disk"
else
    warn "the module in memory ($live) is not the one on disk ($disk)"
    warn "unplug the dongle and reload, or reboot, to drop the patched module"
fi
