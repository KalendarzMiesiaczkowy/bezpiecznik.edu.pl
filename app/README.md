# Bezpiecznik (Flutter app)

Offline crisis assistant. Product and build specification: `../bezpiecznik/`.

## What is in the APK and what is downloaded

| Data | Where | Built by |
|---|---|---|
| Knowledge base `assets/generated/kb.sqlite` | in the APK | `uv run --script tools/build_knowledge.py` |
| Shelter points `assets/generated/points.sqlite` | in the APK | `uv run --script tools/build_points.py` (needs the OSM extract) |
| Map tiles `zachodniopomorskie.mbtiles` (~100 MB) | downloaded by the app | `tools/build_tiles.sh` (Planetiler) |
| Model `gemma-4-E2B-it.litertlm` (2.6 GB) | downloaded by the app | Hugging Face `litert-community/gemma-4-E2B-it-litert-lm` |

`assets/generated/` is git-ignored. The Android build fails when `kb.sqlite`
or `points.sqlite` is missing (check in `android/app/build.gradle.kts`): an
APK without them installs but answers nothing.

The two heavy files are downloaded on first start (`lib/paczki/`), in the
background while the user goes through onboarding, with resume, a size check
and (for the map) a SHA-256 check. Only on Wi-Fi unless the user allows
mobile data. They land in `<app support dir>/paczki/`.

## Build

```
flutter build apk --release \
  --dart-define=MAP_PACK_URL=https://bezpiecznik.edu.pl/paczki/zachodniopomorskie.mbtiles \
  --dart-define=MAP_PACK_BYTES=<size of the mbtiles in bytes> \
  --dart-define=MAP_PACK_SHA256=<sha256 of the mbtiles>
```

- `MAP_PACK_BYTES` is required for the map: without it the build has no map
  pack (the map screen says so). Rebuild the app whenever the hosted file
  changes, because size and checksum are compiled in.
- `MODEL_PACK_URL` overrides where the model comes from.
- Release builds run the model on the phone (`LLM=edge`). Debug builds
  default to `LLM=host` (llama-server on the laptop, see `lib/czat/llm/README.md`)
  and do not download the model.

Testing the download without a public server: serve the file from the laptop
and forward the port, cleartext is allowed for `127.0.0.1` only.

```
python3 -m http.server 8090 --directory ~/development/packs
adb reverse tcp:8090 tcp:8090
flutter build apk --release --dart-define=MAP_PACK_URL=http://127.0.0.1:8090/zachodniopomorskie.mbtiles ...
```

## Tests

```
flutter analyze
flutter test
```
