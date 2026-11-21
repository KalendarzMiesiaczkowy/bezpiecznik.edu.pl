#!/usr/bin/env bash
# Builds app/assets/generated/zachodniopomorskie.mbtiles with Planetiler (OpenMapTiles profile).
# Idempotent: re-running skips downloads that exist; set FORCE=1 to rebuild the mbtiles.
# Tools/data live under ~/development, never in the repo.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV="${DEV_HOME:-$HOME/development}"
PLANETILER_VERSION="${PLANETILER_VERSION:-v0.10.2}"   # needs Java 21+ (jar manifest: Java-Version 21)
JAR="$DEV/planetiler/planetiler.jar"
JAVA_HOME_21="${JAVA_HOME_21:-$DEV/jdk21}"             # used only here; env.sh keeps JDK 17 for Android
DATA="$DEV/data"
SRC_DIR="$DATA/planetiler"
PBF="$DATA/zachodniopomorskie-latest.osm.pbf"
GEOFABRIK="https://download.geofabrik.de/europe/poland/zachodniopomorskie/zachodniopomorskie"
OUT="$REPO/app/assets/generated/zachodniopomorskie.mbtiles"
XMX="${PLANETILER_XMX:-6g}"

mkdir -p "$DEV/planetiler" "$SRC_DIR" "$(dirname "$OUT")"

# JDK 21 (Temurin) if missing.
if [ ! -x "$JAVA_HOME_21/bin/java" ]; then
  echo ">> installing Temurin 21 into $JAVA_HOME_21"
  mkdir -p "$JAVA_HOME_21"
  curl -fL -sS "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse" \
    | tar xz -C "$JAVA_HOME_21" --strip-components=1
fi

# Planetiler jar if missing.
if [ ! -s "$JAR" ]; then
  echo ">> downloading Planetiler $PLANETILER_VERSION"
  curl -fL -sS -o "$JAR.part" \
    "https://github.com/onthegomap/planetiler/releases/download/$PLANETILER_VERSION/planetiler.jar"
  mv "$JAR.part" "$JAR"
fi

# OSM extract if missing or if it is not a real PBF (an HTML error page is tiny).
if [ ! -s "$PBF" ] || [ "$(stat -c %s "$PBF")" -lt 1000000 ]; then
  echo ">> downloading OSM extract"
  ok=0
  # '-latest' is a redirect to the dated file, which may not be published yet: fall back to previous days.
  if curl -fL -sS -o "$PBF.part" "$GEOFABRIK-latest.osm.pbf"; then ok=1; fi
  for back in 1 2 3 4 5 6 7; do
    [ "$ok" = 1 ] && break
    d="$(date -d "-$back day" +%y%m%d)"
    if curl -fL -sS -o "$PBF.part" "$GEOFABRIK-$d.osm.pbf"; then ok=1; fi
  done
  [ "$ok" = 1 ] || { echo "cannot download OSM extract" >&2; exit 1; }
  mv "$PBF.part" "$PBF"
fi

START=$(date +%s)
if [ -s "$OUT" ] && [ "${FORCE:-0}" != 1 ]; then
  echo ">> $OUT exists, skipping build (FORCE=1 to rebuild)"
else
  # Planetiler downloads water polygons, Natural Earth and lake centerlines into SRC_DIR (--download).
  # --maxzoom 14 is the Planetiler default: tiles above z14 are over-zoomed by the client.
  "$JAVA_HOME_21/bin/java" "-Xmx$XMX" -jar "$JAR" \
    --osm-path="$PBF" \
    --output="$OUT" \
    --download \
    --download_dir="$SRC_DIR" \
    --tmpdir="$DATA/planetiler-tmp" \
    --storage=mmap \
    --force
  rm -rf "$DATA/planetiler-tmp"
fi
END=$(date +%s)

echo ">> output: $OUT"
echo ">> size:   $(du -h "$OUT" | cut -f1) ($(stat -c %s "$OUT") bytes)"
echo ">> elapsed: $((END - START)) s"
