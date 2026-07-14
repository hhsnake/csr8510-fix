#!/bin/sh
# DKMS PRE_BUILD hook: pick the btusb source variant matching the target
# kernel and copy it into the build root, where the kbuild Makefile
# (obj-m := btusb.o) expects it.
#
# Variants (each is the full patched drivers/bluetooth/btusb.c of that
# kernel series plus the local headers it includes):
#   src/6.8   - kernels < 6.11   (tested on 6.8.0-94-generic)
#   src/6.11  - kernels 6.11..6.16 (tested on 6.11.0-29-generic)
#   src/6.17  - kernels >= 6.17  (tested on 6.17.0-35-generic and
#                                 7.0.0-14-generic)
#
# Usage: select-variant.sh [kernelver]
# Runs from the build/source root (DKMS runs PRE_BUILD there).

set -e

kv="${1:-$(uname -r)}"
base="${kv%%-*}"                 # e.g. 6.11.0-29-generic -> 6.11.0
maj="${base%%.*}"
rest="${base#*.}"
min="${rest%%.*}"

case "$maj$min" in
    *[!0-9]*|'')
        echo "btusb-csr: cannot parse kernel version '$kv'" >&2
        exit 1
        ;;
esac

n=$((maj * 100 + min))

if   [ "$n" -ge 617 ]; then variant=6.17
elif [ "$n" -ge 611 ]; then variant=6.11
else                        variant=6.8
fi

# Versions the variants were actually built and run against.
case "$n" in
    608|611|617|700) tested=yes ;;
    *)               tested=no  ;;
esac

echo "btusb-csr: kernel $kv -> source variant src/$variant"
if [ "$tested" = no ]; then
    echo "btusb-csr: note: kernel series $maj.$min is untested with this" \
         "package; using the nearest variant. If the build fails, please" \
         "open an issue at https://github.com/hhsnake/csr-dongle-fix" >&2
fi
if [ "$n" -lt 608 ]; then
    echo "btusb-csr: warning: kernels older than 6.8 were never targeted" \
         "and will likely fail to build." >&2
fi

srcdir="$(dirname "$0")/src/$variant"
cp -f "$srcdir"/*.c "$srcdir"/*.h "$(dirname "$0")/"
