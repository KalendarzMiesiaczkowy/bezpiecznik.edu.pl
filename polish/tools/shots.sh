#!/usr/bin/env bash
# Usage: [DEV=emulator-XXXX] polish/tools/shots.sh <out-dir> [test-name]
# Runs app/integration_test/polish_shots_test.dart and saves `adb screencap`
# for every `POLISH_SHOT <name>` line the test prints.
set -u
OUT=$(realpath -m "$1"); NAME=${2:-}
DEV=${DEV:-emulator-5554}
export PATH=$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH
cd "$(dirname "$0")/../../app"
mkdir -p "$OUT"
adb -s "$DEV" reverse tcp:8080 tcp:8080 >/dev/null
flutter test integration_test/polish_shots_test.dart -d "$DEV" --dart-define=LLM=host ${NAME:+--plain-name "$NAME"} 2>&1 |
while IFS= read -r l; do
  case "$l" in
    *POLISH_SHOT*) n=${l##*POLISH_SHOT }; n=${n%$'\r'}; adb -s "$DEV" exec-out screencap -p > "$OUT/$n.png"; echo "shot $n" ;;
    *"tests passed"*|*"Some tests failed"*|*EXCEPTION*|*Expected:*|*Actual:*) echo "$l" ;;
  esac
done
