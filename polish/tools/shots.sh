#!/usr/bin/env bash
# Usage: polish/tools/shots.sh <out-dir> [test-name-regex]
# Runs integration_test/polish_shots_test.dart on the emulator and saves
# `adb screencap` for every POLISH_SHOT mark.
set -u
OUT=$(realpath "$1"); NAME=${2:-}
DEV=${DEV:-emulator-5554}
export PATH=$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH
cd "$(dirname "$0")/../../app"
mkdir -p "$OUT"
adb -s $DEV reverse tcp:8080 tcp:8080 >/dev/null
adb -s $DEV logcat -c
adb -s $DEV logcat -v raw -s flutter:I | while read -r l; do
  case "$l" in *POLISH_SHOT*) n=${l##*POLISH_SHOT }; n=${n%$'\r'}; adb -s $DEV exec-out screencap -p > "$OUT/$n.png"; echo "shot $n";; esac
done &
READER=$!
flutter test integration_test/polish_shots_test.dart -d $DEV --dart-define=LLM=host ${NAME:+--plain-name "$NAME"} 2>&1 | grep -E "^[0-9:+ -]+.*(passed|failed|Some tests|All tests)|EXCEPTION|Expected|Error" | tail -15
sleep 3; kill $READER 2>/dev/null; pkill -P $READER 2>/dev/null
ls "$OUT"
