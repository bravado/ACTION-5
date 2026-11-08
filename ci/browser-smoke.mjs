// ACTION-5 browser smoke: verify a real WebGL2 canvas and all five keyboard views.
// Keeps D01 startup checks while adding D02 rendered camera evidence.
import { chromium } from 'playwright';
import { createHash } from 'node:crypto';
import { mkdir } from 'node:fs/promises';

const errors = [];
const cameraChanges = [];
const moveChanges = [];
const settingsVisibility = [];
const rigViews = [];
const browser = await chromium.launch({
  headless: true,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl'],
});
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('pageerror', error => errors.push('pageerror: ' + error.message));
  page.on('console', message => {
    const line = message.text();
    if (message.type() === 'error') errors.push('console: ' + line);
    if (line.includes('ACTION5_VIEW_CHANGED')) cameraChanges.push(line);
    if (line.includes('ACTION5_MOVE_CHANGED')) moveChanges.push(line);
    if (line.includes('ACTION5_D04_PRESENTATION')) rigViews.push(line);
    if (line.includes('ACTION5_CAMERA_SETTINGS_VISIBLE')) settingsVisibility.push(line);
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
  if (!rigViews.some(line => line.includes('view=3 body_hidden=0 rig=1 tool=1')) ||
      !rigViews.some(line => line.includes('view=4 body_hidden=1 rig=1 tool=1') &&
        line.includes('viewmodel=1'))) {
    errors.push('D04 imported rig, F4 camera-local weapon, or body culling failed');
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_D04_RIG_OK skeleton=1 sockets=1 fps=1 body_culling=1');

  // Movement extension: compare standing/crouched first-person views
  // through real browser input, then validate the independent F3 animations.
  await page.keyboard.press('4');
  await page.waitForTimeout(600);
  const standingEye = await page.screenshot({
    path: 'build/evidence/web-f4-eye-standing.png', fullPage: true,
  });
  await page.keyboard.press('3');
  await page.waitForTimeout(400);
  await page.keyboard.press('Control');
  await page.waitForTimeout(550);
  const crouchIdle = await page.screenshot({
    path: 'build/evidence/web-crouch-idle.png', fullPage: true,
  });
  await page.keyboard.press('4');
  await page.waitForTimeout(650);
  const loweredEye = await page.screenshot({
    path: 'build/evidence/web-f4-eye-crouched.png', fullPage: true,
  });
  if (createHash('sha256').update(standingEye).digest('hex') ===
      createHash('sha256').update(loweredEye).digest('hex')) {
    errors.push('First-person eye view did not change after crouching');
  }
  await page.keyboard.press('3');
  await page.waitForTimeout(300);
  // Capture the exact side silhouette too: isometric screenshots alone can
  // hide whether knees are in front of or behind the hips.
  await page.keyboard.press('1');
  await page.waitForTimeout(400);
  await page.screenshot({
    path: 'build/evidence/web-crouch-side-idle.png', fullPage: true,
  });
  await page.keyboard.press('3');
  await page.waitForTimeout(400);
  if (!moveChanges.some(line => line.includes('current=crouch') &&
      !line.includes('current=crouch_walk'))) {
    errors.push('Crouch idle did not activate via the real Ctrl input action');
  }
  await page.keyboard.down('a');
  await page.waitForTimeout(900);
  const crouchWalk = await page.screenshot({
    path: 'build/evidence/web-crouch-walk.png', fullPage: true,
  });
  await page.keyboard.press('1');
  await page.waitForTimeout(400);
  await page.screenshot({
    path: 'build/evidence/web-crouch-side-walk.png', fullPage: true,
  });
  await page.keyboard.press('3');
  await page.waitForTimeout(400);
  await page.keyboard.up('a');
  await page.waitForTimeout(950);
  if (!moveChanges.some(line => line.includes('current=crouch_walk'))) {
    errors.push('Crouch walk did not activate while holding a movement key');
  }
  if (createHash('sha256').update(crouchIdle).digest('hex') ===
      createHash('sha256').update(crouchWalk).digest('hex')) {
    errors.push('Crouch idle and crouch walking produced identical browser screenshots');
  }
  const sawReturnToIdle = moveChanges.some(line =>
    line.includes('previous=crouch_walk current=crouch'));
  if (!sawReturnToIdle) {
    errors.push('Releasing the walking key did not return crouch-walk to crouch idle; events='
      + moveChanges.slice(-12).join(' | '));
  }
  await page.keyboard.press('Control', { delay: 150 });
  await page.waitForTimeout(950);
  const didStand = moveChanges.some(line =>
    line.includes('previous=crouch current=grounded') ||
    line.includes('previous=crouch_walk current=grounded'));
  if (!didStand) {
    errors.push('Second Ctrl press failed to restore the normal grounded move; events='
      + moveChanges.slice(-12).join(' | '));
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_CROUCH_OK idle=1 walk=1 stand=1 eye_height=1 screenshots=4');



  // Reproduce the reported F4 jump: the camera-anchored training tool must
  // remain enabled even while the world-space hand and actor move upward.
  await page.keyboard.press('4');
  await page.waitForTimeout(550);
  const f4Standing = await page.screenshot({
    path: 'build/evidence/web-f4-tool-standing.png', fullPage: true,
  });
  await page.keyboard.down(' ');
  await page.waitForTimeout(225);
  const f4Jumping = await page.screenshot({
    path: 'build/evidence/web-f4-tool-jumping.png', fullPage: true,
  });
  await page.keyboard.up(' ');
  if (createHash('sha256').update(f4Standing).digest('hex') ===
      createHash('sha256').update(f4Jumping).digest('hex')) {
    errors.push('F4 jump screenshot did not change after real Space input');
  }
  if (!rigViews.some(line => line.includes('view=4 body_hidden=1 rig=1 tool=1') &&
      line.includes('viewmodel=1'))) {
    errors.push('F4 camera-local training tool was not presented');
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_F4_JUMP_TOOL_OK viewmodel=1 screenshots=2');

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
  // A bundled move registers its own 'actor_slide' key. This should fire
  // through the generic registry, without any slide branch in ActorInput.
  await page.keyboard.down('d');
  // Software WebGL2 rendering can starve 60-Hz physics briefly in CI.
  // Allow time to reach Slide's grounded speed threshold, then send real
  // keydown/keyup edges (never call the movement controller from the test).
  await page.waitForTimeout(1100);
  for (let attempt = 0; attempt < 3; attempt++) {
    await page.keyboard.press('x', { delay: 110 });
    await page.waitForTimeout(320);
    if (moveChanges.some(line => line.includes('current=slide'))) break;
    await page.waitForTimeout(650);
  }
  await page.keyboard.up('d');
  if (!moveChanges.some(line => line.includes('current=slide'))) {
    errors.push('D03 Slide did not activate via real InputMap key X after 3 input edges; events='
      + moveChanges.slice(-8).join(' | '));
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_MOVE_PLUGIN_OK slide=1');

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
  // Reproduce the user-reported focus bug with *real* canvas events.
  // Clicking mode 3, pressing 2, and then jumping must not re-activate 3.
  await page.mouse.click(391, 169);
  await page.waitForTimeout(200);
  await page.keyboard.press('2');
  await page.waitForTimeout(300);
  const cameraCountBeforeSpace = cameraChanges.length;
  if (cameraCountBeforeSpace === 0 ||
      !cameraChanges.at(-1).includes('index=2')) {
    errors.push('Cannot confirm selected view from Godot browser logs');
  }
  await page.keyboard.press('Space');
  await page.waitForTimeout(300);
  if (cameraChanges.length !== cameraCountBeforeSpace) {
    errors.push('Space activated previously clicked camera button');
  }
  // Likewise Camera Settings must not reopen when Space is pressed after C.
  await page.mouse.click(1130, 168);
  await page.waitForTimeout(200);
  await page.keyboard.press('c');
  await page.waitForTimeout(200);
  const visibilityBeforeSpace = settingsVisibility.length;
  if (visibilityBeforeSpace === 0 ||
      !settingsVisibility.at(-1).includes('closed')) {
    errors.push('Cannot confirm camera settings closed before Space');
  }
  await page.keyboard.press('Space');
  await page.waitForTimeout(300);
  if (settingsVisibility.length !== visibilityBeforeSpace) {
    errors.push('Space reactivated the Camera Settings button');
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_FOCUS_OK view=1 settings=1 jump=1');
  console.log('ACTION5_BROWSER_CAMERA_SETTINGS_OK open=1 shortcut=1');
  console.log('ACTION5_BROWSER_FIVE_VIEWS_OK unique=' + hashes.size + ' selector=1');

  // VT-12: drive the REAL actor into the existing solid NorthWall, then
  // capture F3 and F4 at the same near-wall position. A layer-only test
  // in an empty room would not catch first-person wall occlusion.
  await page.keyboard.press('4');
  await page.waitForTimeout(350);
  await page.keyboard.down('Shift');
  await page.keyboard.down('w');
  let nearWallZ = Number.NaN;
  for (let attempt = 0; attempt < 7; attempt++) {
    await page.waitForTimeout(1200);
    // Re-enter F4 to emit the demo's existing per-view position/culling
    // diagnostics; no test-only teleport or browser-to-Godot bridge.
    await page.keyboard.press('3');
    await page.waitForTimeout(170);
    await page.keyboard.press('4');
    await page.waitForTimeout(250);
    const report = [...rigViews].reverse().find(line =>
      line.includes('view=4 body_hidden=1 rig=1 tool=1 actor_z='));
    const match = report?.match(/actor_z=(-?\d+(?:\.\d+)?)/);
    nearWallZ = match ? Number(match[1]) : Number.NaN;
    if (nearWallZ <= -7.5 && nearWallZ > -8.7) break;
  }
  await page.keyboard.up('w');
  await page.keyboard.up('Shift');
  await page.waitForTimeout(400);
  await page.keyboard.press('3');
  await page.waitForTimeout(500);
  const thirdPersonNearWall = await page.screenshot({
    path: 'build/evidence/web-f3-near-wall.png', fullPage: true,
  });
  await page.keyboard.press('4');
  await page.waitForTimeout(500);
  const firstPersonNearWall = await page.screenshot({
    path: 'build/evidence/web-f4-near-wall.png', fullPage: true,
  });
  const finalF4 = [...rigViews].reverse().find(line =>
    line.includes('view=4 body_hidden=1 rig=1 tool=1 actor_z='));
  const finalMatch = finalF4?.match(/actor_z=(-?\d+(?:\.\d+)?)/);
  const finalZ = finalMatch ? Number(finalMatch[1]) : Number.NaN;
  if (!(finalZ <= -7.5 && finalZ > -8.7)) {
    errors.push('VT-12 browser actor failed to reach the solid NorthWall: z=' + finalZ);
  }
  if (createHash('sha256').update(thirdPersonNearWall).digest('hex') ===
      createHash('sha256').update(firstPersonNearWall).digest('hex')) {
    errors.push('VT-12 F3 and F4 near-wall screenshots are identical');
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_FPS_NEAR_WALL_OK z=' + finalZ.toFixed(2)
    + ' body_culled=1 wall=1 screenshots=2');
  console.log('ACTION5_BROWSER_SMOKE_OK ' + url);
} finally {
  await browser.close();
}
