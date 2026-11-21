#!/usr/bin/env bash
# Usage: polish/tools/render.sh <out.png> [text-scale]
# Renders the whole debug gallery on the host with `flutter test` (seconds, no emulator).
set -eu
OUT=$(realpath -m "$1"); mkdir -p "$(dirname "$OUT")"
cd "$(dirname "$0")/../../app"
T=test/zz_polish_gallery_render_test.dart
cp ../polish/tools/gallery_render_test.dart $T
trap 'rm -f $T' EXIT
LUCIDE_TTF=$(ls ~/.pub-cache/hosted/pub.dev/lucide_icons_flutter-*/assets/lucide.ttf | tail -1) \
POLISH_OUT="$OUT" POLISH_SCALE="${2:-1}" ~/development/flutter/bin/flutter test $T 2>&1 | tail -4
