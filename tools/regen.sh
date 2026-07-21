#!/bin/bash
# Regenerate src/<variant>/ from provenance/<variant>.manifest:
#   pristine kernel files (verified by sha256) + our patch.
#
# Usage: tools/regen.sh <variant> [dest_dir]
#   dest_dir defaults to src/<variant>. Set KERNEL_GIT=/path/to/linux(.git)
#   to pull files from a local clone instead of the network.
set -euo pipefail

V=${1:?usage: regen.sh <variant> [dest_dir]}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MAN="$ROOT/provenance/$V.manifest"
[ -f "$MAN" ] || { echo "no manifest: $MAN" >&2; exit 1; }

commit=$(awk '$1=="commit"{print $2}' "$MAN")
patch=$(awk '$1=="patch"{print $2}' "$MAN")
mapfile -t mirrors < <(awk '$1=="mirror"{print $2}' "$MAN")

DEST=${2:-$ROOT/src/$V}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fetch() { # $1=kernel path -> file content on stdout
    local path=$1 url out
    if [ -n "${KERNEL_GIT:-}" ] && \
       git -C "$KERNEL_GIT" cat-file -e "$commit:$path" 2>/dev/null; then
        git -C "$KERNEL_GIT" show "$commit:$path"; return 0
    fi
    for m in "${mirrors[@]}"; do
        url=${m//\{commit\}/$commit}; url=${url//\{path\}/$path}
        if out=$(curl -fsSL "$url" 2>/dev/null); then printf '%s' "$out"; return 0; fi
    done
    return 1
}

mkdir -p "$DEST"
while read -r _ sha path dest apply; do
    [ -n "${sha:-}" ] || continue
    fetch "$path" > "$work/$dest" || { echo "fetch failed: $path" >&2; exit 1; }
    got=$(sha256sum "$work/$dest" | cut -d' ' -f1)
    [ "$got" = "$sha" ] || {
        echo "sha256 mismatch for $path" >&2
        echo "  want $sha" >&2; echo "  got  $got" >&2; exit 1; }
    [ "$apply" = yes ] && patch -s "$work/$dest" < "$ROOT/$patch"
    cp "$work/$dest" "$DEST/$dest"
    echo "  ok  $dest${apply:+ ($apply patch)}"
done < <(awk '$1=="file"{print}' "$MAN")

echo "regenerated $DEST from $MAN"
