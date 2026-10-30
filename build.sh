#!/bin/sh
# Builds the installable .plasmoid archive from package/
set -e
cd "$(dirname "$0")"
version=$(sed -n 's/.*"Version": "\(.*\)".*/\1/p' package/metadata.json)
out="ps-controller-battery-$version.plasmoid"
rm -f "$out"
(cd package && zip -qr "../$out" metadata.json contents)
echo "$out"
