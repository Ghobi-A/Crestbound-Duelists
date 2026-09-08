// Runs against a real exported Godot Web build, never a mocked canvas.
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
const base = process.env.CRESTBOUND_QA_URL || 'http://127.0.0.1:8765';
const out = process.env.CRESTBOUND_QA_OUT;
const browser = await chromium.launch({args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const page = await browser.newPage({viewport:{width:1920,height:1080}});
const errors = [];
page.on('pageerror', error => errors.push(String(error)));
await page.goto(base);
await page.locator('canvas[data-ready="true"]').waitFor({timeout:120000});
await page.locator('canvas').click();
await page.waitForTimeout(1500);
await page.keyboard.press('z'); // story -> class choice
await page.waitForTimeout(350);
await page.keyboard.press('z'); // class choice -> Greymere
await page.waitForTimeout(1500);
await page.keyboard.down('ArrowUp');
await page.waitForTimeout(1300);
await page.keyboard.up('ArrowUp');
await page.waitForTimeout(700);
for (const [width,height] of [[1920,1080],[1280,720],[1024,768],[640,360]]) {
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
await page.keyboard.press('Escape');
await page.waitForTimeout(300);
await page.screenshot({path:`${out}/web-menu.png`});
assert.deepEqual(errors,[]);
console.log('WEB_WORLD_QA: 4 viewport sizes, keyboard progression and menu captured; no page errors');
await browser.close();
