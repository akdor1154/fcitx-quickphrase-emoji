#!/usr/bin/env bash
# Build dist/fcitx5-quickphrase-emoji_<version>_all.deb with plain dpkg-deb.
#
# A binary package is just a directory holding the files at their installed
# paths plus DEBIAN/control, so no debhelper or source package is involved.
# The version comes from the VERSION file; the maintainer from git config.
set -euo pipefail

cd "$(dirname "$0")/.."

name=fcitx5-quickphrase-emoji
version=$(< VERSION)
if [[ ! $version =~ ^[0-9] ]]; then
    echo "VERSION must start with a digit, got '$version'" >&2
    exit 1
fi

root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
chmod 755 "$root"

dest=$root/usr/share/fcitx5
install -Dm644 fcitx5/addon/emojipicker.conf "$dest/addon/emojipicker.conf"
install -Dm644 -t "$dest/lua/emojipicker" fcitx5/lua/emojipicker/*.lua

mkdir -m 755 "$root/DEBIAN"
cat > "$root/DEBIAN/control" <<EOF
Package: $name
Version: $version
Architecture: all
Maintainer: $(git config user.name) <$(git config user.email)>
Depends: fcitx5, fcitx5-module-lua, unicode-data, unicode-cldr-core
Section: utils
Priority: optional
Description: emoji search mode for fcitx5 Quick Phrase
 A Lua addon that turns Quick Phrase into an emoji picker when it is opened
 with Super+E. It searches emoji names and keywords from the system's
 Unicode data. Add Super+E to Quick Phrase's trigger keys after installing.
EOF

mkdir -p dist
dpkg-deb --build --root-owner-group "$root" "dist/${name}_${version}_all.deb"
