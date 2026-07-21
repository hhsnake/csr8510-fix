#!/bin/bash
# Prove src/<variant>/ equals "pristine kernel files + our patch" as pinned in
# provenance/<variant>.manifest. Exits non-zero (and prints the diff) if the
# committed source contains anything not derivable from the manifest + patch.
#
# Usage: tools/verify.sh <variant>   (honours KERNEL_GIT like regen.sh)
set -euo pipefail

V=${1:?usage: verify.sh <variant>}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

"$ROOT/tools/regen.sh" "$V" "$tmp" >/dev/null

if diff -ru "$ROOT/src/$V" "$tmp"; then
    echo "OK: src/$V matches provenance/$V.manifest + patch"
else
    echo "MISMATCH: src/$V is not reproducible from the manifest + patch" >&2
    exit 1
fi
