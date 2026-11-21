// Generates MapLibre SDF glyph PBFs with node fontnik.
// Usage: node build_glyphs.mjs <fontnik-module-dir> <out-dir> <FontStackName>=<font.ttf> ...
// Ranges 0-255 ... 7936-8191 (Latin, Latin Extended, punctuation).
import { createRequire } from 'node:module';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [modDir, outDir, ...stacks] = process.argv.slice(2);
const fontnik = createRequire(join(modDir, 'package.json'))('fontnik');
const range = (opts) => new Promise((res, rej) =>
  fontnik.range(opts, (e, d) => (e ? rej(e) : res(d))));

for (const spec of stacks) {
  const [name, path] = spec.split('=');
  const font = readFileSync(path);
  mkdirSync(join(outDir, name), { recursive: true });
  for (let start = 0; start < 8192; start += 256) {
    const end = start + 255;
    const buf = await range({ font, start, end });
    writeFileSync(join(outDir, name, `${start}-${end}.pbf`), buf);
  }
  console.log(`${name}: done`);
}
