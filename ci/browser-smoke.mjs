// ACTION-5 browser smoke: verify a real WebGL2 canvas and all five keyboard views.
// Keeps D01 startup checks while adding D02 rendered camera evidence.
import { chromium } from 'playwright';
import { createHash } from 'node:crypto';
import { mkdir } from 'node:fs/promises';

const errors = [];
const browser = await chromium.launch({
  headless: true,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl'],
});
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('pageerror', error => errors.push('pageerror: ' + error.message));
  page.on('console', message => {
    if (message.type() === 'error') errors.push('console: ' + message.text());
  });
  page.on('requestfailed', req => errors.push('request: ' + req.url() + ': ' + req.failure()?.errorText));
  const url = process.env.ACTION5_WEB_URL || 'http://127.0.0.1:8765/';
  await page.goto(url, { waitUntil: 'load', timeout: 90_000 });
  await page.waitForTimeout(7000);
  const state = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    return {
      hasCanvas: !!canvas,
      width: canvas?.width ?? 0,
      height: canvas?.height ?? 0,
      hasWebGL2: !!canvas?.getContext('webgl2'),
      visible: canvas ? getComputedStyle(canvas).display !== 'none' : false,
    };
  });
  await mkdir('build/evidence', { recursive: true });
  await page.screenshot({ path: 'build/evidence/web-scene.png', fullPage: true });
  console.log('ACTION5_BROWSER_STATE', JSON.stringify(state));
  if (!state.hasCanvas || !state.visible || state.width < 100 || state.height < 100 || !state.hasWebGL2) {
    errors.push('WebGL2 game canvas is unavailable or invalid');
  }
  if (errors.length) throw Error(errors.join('\n'));

  // Native DOM keyboard events drive the Godot InputMap actions, not test hooks.
  const hashes = new Set();
  for (let index = 1; index <= 5; index++) {
    await page.keyboard.press(String(index));
    await page.waitForTimeout(450);
    const png = await page.screenshot({
      path: 'build/evidence/web-view-' + index + '.png',
      fullPage: true,
    });
    hashes.add(createHash('sha256').update(png).digest('hex'));
  }
  if (hashes.size < 5) {
    errors.push('Only ' + hashes.size + '/5 unique camera screenshots after pressing 1–5');
  }

  // D03: Send actual browser keyboard events to a real running Godot world.
  // Movement is handled by InputMap + Action5ActorInputAdapter, not test hooks.
  await page.keyboard.press('2');
  await page.waitForTimeout(300);
  const stationary = createHash('sha256').update(await page.screenshot()).digest('hex');
  await page.keyboard.down('d');
  await page.waitForTimeout(650);
  await page.keyboard.up('d');
  await page.waitForTimeout(250);
  const walking = await page.screenshot({
    path: 'build/evidence/web-d03-walking.png', fullPage: true,
  });
  const walkingHash = createHash('sha256').update(walking).digest('hex');
  if (walkingHash === stationary) {
    errors.push('D03 keyboard movement did not change the real Godot canvas');
  }
  await page.keyboard.down(' ');
  await page.waitForTimeout(220);
  const jumping = await page.screenshot({
    path: 'build/evidence/web-d03-jumping.png', fullPage: true,
  });
  await page.keyboard.up(' ');
  if (createHash('sha256').update(jumping).digest('hex') === walkingHash) {
    errors.push('D03 Space jump did not change the rendered player');
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_D03_LOCOMOTION_OK walk=1 jump=1');

  // The on-screen view selector is a mandatory browser fallback.
  // A D02 Button spans x=24..166 and y=146..190 in the 1280x720 demo.
  await page.mouse.click(94, 169);
  await page.waitForTimeout(500);
  const buttonPng = await page.screenshot({
    path: 'build/evidence/web-selector-view-1.png',
    fullPage: true,
  });
  const buttonHash = createHash('sha256').update(buttonPng).digest('hex');
  const lastKeyHash = [...hashes].at(-1);
  if (buttonHash === lastKeyHash) {
    errors.push('On-screen selector did not visibly change the F5 camera');
  }
  if (errors.length) throw Error(errors.join('\n'));
  // Camera settings must work on real Godot WebGL controls, not only scripts.
  await page.keyboard.press('2');
  await page.waitForTimeout(500);
  const collapsed = createHash('sha256').update(await page.screenshot()).digest('hex');
  // SettingsToggle is at x=1031..1255, y=145..191 on the reference viewport.
  await page.mouse.click(1130, 168);
  await page.waitForTimeout(350);
  const openPng = await page.screenshot({
    path: 'build/evidence/web-camera-settings.png',
    fullPage: true,
  });
  const openHash = createHash('sha256').update(openPng).digest('hex');
  if (openHash === collapsed) {
    errors.push('Camera settings button did not open visible controls');
  }
  await page.keyboard.press('c');
  await page.waitForTimeout(350);
  const closedHash = createHash('sha256').update(await page.screenshot()).digest('hex');
  if (closedHash === openHash) {
    errors.push('Camera settings C shortcut did not close controls');
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_CAMERA_SETTINGS_OK open=1 shortcut=1');
  console.log('ACTION5_BROWSER_FIVE_VIEWS_OK unique=' + hashes.size + ' selector=1');
  console.log('ACTION5_BROWSER_SMOKE_OK ' + url);
} finally {
  await browser.close();
}
