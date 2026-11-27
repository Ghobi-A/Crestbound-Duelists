// Mobile check against a real exported Godot Web build: an emulated phone
// (touch, coarse pointer, landscape 844x390) with no autoplay exemption, so
// sound has to unlock from a real tap. Every input is a real touch on the
// web shell's on-screen pad (game/web/shell.html), dispatched through CDP,
// never a keyboard press:
//
//   tap to begin (unlocks sound) -> title -> A: New Game -> the opening (hold A to skip) ->
//   Kai's house and the wake-up scene -> D-pad walk to the door -> out into
//   Greymere -> B opens the field menu and closes it; then portrait.
//
//   (export) godot --headless --path game --export-release "Web" <dir>/index.html
//   (serve)  python -m http.server 8765 --directory <dir>
//   CRESTBOUND_QA_OUT=<shots> node tools/verify_mobile_web.mjs
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
const base = process.env.CRESTBOUND_QA_URL || 'http://127.0.0.1:8765';
const out = process.env.CRESTBOUND_QA_OUT || '.';
const browser = await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const context = await browser.newContext({viewport:{width:844,height:390}, isMobile:true, hasTouch:true});
const page = await context.newPage();
const cdp = await context.newCDPSession(page);
const errors = [];
page.on('pageerror', error => errors.push(String(error)));
await page.addInitScript(() => {
  window.__audio = {contexts: [], starts: []};
  const Original = window.AudioContext;
  window.AudioContext = class extends Original {
    constructor(...args) { super(...args); window.__audio.contexts.push(this); }
  };
  const start = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function (...args) {
    window.__audio.starts.push({at: performance.now(), seconds: this.buffer ? +this.buffer.duration.toFixed(2) : -1});
    return start.apply(this, args);
  };
});
const audio = async () => page.evaluate(() => ({
  states: window.__audio.contexts.map(c => c.state),
  starts: window.__audio.starts.slice(),
}));
const since = (log, from) => log.starts.filter(s => s.at >= from);
const now = () => page.evaluate(() => performance.now());
const footsteps = (log, from) => since(log, from).filter(s => s.seconds > 0.2 && s.seconds < 0.4).length;
const doors = (log, from) => since(log, from).filter(s => s.seconds > 0.9 && s.seconds < 1.0).length;
const until = async (test, ms, label) => {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const current = await audio();
    if (test(current)) return current;
    await page.waitForTimeout(250);
  }
  assert.fail(`timed out after ${ms} ms waiting for ${label}`);
};
// A real finger on one of the shell's buttons, held for `ms`.
let touchId = 0;
const centre = async (code) => {
  const box = await page.locator(`#mobile-pad button[data-code="${code}"]`).boundingBox();
  assert.ok(box, `no on-screen button for ${code}`);
  return {x: box.x + box.width / 2, y: box.y + box.height / 2};
};
const press = async (code, ms = 90) => {
  const point = await centre(code);
  const id = touchId++;
  await cdp.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [{...point, id}]});
  await page.waitForTimeout(ms);
  await cdp.send('Input.dispatchTouchEvent', {type: 'touchEnd', touchPoints: []});
  await page.waitForTimeout(60);
};
const tapA = () => press('KeyZ');
const walkToWall = async (code) => {
  const point = await centre(code);
  const start = await now();
  await cdp.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [{...point, id: touchId++}]});
  let count = -1, still = Date.now();
  const end = Date.now() + 20000;
  while (Date.now() < end) {
    const steps = footsteps(await audio(), start);
    if (steps !== count) { count = steps; still = Date.now(); }
    else if (count > 0 && Date.now() - still > 1200) break;
    await page.waitForTimeout(100);
  }
  await cdp.send('Input.dispatchTouchEvent', {type: 'touchEnd', touchPoints: []});
  assert.ok(count > 0, `no footsteps holding ${code}`);
};
// One tile: a 110 ms touch starts one 0.14 s step (player.gd) and lets go
// before it ends; confirmed by its footstep and repeated if swallowed.
const stepOnce = async (code) => {
  for (let attempt = 0; attempt < 4; attempt++) {
    const start = await now();
    await press(code, 110);
    await page.waitForTimeout(450);
    if (footsteps(await audio(), start) > 0) return;
  }
  assert.fail(`no step for ${code}`);
};

