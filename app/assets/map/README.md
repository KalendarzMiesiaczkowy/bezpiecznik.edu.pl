# Offline map style

`style.json` is a MapLibre style (spec v8), dark, targeting the OpenMapTiles schema produced by
Planetiler (`tools/build_tiles.sh`). Colours come from `bezpiecznik/08-design-system/tokens.json`:
land `bg-100`, buildings `bg-200`, roads `bg-300`/`line-150`/`line-200`, water `info` at 13%,
parks `verified` at 5-7%, street labels `ink-200`/`ink-100` with a `bg-000` halo.
There is no `sprite` key (no icon layers); shelter markers come from the app.
The style contains no http(s) URL; `tools/check_style.py` enforces this.

## Placeholders (exact strings, substituted at runtime by the map task)

| Placeholder | Where | Replace with |
|---|---|---|
| `{MBTILES_PATH}` | `sources.openmaptiles.url` = `mbtiles://{MBTILES_PATH}` | absolute path of the MBTiles file copied to app storage, e.g. `/data/user/0/<pkg>/files/zachodniopomorskie.mbtiles`, so the final url is `mbtiles:///data/user/0/...` |
| `{GLYPHS_DIR}` | `glyphs` = `file://{GLYPHS_DIR}/{fontstack}/{range}.pbf` | absolute directory of the glyphs copied to app storage (no trailing slash), so the final url is `file:///data/user/0/.../glyphs/{fontstack}/{range}.pbf` |

`{fontstack}` and `{range}` are MapLibre's own tokens: leave them untouched.
Do a plain string replace of the two placeholders on the style JSON text, then pass the result to
`MapLibreMap(styleString: ...)`.

## Loading local glyphs

maplibre_gl 0.28 cannot point `glyphs` at `asset://` (its CHANGELOG: "the native engines fetch those
themselves; copy the files to disk at startup and reference them with `file://`"). So on first run
copy `assets/map/glyphs/**` and the mbtiles from the asset bundle to the app documents/support
directory, then substitute the placeholders with those paths.

## Fonts and glyphs

Font stacks used by the style (directory name = stack name, no spaces on purpose):
`AtkinsonHyperlegibleNext-Regular`, `AtkinsonHyperlegibleNext-Bold` (static instances at wght 400/700
of the design-system variable font, latin + latin-ext merged).
`glyphs/<stack>/<start>-<end>.pbf` covers 0-8191 in 256-code-point ranges (~250 KB per stack);
ranges 0-255 and 256-511 include Polish diacritics.
Regenerate: instantiate the variable woff2 files with fontTools (`varLib.instancer`, merge latin and
latin-ext with `fontTools.merge`), then `node tools/build_glyphs.mjs <dir-with-fontnik> app/assets/map/glyphs <Stack>=<font.ttf> ...`
(needs `npm install fontnik`).

## Labels

Polish: `["coalesce", ["get","name:pl"], ["get","name"]]` on places, streets and water names.

## pubspec assets

Flutter does not include sub-directories recursively, list each one:
`assets/map/`, `assets/map/glyphs/AtkinsonHyperlegibleNext-Regular/`,
`assets/map/glyphs/AtkinsonHyperlegibleNext-Bold/`, `assets/generated/`.

## Attribution

Show "© OpenStreetMap contributors" (ODbL) and "OpenMapTiles" / Planetiler attribution in the app
(the mbtiles `attribution` metadata row has the exact string).
