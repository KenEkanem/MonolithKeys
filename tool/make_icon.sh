#!/bin/sh
# Builds windows/runner/resources/app_icon.ico from the MonolithKeys mark:
# a tall key cap on a dark tile. Proportions match BrandMark in
# lib/ui/previews.dart. Requires ImageMagick 7 (`magick`).
set -eu
cd "$(dirname "$0")/.."
S=1024
px() { awk "BEGIN { printf \"%d\", $1 * $S }"; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
magick -size ${S}x${S} xc:none \
  -fill '#16181D' -draw "roundrectangle 0,0 $((S-1)),$((S-1)) $(px .22),$(px .22)" \
  -fill '#2F6FED' -draw "roundrectangle $(px .30),$(px .17) $(px .70),$(px .85) $(px .09),$(px .09)" \
  -fill '#F4F5F7' -draw "roundrectangle $(px .30),$(px .17) $(px .70),$(px .77) $(px .09),$(px .09)" \
  -fill '#E1E4EA' -draw "roundrectangle $(px .36),$(px .23) $(px .64),$(px .69) $(px .06),$(px .06)" \
  "$tmp/mark.png"
magick "$tmp/mark.png" -define icon:auto-resize=256,64,48,40,32,24,20,16 windows/runner/resources/app_icon.ico
echo "Wrote windows/runner/resources/app_icon.ico"
