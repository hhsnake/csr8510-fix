#!/bin/sh
# DKMS POST_INSTALL hook. DKMS 2.8.x (Ubuntu 22.04) sometimes reports a
# module "installed" for a non-running kernel while actually copying nothing
# into /lib/modules; place the module into updates/dkms explicitly and
# refresh depmod. On DKMS 3.x this is a harmless duplicate copy.
#
# Args: $1 = kernelver, $2 = arch. Runs from the DKMS build tree, so the
# package tree root is one level up from this script.
set -e

kver="$1"
arch="$2"
[ -n "$kver" ] && [ -n "$arch" ] || exit 0

tree="$(cd "$(dirname "$0")/.." && pwd)"
src="$tree/$kver/$arch/module"
dst="/lib/modules/$kver/updates/dkms"

[ -d "$src" ] || exit 0
mkdir -p "$dst"
cp -f "$src"/btusb.ko* "$dst"/
depmod "$kver"
