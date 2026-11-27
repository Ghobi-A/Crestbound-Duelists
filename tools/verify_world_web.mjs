// Runs against a real exported Godot Web build, never a mocked canvas.
//
//   (export) godot --headless --path game --export-release "Web" <dir>/index.html
//   (serve)  python -m http.server 8765 --directory <dir>
//   CRESTBOUND_QA_OUT=<shots> node tools/verify_world_web.mjs
//
// Plays the story start with real key presses: title (music) -> New Game ->
// the opening movie (its theme and narration) -> skip -> morning in Kai's
// house (music, the wake-up scene) -> walk to the door (footsteps) -> out
// into Greymere (the door, its ambience) -> a walk through town and the
// menu. Web Audio is instrumented so the log shows the AudioContext running
// and each sound buffer that actually started.
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
const base = process.env.CRESTBOUND_QA_URL || 'http://127.0.0.1:8765';
const out = process.env.CRESTBOUND_QA_OUT || '.';
const browser = await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
const page = await browser.newPage({viewport:{width:1280,height:720}});
const errors = [];
// CRESTBOUND_QA_CPU_THROTTLE=4 slows the page's CPU like a CI runner, to
// prove the walk waits on the game rather than on timing.
const throttle = Number(process.env.CRESTBOUND_QA_CPU_THROTTLE || 1);
if (throttle > 1) {
  const cdp = await page.context().newCDPSession(page);
  await cdp.send('Emulation.setCPUThrottlingRate', {rate: throttle});
}
page.on('pageerror', error => errors.push(String(error)));
await page.addInitScript(() => {
  // Record every sound Godot starts: Web Audio buffers (sample playback)
  // with their length, so cues can be told apart, and each context's state.
  window.__audio = {contexts: [], starts: []};
  const Original = window.AudioContext;
  window.AudioContext = class extends Original {
    constructor(...args) { super(...args); window.__audio.contexts.push(this); }
  };
  const start = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function (...args) {
    window.__audio.starts.push({at: performance.now(), seconds: this.buffer ? +this.buffer.duration.toFixed(2) : -1, loop: this.loop});
    return start.apply(this, args);
  };
});
const audio = async () => page.evaluate(() => ({
  states: window.__audio.contexts.map(c => c.state),
  starts: window.__audio.starts.slice(),
}));
const since = (log, from) => log.starts.filter(s => s.at >= from);
const now = () => page.evaluate(() => performance.now());
const hold = async (key, ms) => { await page.keyboard.down(key); await page.waitForTimeout(ms); await page.keyboard.up(key); };
// Poll the audio log until `test` passes; CI runners are slow and scene
// loads take seconds, so the walk waits on what the game reports, never on
// fixed delays.
const until = async (test, ms, label) => {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const current = await audio();
    if (test(current)) return current;
    await page.waitForTimeout(250);
  }
  assert.fail(`timed out after ${ms} ms waiting for ${label}`);
};
// Hold a direction until `test` passes, pressing it afresh every few seconds:
// a key already held when a new area loads is not a new press there.
const holdUntil = async (key, test, ms, label) => {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    await page.keyboard.down(key);
    const until_press = Math.min(end, Date.now() + 3000);
    while (Date.now() < until_press) {
      if (test(await audio())) { await page.keyboard.up(key); return; }
      await page.waitForTimeout(200);
    }
    await page.keyboard.up(key);
    await page.waitForTimeout(150);
  }
  assert.fail(`timed out after ${ms} ms holding ${key} for ${label}`);
};
const travelTimes = (log, from) => since(log, from).filter(s => s.seconds > 1.0 && s.seconds < 1.4).map(s => s.at);
const travels = (log, from) => travelTimes(log, from).length;
// Footsteps are the 0.26-0.34 s buffers; the door is 0.95 s.
const footsteps = (log, from) => since(log, from).filter(s => s.seconds > 0.2 && s.seconds < 0.4).length;
const doors = (log, from) => since(log, from).filter(s => s.seconds > 0.9 && s.seconds < 1.0).length;
// Walk until something blocks the way: hold until no new footstep for a while.
const walkToWall = async (key, label) => {
  const start = await now();
  let count = -1, still = Date.now();
  await page.keyboard.down(key);
  const end = Date.now() + 20000;
  while (Date.now() < end) {
    const steps = footsteps(await audio(), start);
    if (steps !== count) { count = steps; still = Date.now(); }
    else if (count > 0 && Date.now() - still > 1200) break;
    await page.waitForTimeout(100);
  }
  await page.keyboard.up(key);
  assert.ok(count > 0, `no footsteps walking ${label}`);
  return count;
};
// Walk exactly one tile. A step takes 0.14 s and a turn from standing 0.08 s
// (game/scripts/overworld/player.gd), so a 110 ms hold starts one step and
// lets go before it ends, turning first or not. Each tap is confirmed by its
// footstep and repeated if a slow frame swallowed it.
const stepOnce = async (key) => {
  for (let attempt = 0; attempt < 4; attempt++) {
    const start = await now();
    await page.keyboard.down(key);
    await page.waitForTimeout(110);
    await page.keyboard.up(key);
    await page.waitForTimeout(500);
    if (footsteps(await audio(), start) > 0) return;
  }
  assert.fail(`no step for ${key}`);
};
const walkSteps = async (key, n) => { for (let i = 0; i < n; i++) await stepOnce(key); };

