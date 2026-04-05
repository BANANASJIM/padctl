#!/usr/bin/env bash
# build-deb.sh — build a binary .deb from a padctl GitHub release tarball.
#
# Usage: ./build-deb.sh [VERSION]
# Example: ./build-deb.sh 0.1.0
#
# TODO: update VERSION and ARCH before use; set sha256 check once release tarballs exist.

set -euo pipefail

VERSION="${1:-0.1.0}"
ARCH="$(dpkg --print-architecture)"  # amd64 or arm64

case "$ARCH" in
    amd64) MUSL_ARCH="x86_64-linux-musl" ;;
    arm64) MUSL_ARCH="aarch64-linux-musl" ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

TARBALL="padctl-v${VERSION}-${MUSL_ARCH}.tar.gz"
# TODO: update URL once release tarballs exist
URL="https://github.com/BANANASJIM/padctl/releases/download/v${VERSION}/${TARBALL}"

PKG="padctl_${VERSION}_${ARCH}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "Downloading $URL ..."
curl -fL "$URL" -o "$WORKDIR/$TARBALL"

tar -xzf "$WORKDIR/$TARBALL" -C "$WORKDIR"
SRC="$WORKDIR/padctl-v${VERSION}-${MUSL_ARCH}"

DEST="$WORKDIR/$PKG"
mkdir -p "$DEST/DEBIAN"

# Copy DEBIAN control scripts from this directory
for f in control postinst prerm postrm; do
    cp "$(dirname "$0")/$f" "$DEST/DEBIAN/$f"
done
chmod 0644 "$DEST/DEBIAN/control"
chmod 0755 "$DEST/DEBIAN/postinst" "$DEST/DEBIAN/prerm" "$DEST/DEBIAN/postrm"
# Patch version in control
sed -i "s/^Version:.*/Version: $VERSION/" "$DEST/DEBIAN/control"
sed -i "s/^Architecture:.*/Architecture: $ARCH/" "$DEST/DEBIAN/control"

# Run padctl install into dest tree
"$SRC/bin/padctl" install --destdir "$DEST" --prefix /usr

# License (Debian policy §12.5)
install -Dm644 "$SRC/LICENSE" "$DEST/usr/share/doc/padctl/copyright"

dpkg-deb --build --root-owner-group "$DEST" "${PKG}.deb"
echo "Built: ${PKG}.deb"
