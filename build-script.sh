#!/usr/bin/env bash
set -euo pipefail

: "${UPSTREAM_SHA:?}"
UPSTREAM="${UPSTREAM:-https://git.sr.ht/~xerool/fennel-ls}"
FENNEL_VER="${FENNEL_VER:-1.6.1}"
KEYID=9D13D9426A0814B3373CF5E3D8A8243577A7859F
out="${1:-fennel-ls}"

base="https://fennel-lang.org/downloads/fennel-${FENNEL_VER}-x86_64"
curl -fsSL -o fennel "$base"
curl -fsSL -o fennel.asc "$base.asc"
curl -fsSL "https://technomancy.us/${KEYID}.txt" | gpg --batch --import -
sig_keyid=$(gpg --batch --status-fd 1 --verify fennel.asc fennel 2>/dev/null \
	| awk '/VALIDSIG/ { print $3; exit }')
[ "$sig_keyid" = "$KEYID" ] || { echo "unexpected signer: ${sig_keyid:-none}" >&2; exit 1; }
chmod +x fennel

git clone "$UPSTREAM" src
git -C src checkout --detach "$UPSTREAM_SHA"
make -C src FENNEL="$PWD/fennel"
cp src/fennel-ls "$out"