await page.goto(base);
await page.locator('canvas[data-ready="true"]').waitFor({timeout: 120000});
assert.ok(await page.locator('#mobile-pad.active').isVisible(), 'the touch pad is not showing on a phone');
for (const code of ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'KeyZ', 'KeyX']) await centre(code);
// Held sideways the pad sits in the gutters beside the 2x canvas: A and B
// clear of it, the D-pad over its edge by at most a 15 px (30 CSS px) strip.
const overlap = async () => page.evaluate(() => {
  const canvas = document.querySelector('canvas').getBoundingClientRect();
  const over = code => {
    const b = document.querySelector(`#mobile-pad button[data-code="${code}"]`).getBoundingClientRect();
    const x = Math.max(0, Math.min(b.right, canvas.right) - Math.max(b.left, canvas.left));
    const y = Math.max(0, Math.min(b.bottom, canvas.bottom) - Math.max(b.top, canvas.top));
    return x && y ? x : 0;
  };
  return {dpad: Math.max(...['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].map(over)), actions: Math.max(over('KeyZ'), over('KeyX')),
          size: document.querySelector('#mobile-pad button').getBoundingClientRect().width};
});
let layout = await overlap();
assert.ok(layout.actions === 0 && layout.dpad <= 30 && layout.size >= 40, `landscape pad covers the game: ${JSON.stringify(layout)}`);
await page.screenshot({path: `${out}/mobile-title.png`});

// "Tap to begin" is the gesture that unlocks sound; it chooses nothing.
assert.ok(await page.locator('#tap-to-begin.active').isVisible(), 'no tap-to-begin gate on a phone');
await cdp.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [{x: 422, y: 195, id: touchId++}]});
await cdp.send('Input.dispatchTouchEvent', {type: 'touchEnd', touchPoints: []});
let log = await until(l => l.states.includes('running') && l.starts.some(s => s.seconds > 30), 30000, 'sound unlocked by a tap, and the title theme');
assert.ok(!(await page.locator('#tap-to-begin.active').isVisible()), 'the gate stayed up after a tap');
await page.waitForTimeout(1200);
// Prompts name the pad's A and B, not the keyboard's Z and X.
assert.equal(await page.evaluate(() => window.crestboundPromptStyle), 'pad', 'prompts still name keyboard keys on a phone');
await page.screenshot({path: `${out}/mobile-title-sound.png`});
// New Game is the first row: A starts the opening.
let mark = await now();
await tapA();
log = await until(l => since(l, mark).some(s => s.seconds > 95), 45000, 'the opening theme');
await page.screenshot({path: `${out}/mobile-opening.png`});
// Hold A to skip the movie, then morning in Kai's house and its scene.
// The skip lands 0.9 s into the hold, so the next scene's music can start
// before the finger lifts: mark the time first.
const skipped = await now();
await press('KeyZ', 2600);
log = await until(l => since(l, skipped).some(s => s.seconds > 30), 30000, 'music in Kai\'s house');
await page.waitForTimeout(1500);
await page.screenshot({path: `${out}/mobile-kai-house-scene.png`});
for (let i = 0; i < 10; i++) { await tapA(); await page.waitForTimeout(300); }
await page.waitForTimeout(500);
// The bed to the door with the D-pad (the same route as verify_world_web.mjs).
mark = await now();
await page.screenshot({path: `${out}/mobile-walk-0.png`});
await walkToWall('ArrowLeft');
await page.screenshot({path: `${out}/mobile-walk-1.png`});
await walkToWall('ArrowDown');
await page.screenshot({path: `${out}/mobile-walk-2.png`});
await stepOnce('ArrowLeft');
await stepOnce('ArrowLeft');
await page.screenshot({path: `${out}/mobile-walk-3.png`});
await walkToWall('ArrowDown');
await page.screenshot({path: `${out}/mobile-walk-4.png`});
let doorMark = await now();
await tapA();
for (const [code, n] of [['ArrowRight', 1], ['ArrowLeft', 2]]) {
  await page.waitForTimeout(1500);
  if (doors(await audio(), doorMark) > 0) break;
  for (let i = 0; i < n; i++) await stepOnce(code);
  await press('ArrowDown', 60);
  doorMark = await now();
  await tapA();
}
log = await until(l => doors(l, mark) >= 1, 8000, 'the front door');
const outside = await now();
log = await until(l => since(l, outside).some(s => s.seconds > 15 && s.seconds < 20), 30000, 'Greymere ambience');
await page.waitForTimeout(1500);
await page.screenshot({path: `${out}/mobile-greymere.png`});
assert.ok(footsteps(log, mark) >= 3, 'no footsteps from the D-pad walk');
// B opens the field menu; B again closes it.
await press('KeyX');
await page.waitForTimeout(600);
await page.screenshot({path: `${out}/mobile-menu.png`});
await press('KeyX');
await page.waitForTimeout(400);
// Portrait: the canvas still fits and the pad stays on screen.
await page.setViewportSize({width: 390, height: 844});
await page.waitForTimeout(800);
const canvas = await page.locator('canvas').boundingBox();
assert.ok(canvas.width <= 390 && canvas.width >= 320, `portrait canvas width ${canvas.width}`);
for (const code of ['ArrowUp', 'KeyZ']) {
  const box = await page.locator(`#mobile-pad button[data-code="${code}"]`).boundingBox();
  assert.ok(box.y + box.height <= 844 && box.x >= 0 && box.x + box.width <= 390, `${code} button off screen in portrait`);
}
// Upright, the pad has its own band under the game and covers none of it.
layout = await overlap();
assert.ok(layout.dpad === 0 && layout.actions === 0 && layout.size >= 44, `portrait pad covers the game: ${JSON.stringify(layout)}`);
await page.screenshot({path: `${out}/mobile-portrait.png`});
assert.deepEqual(errors, []);
console.log('MOBILE_WEB_QA: touch pad shown around the game; a tap unlocked sound; A/B prompts; New Game, opening skip, wake-up scene, D-pad walk to the door, Greymere, field menu, portrait layout; no page errors');
await browser.close();
