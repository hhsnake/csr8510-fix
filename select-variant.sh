#!/bin/sh
# DKMS PRE_BUILD hook: pick the btusb source variant matching the target
# kernel and copy it into the build root, where the kbuild Makefile
# (obj-m := btusb.o) expects it.
#
# Variants (each is the full patched drivers/bluetooth/btusb.c of that
# kernel series plus the local headers it includes):
#   src/5.15  - kernels < 5.19     (tested on 5.15.0-185-generic)
#   src/5.19  - kernels 5.19..6.1  (tested on 5.19.0-50-generic)
#   src/6.2   - kernels 6.2..6.4   (tested on 6.2.0-39-generic)
#   src/6.5   - kernels 6.5..6.7   (tested on 6.5.0-45-generic)
#   src/6.8   - kernels 6.8..6.10  (tested on 6.8.0-94/134-generic)
#   src/6.11  - kernels 6.11..6.13 (tested on 6.11.0-29-generic;
#                                   6.11.4-301.fc41)
#   src/6.14  - kernels 6.14..6.16 (tested on 6.14.0-37-generic; these
#                                   Ubuntu/stable trees backported the
#                                   quirk_flags API and removed cmd_timeout)
#   src/6.17  - kernels >= 6.17    (tested on 6.17.0-35-generic,
#                                   7.0.0-14-generic; 6.17.10-100.fc41,
#                                   6.19.10-300.fc44, 7.1.4-200.fc44)
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
        echo "csr8510-fix: cannot parse kernel version '$kv'" >&2
        exit 1
        ;;
esac

n=$((maj * 100 + min))

if   [ "$n" -ge 617 ]; then variant=6.17
elif [ "$n" -ge 614 ]; then variant=6.14
elif [ "$n" -ge 611 ]; then variant=6.11
elif [ "$n" -ge 608 ]; then variant=6.8
elif [ "$n" -ge 605 ]; then variant=6.5
elif [ "$n" -ge 602 ]; then variant=6.2
elif [ "$n" -ge 519 ]; then variant=5.19
else                        variant=5.15
fi

# Versions the variants were actually built and run against.
case "$n" in
    515|519|602|605|608|611|614|617|619|700|701) tested=yes ;;
    *)                                            tested=no  ;;
esac

echo "csr8510-fix: kernel $kv -> source variant src/$variant"
if [ "$tested" = no ]; then
    echo "csr8510-fix: note: kernel series $maj.$min is untested with this" \
         "package; using the nearest variant. If the build fails, please" \
         "open an issue at https://github.com/hhsnake/csr8510-fix" >&2
fi
if [ "$n" -lt 515 ]; then
    echo "csr8510-fix: warning: kernels older than 5.15 were never targeted" \
         "and will likely fail to build." >&2
fi

srcdir="$(dirname "$0")/src/$variant"
cp -f "$srcdir"/*.c "$srcdir"/*.h "$(dirname "$0")/"
