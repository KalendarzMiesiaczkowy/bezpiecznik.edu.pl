#!/usr/bin/env bash
# Usage: [DEV=emulator-XXXX] polish/tools/gallery-shots.sh <out-dir> [file-prefix]
# Runs app/integration_test/polish_gallery_test.dart and saves `adb screencap`
# for every `POLISH_SHOT <name>` line (same mechanism as shots.sh).
set -u
OUT=$(realpath -m "$1"); PRE=${2:-}
DEV=${DEV:-emulator-5556}
export PATH=$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH
cd "$(dirname "$0")/../../app"
mkdir -p "$OUT"
flutter test integration_test/polish_gallery_test.dart -d "$DEV" 2>&1 |
while IFS= read -r l; do
  case "$l" in
    *POLISH_SHOT*) n=${l##*POLISH_SHOT }; n=${n%$'\r'}; adb -s "$DEV" exec-out screencap -p > "$OUT/$PRE$n.png"; echo "shot $n" ;;
    *"tests passed"*|*"Some tests failed"*|*EXCEPTION*|*Expected:*|*Actual:*) echo "$l" ;;
  esac
done
