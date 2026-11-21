#!/usr/bin/env bash
# Usage: polish/tools/compare.sh  → polish/compare/<name>.png (before | after) + polish/compare/demo.mp4
set -eu
cd "$(dirname "$0")/.."
mkdir -p compare compare/frames; rm -f compare/frames/*
FONT=$(fc-match -f '%{file}' 'Atkinson Hyperlegible Next:bold' 2>/dev/null || fc-match -f '%{file}' 'DejaVu Sans:bold')
ORDER="onboarding-1 onboarding-3 czat-start czat-odpowiedz czat-zrodlo karta-ratunkowa rko sos mapa mapa-punkt kompas profil ustawienia"
i=0
for n in $ORDER; do
  [ -f "before/$n.png" ] && [ -f "after/$n.png" ] || continue
  magick \( before/$n.png -resize x1600 \) \( after/$n.png -resize x1600 \) -background '#100f0e' -gravity center +smush 60 \
    -gravity north -splice 0x130 -font "$FONT" -pointsize 56 -fill '#a9a59d' -annotate -370+40 'Przed' -fill '#eeece6' -annotate +370+40 'Po' compare/$n.png
  # video frames: before, after (same canvas)
  for s in before after; do
    magick $s/$n.png -resize x1700 -background '#100f0e' -gravity center -extent 1080x1920 \
      -gravity north -font "$FONT" -pointsize 52 -fill "$([ $s = before ] && echo '#a9a59d' || echo '#eeece6')" \
      -annotate +0+70 "$n · $([ $s = before ] && echo Przed || echo Po)" compare/frames/$(printf %02d $i)-$s.png
  done
  i=$((i+1))
done
[ $i -gt 0 ] || { echo "no pairs"; exit 1; }
# each screen: 1.5 s before, 0.6 s crossfade, 2.4 s after  → ~4.5 s per screen
inputs=(); filt=""; k=0
for f in compare/frames/*-before.png; do
  a=${f%-before.png}-after.png
  inputs+=(-loop 1 -t 2.1 -i "$f" -loop 1 -t 3.0 -i "$a")
  filt+="[$((2*k)):v][$((2*k+1)):v]xfade=transition=fade:duration=0.6:offset=1.5,format=yuv420p[s$k];"
  k=$((k+1))
done
cat=""; for j in $(seq 0 $((k-1))); do cat+="[s$j]"; done
ffmpeg -y -loglevel error "${inputs[@]}" -filter_complex "${filt}${cat}concat=n=$k:v=1:a=0,fps=30[v]" -map "[v]" -c:v libx264 -crf 22 -pix_fmt yuv420p compare/demo.mp4
echo "pairs: $i  video: $(ffprobe -v error -show_entries format=duration -of csv=p=0 compare/demo.mp4)s"
