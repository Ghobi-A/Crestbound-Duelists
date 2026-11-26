// Runs against a real exported Godot Web build, never a mocked canvas.
//
//   (export) godot --headless --path game --export-release "Web" <dir>/index.html
//   (serve)  python -m http.server 8765 --directory <dir>
//   CRESTBOUND_QA_OUT=<shots> node tools/verify_world_web.mjs
//
// Plays the story start with real key presses: title (music) -> class
// choice -> the opening movie (its theme and narration) -> skip -> Greymere
// (music, ambience, footsteps) -> walk off the south road, no button needed
// -> Route 01 -> walk back. Web Audio is instrumented so the log shows the
// AudioContext running and each sound buffer that actually started.
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
const base = process.env.CRESTBOUND_QA_URL || 'http://127.0.0.1:8765';
const out = process.env.CRESTBOUND_QA_OUT || '.';
const browser = await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
const page = await browser.newPage({viewport:{width:1280,height:720}});
const errors = [];
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

await page.goto(base);
await page.locator('canvas[data-ready="true"]').waitFor({timeout:120000});
await page.locator('canvas').click();   // the user gesture browsers require for sound
await page.waitForTimeout(2500);
await page.screenshot({path:`${out}/web-title.png`});
let log = await audio();
assert.ok(log.states.includes('running'), `AudioContext not running: ${log.states}`);
assert.ok(log.starts.some(s => s.seconds > 30), 'title music did not start');

// Menu cursor and confirm sounds, then class choice.
let mark = await now();
await page.keyboard.press('ArrowDown');
await page.waitForTimeout(200);
await page.keyboard.press('ArrowUp');
await page.waitForTimeout(200);
await page.keyboard.press('z');           // Play Story Demo -> class choice
await page.waitForTimeout(600);
await page.screenshot({path:`${out}/web-class-select.png`});
log = await audio();
assert.ok(since(log, mark).filter(s => s.seconds < 1).length >= 3, 'menu move/confirm sounds did not play');

// The opening: its theme and the first two narration lines.
mark = await now();
await page.keyboard.press('z');           // Begin -> "The Last Accord"
await page.waitForTimeout(10000);
await page.screenshot({path:`${out}/web-opening.png`});
log = await audio();
const opening = since(log, mark);
assert.ok(opening.some(s => s.seconds > 95), 'opening theme did not start');
const narration = opening.filter(s => s.seconds > 1.5 && s.seconds < 9);
assert.ok(narration.length >= 2, `narration lines did not start: ${JSON.stringify(opening)}`);

// Skip, then Greymere: music and ambience. A new game starts two tiles
// above the south road's edge, so holding Down walks off it onto Route 01
// with no button press; holding Left walks back through the route's west
// mouth into town.
await hold('z', 2600);
await page.waitForTimeout(3500);
await page.screenshot({path:`${out}/web-greymere.png`});
log = await audio();
assert.ok(log.starts.some(s => s.seconds > 15 && s.seconds < 20), 'Greymere ambience did not start');
mark = await now();
await hold('ArrowDown', 1400);
await page.waitForTimeout(1500);
await page.screenshot({path:`${out}/web-route-01.png`});
await hold('ArrowLeft', 1400);
await page.waitForTimeout(1500);
await page.screenshot({path:`${out}/web-route-return.png`});
log = await audio();
const walk = since(log, mark);
// Footsteps are the 0.26-0.34 s buffers; the road travel sound is 1.2 s.
const steps = walk.filter(s => s.seconds > 0.2 && s.seconds < 0.4);
assert.ok(steps.length >= 3, `footsteps did not play: ${steps.length}`);
assert.equal(walk.filter(s => s.seconds > 1.0 && s.seconds < 1.4).length, 2, 'expected two road crossings (out and back)');
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
console.log('WEB_WORLD_QA: title, class select, opening narration, Greymere, route and back; sound verified; 5 viewport sizes; no page errors');
await browser.close();
