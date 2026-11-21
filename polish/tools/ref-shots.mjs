// Screenshots of the landing's phone mockups (390 px viewport, DPR 3) from a running server.
// Usage: node ref-shots.mjs http://localhost:4173/ ../ref
import { spawn } from 'node:child_process';
import { writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const [url, outDir] = process.argv.slice(2);
const here = dirname(fileURLToPath(import.meta.url)); const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const port = 9600 + Math.floor(Math.random() * 90), prof = mkdtempSync(join(here, 'prof-'));
const chrome = spawn('google-chrome', ['--headless=new', '--disable-gpu', '--hide-scrollbars', `--remote-debugging-port=${port}`, `--user-data-dir=${prof}`, 'about:blank'], { stdio: 'ignore' });
let tabs; for (let i = 0; i < 50 && !tabs; i++) { await sleep(200); try { tabs = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); } catch {} }
const ws = new WebSocket(tabs.find((t) => t.type === 'page').webSocketDebuggerUrl); await new Promise((r) => ws.addEventListener('open', r));
let id = 0; const pend = new Map(); ws.addEventListener('message', (e) => { const m = JSON.parse(e.data); if (pend.has(m.id)) { pend.get(m.id)(m.result); pend.delete(m.id); } });
const send = (method, params = {}) => new Promise((r) => { pend.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });
const ev = async (x) => (await send('Runtime.evaluate', { expression: x, returnByValue: true }))?.result?.value;
await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 3, mobile: true });
await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }] });
await send('Page.navigate', { url }); await sleep(3000);
await ev(`document.head.insertAdjacentHTML('beforeend', '<style>body *{visibility:hidden!important} [inert],[inert] *{visibility:visible!important}</style>')`);
const phones = await ev(`[...document.querySelectorAll('[inert]')].map((el, i) => { const sec = el.closest('section'); const r = el.getBoundingClientRect(); return { i, sec: sec?.id || 'hero', w: r.width, h: r.height, text: el.innerText.replace(/\\s+/g,' ').slice(0, 60) }; }).filter(p => p.w > 150)`);
const seen = {};
for (const p of phones) {
  await ev(`document.querySelectorAll('[inert]')[${p.i}].scrollIntoView({block:'center'})`); await sleep(600);
  const r = await ev(`(() => { const r = document.querySelectorAll('[inert]')[${p.i}].getBoundingClientRect(); return { x: r.x + scrollX, y: r.y + scrollY, width: r.width, height: r.height }; })()`);
  const n = (seen[p.sec] = (seen[p.sec] || 0) + 1); const name = `${p.sec}-${n}.png`;
  const d = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true, clip: { ...r, scale: 1 } });
  writeFileSync(resolve(outDir, name), Buffer.from(d.data, 'base64')); console.log(name, Math.round(r.width) + 'x' + Math.round(r.height), '|', p.text);
}
ws.close(); chrome.kill(); await sleep(200); rmSync(prof, { recursive: true, force: true });
