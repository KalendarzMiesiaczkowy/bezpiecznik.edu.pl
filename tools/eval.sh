#!/usr/bin/env bash
# Runs the A07 eval against the host llama-server (127.0.0.1:8080).
# Usage: tools/eval.sh [--no-llm]
set -euo pipefail
source /home/weak/Dokumenty/bezpiecznik/Bezpiecznik/night-shift/bin/env.sh
cd "$(dirname "$0")/../app"
export BZ_EVAL=1
[ "${1:-}" = "--no-llm" ] && export BZ_EVAL_LLM=0
flutter test test/eval/eval_test.dart --reporter expanded