await page.goto(base);
await page.locator('canvas[data-ready="true"]').waitFor({timeout:120000});
await page.locator('canvas').click();   // the user gesture browsers require for sound
let log = await until(l => l.starts.some(s => s.seconds > 30), 30000, 'title music');
await page.waitForTimeout(500);
await page.screenshot({path:`${out}/web-title.png`});
assert.ok(log.states.includes('running'), `AudioContext not running: ${log.states}`);

// Menu cursor and confirm sounds; New Game goes straight to the opening
// (Kai's class is chosen in Civara, at the end of the chapter).
let mark = await now();
await page.keyboard.press('ArrowDown');
await page.waitForTimeout(200);
await page.keyboard.press('ArrowUp');
await page.waitForTimeout(200);
await page.keyboard.press('z');           // New Game -> "The Last Accord"
log = await until(l => since(l, mark).filter(s => s.seconds < 1).length >= 3, 15000, 'menu move and confirm sounds');

// The opening: its theme and the first two narration lines, at 1.5 s and
// 7.3 s of movie time, however long the scene takes to load.
const isNarration = s => s.seconds > 1.5 && s.seconds < 9;
log = await until(l => since(l, mark).some(s => s.seconds > 95) && since(l, mark).filter(isNarration).length >= 2,
  45000, 'the opening theme and two narration lines');
await page.screenshot({path:`${out}/web-opening.png`});

// Skip, then morning in Kai's house: the town theme, and the wake-up scene
// plays by itself. Confirm reads it through (each line needs two presses:
// finish the reveal, then advance).
let skipped = await now();
await hold('z', 2600);
log = await until(l => since(l, skipped).some(s => s.seconds > 30), 30000, 'music in Kai\'s house');
await page.waitForTimeout(1500);   // the fade in finishes and the scene starts
await page.screenshot({path:`${out}/web-kai-house-scene.png`});
for (let i = 0; i < 10; i++) { await page.keyboard.press('z'); await page.waitForTimeout(350); }
await page.waitForTimeout(500);
await page.screenshot({path:`${out}/web-kai-house.png`});

// From the bed to the door (tools/build_greymere_world.py, kai_house): left
// to the table, down to the workbench, two tiles left, down to the door.
mark = await now();
await walkToWall('ArrowLeft', 'to the table');
await page.screenshot({path:`${out}/web-walk-1.png`});
await walkToWall('ArrowDown', 'past the table');
await page.screenshot({path:`${out}/web-walk-2.png`});
await walkSteps('ArrowLeft', 2);
await page.screenshot({path:`${out}/web-walk-3.png`});
await walkToWall('ArrowDown', 'to the door');
await page.screenshot({path:`${out}/web-walk-4.png`});
// Leave. If a slow frame put Kai a tile off, try either side of the door.
let doorMark = await now();
await page.keyboard.press('z');
for (const [key, n] of [['ArrowRight', 1], ['ArrowLeft', 2]]) {
  await page.waitForTimeout(1500);
  if (doors(await audio(), doorMark) > 0) break;
  await walkSteps(key, n);
  await page.keyboard.press('ArrowDown');
  await page.waitForTimeout(300);
  doorMark = await now();
  await page.keyboard.press('z');
}
log = await until(l => doors(l, mark) >= 1, 8000, 'the front door');
const outside = await now();
log = await until(l => since(l, outside).some(s => s.seconds > 15 && s.seconds < 20), 30000, 'Greymere ambience');
await page.waitForTimeout(1500);
await page.screenshot({path:`${out}/web-greymere.png`});
mark = await now();
await walkToWall('ArrowLeft', 'along the east lane');
await page.screenshot({path:`${out}/web-greymere-walk.png`});
log = await audio();
assert.ok(footsteps(log, mark) >= 3, `footsteps did not play: ${footsteps(log, mark)}`);
await page.keyboard.press('Escape');
await page.waitForTimeout(300);
await page.screenshot({path:`${out}/web-menu.png`});
await page.keyboard.press('Escape');

for (const [width,height] of [[1920,1080],[1280,720],[960,540],[1024,768],[640,360]]) {
  await page.setViewportSize({width,height});
  await page.waitForTimeout(500);
  const dimensions = await page.locator('canvas').evaluate(c=>({width:c.width,height:c.height,cssWidth:c.getBoundingClientRect().width,cssHeight:c.getBoundingClientRect().height}));
  const scale = Math.max(1,Math.floor(Math.min(width/320,height/180)));
  assert.equal(dimensions.width,320*scale);
  assert.equal(dimensions.height,180*scale);
  assert.equal(dimensions.cssWidth,dimensions.width);
  assert.equal(dimensions.cssHeight,dimensions.height);
  await page.screenshot({path:`${out}/web-${width}x${height}.png`});
}
log = await audio();
const lengths = {};
for (const s of log.starts) lengths[s.seconds] = (lengths[s.seconds] || 0) + 1;
console.log('AUDIO contexts:', log.states.join(','), ' buffers started:', log.starts.length);
console.log('AUDIO by length (s: count):', JSON.stringify(lengths));
assert.deepEqual(errors,[]);
console.log('WEB_WORLD_QA: title, New Game, opening narration, Kai\'s house and its scene, out through the door into Greymere; sound verified; 5 viewport sizes; no page errors');
await browser.close();
