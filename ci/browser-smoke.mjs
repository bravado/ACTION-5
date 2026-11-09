// ACTION-5 browser smoke: verify a real WebGL2 canvas and all five keyboard views.
// Keeps D01 startup checks while adding D02 rendered camera evidence.
import { chromium } from 'playwright';
import { createHash } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';

const errors = [];
const cameraChanges = [];
const moveChanges = [];
const settingsVisibility = [];
const rigViews = [];
const combatStarts = [];
const weaponEvents = [];
const limbVisibility = [];
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
    if (line.includes('ACTION5_ATTACK_STARTED')) combatStarts.push(line);
    if (line.includes('ACTION5_WEAPON_')) weaponEvents.push(line);
    if (line.includes('ACTION5_F4_LIMB_VISIBLE')) limbVisibility.push(line);
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

  // Real browser keys exercise the decoupled combat adapter. Capture each
  // authored action while its AnimationTree channel is playing in F3.
  await page.keyboard.press('3');
  await page.waitForTimeout(500);
  const idleCombat = await page.screenshot();
  await page.keyboard.down('j');
  await page.waitForTimeout(110);
  const punchCombat = await page.screenshot({
    path: 'build/evidence/web-d05-punch.png', fullPage: true,
  });
  await page.keyboard.up('j');
  await page.waitForTimeout(600);
  await page.keyboard.down('k');
  await page.waitForTimeout(165);
  const kickCombat = await page.screenshot({
    path: 'build/evidence/web-d05-kick.png', fullPage: true,
  });
  await page.keyboard.up('k');
  await page.waitForTimeout(600);
  if (!combatStarts.some(line => line.includes('id=punch')) ||
      !combatStarts.some(line => line.includes('id=kick'))) {
    errors.push('D05 browser J/K did not start both configured actions: ' + combatStarts.join(' | '));
  }
  if (createHash('sha256').update(idleCombat).digest('hex') ===
      createHash('sha256').update(punchCombat).digest('hex') ||
      createHash('sha256').update(punchCombat).digest('hex') ===
      createHash('sha256').update(kickCombat).digest('hex')) {
    errors.push('D05 browser punch/kick pose evidence is identical');
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_D05_COMBAT_OK punch=1 kick=1 screenshots=2');

  // The same action definitions must react to real left/right mouse clicks.
  // A HUD button must consume its click without also starting a punch.
  await page.keyboard.press('2');
  await page.waitForTimeout(450);
  const beforeMousePunch = combatStarts.length;
  await page.mouse.click(700, 420, { button: 'left' });
  await page.waitForTimeout(500);
  if (!combatStarts.slice(beforeMousePunch).some(line => line.includes('id=punch'))) {
    errors.push('Left-click in gameplay did not trigger Punch');
  }
  const beforeMouseKick = combatStarts.length;
  await page.mouse.click(700, 420, { button: 'right' });
  await page.waitForTimeout(500);
  if (!combatStarts.slice(beforeMouseKick).some(line => line.includes('id=kick'))) {
    errors.push('Right-click in gameplay did not trigger Kick');
  }
  const beforeHudClick = combatStarts.length;
  await page.mouse.click(94, 169);
  await page.waitForTimeout(400);
  if (combatStarts.length !== beforeHudClick) {
    errors.push('Clicking a HUD view button unexpectedly activated Punch');
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_D05_MOUSE_OK punch=1 kick=1 hud_blocked=1');

  // D06 real browser input: E/Q/G manage equipment. The Bat uses
  // separate left/vertical and right/horizontal attack definitions,
  // whereas Shovel still uses a left swing with right-side Kick.
  // No extra attack key or test-only gameplay input is needed.
  await page.keyboard.press('2');
  await page.waitForTimeout(300);
  const firstEquipIndex = weaponEvents.length;
  await page.keyboard.press('e', { delay: 120 });
  await page.waitForTimeout(350);
  await page.keyboard.press('e', { delay: 120 });
  await page.waitForTimeout(350);
  const pickups = weaponEvents.slice(firstEquipIndex).filter(s => s.includes('ACTION5_WEAPON_PICKUP'));
  if (pickups.length !== 2 || pickups[0] === pickups[1]) {
    errors.push('D06 E-key did not pick up two different weapon definitions: ' +
      pickups.join(' | '));
  }
  await page.keyboard.press('q');
  await page.waitForTimeout(350);
  const equipped = weaponEvents.filter(s => s.includes('ACTION5_WEAPON_EQUIPPED'));
  if (equipped.length < 2 || equipped.at(-1) === equipped[0] ||
      !equipped.at(-1).includes('meshes=2 f4_visual=1')) {
    errors.push('D06 Q-key did not swap to the second multi-mesh weapon: ' +
      equipped.join(' | '));
  }
  // Pickups have equal range, so selection order is nondeterministic.
  // After proving swap, select the Bat explicitly using the normal Q
  // input so the browser exercises BOTH attacks on one equipped item.
  let selectedWeapon = equipped.at(-1).match(/id=(bat|shovel)(?:\s|$)/)?.[1];
  if (selectedWeapon === 'shovel') {
    await page.keyboard.press('q');
    await page.waitForTimeout(400);
    selectedWeapon = weaponEvents.filter(
      s => s.includes('ACTION5_WEAPON_EQUIPPED')).at(-1)
      ?.match(/id=(bat|shovel)(?:\s|$)/)?.[1];
  }
  if (selectedWeapon !== 'bat') {
    errors.push('D06 could not select Bat using the two independent pickup slots: ' +
      weaponEvents.join(' | '));
  }
  const expectedAction = 'bat_swing';
  const expectedSecondaryAction = 'bat_horizontal';
  const beforeRight = combatStarts.length;
  await page.mouse.click(700, 420, { button: 'right' });
  await page.waitForTimeout(850);
  const fromRight = combatStarts.slice(beforeRight);
  if (fromRight.length !== 1 ||
      !fromRight[0].includes('id=' + expectedSecondaryAction)) {
    errors.push('D06 Bat right click must start horizontal strike, not Kick: ' +
      fromRight.join(' | '));
  }
  const beforeLeft = combatStarts.length;
  await page.mouse.click(700, 420, { button: 'left' });
  await page.waitForTimeout(850);
  const fromLeft = combatStarts.slice(beforeLeft);
  if (fromLeft.length !== 1 || !fromLeft[0].includes('id=' + expectedAction)) {
    errors.push('D06 left-click must also use the selected weapon: ' +
      fromLeft.join(' | '));
  }
  // Both keyboard equivalents must route through the identical InputMap
  // selection policy, with no dedicated swing key or weapon-ID dispatcher.
  const beforeBatJ = combatStarts.length;
  await page.keyboard.press('j');
  await page.waitForTimeout(650);
  if (combatStarts.slice(beforeBatJ).length !== 1 ||
      !combatStarts.at(-1).includes('id=bat_swing')) {
    errors.push('D06 equipped Bat J must use vertical swing');
  }
  const beforeBatK = combatStarts.length;
  await page.keyboard.press('k');
  await page.waitForTimeout(650);
  if (combatStarts.slice(beforeBatK).length !== 1 ||
      !combatStarts.at(-1).includes('id=bat_horizontal')) {
    errors.push('D06 equipped Bat K must use horizontal swing');
  }

  await page.keyboard.press('3');
  await page.waitForTimeout(450);
  await page.screenshot({ path: 'build/evidence/web-d06-world-equipped.png', fullPage: true });
  // In pointer-locked F4, do not let Playwright's cursor jump from its last
  // F2 click position to a different F4 click position. That generates a
  // synthetic-look delta and can pitch the camera into the empty sky.
  await page.mouse.move(640, 360);
  await page.keyboard.press('4');
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'build/evidence/web-d06-f4-equipped.png', fullPage: true });
  const beforeF4Attack = combatStarts.length;
  await page.mouse.down({ button: 'left' });
  await page.waitForTimeout(150);
  await page.screenshot({ path: 'build/evidence/web-d06-f4-swing.png', fullPage: true });
  // The first F4 attack may also capture the mouse. Synthetic warp events
  // must not pitch the camera into a black/empty world. This asserts a
  // real rendered world pixel, not just a successful combat-start log.
  async function requireReadableF4(label) {
    const rgb = await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      const mirror = document.createElement('canvas');
      mirror.width = canvas.width;
      mirror.height = canvas.height;
      const ctx = mirror.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(canvas, 0, 0);
      const px = ctx.getImageData(
        Math.floor(canvas.width * 0.50), Math.floor(canvas.height * 0.51), 1, 1).data;
      return px[0] + px[1] + px[2];
    });
    if (rgb < 60) {
      errors.push('D06 F4 camera lost the visible arena after ' + label +
        ' (center RGB sum=' + rgb + ')');
    }
  }
  await requireReadableF4('Bat primary pointer capture');
  await page.mouse.up({ button: 'left' });
  await page.waitForTimeout(850);
  const f4Starts = combatStarts.slice(beforeF4Attack);
  if (f4Starts.length !== 1 || !f4Starts[0].includes('id=' + expectedAction)) {
    errors.push('D06 F4 left-click did not use the selected weapon: ' + f4Starts.join(' | '));
  }
  // The secondary action must also drive the horizontal F4 grip pose.
  const beforeF4Horizontal = combatStarts.length;
  await page.mouse.down({ button: 'right' });
  await page.waitForTimeout(170);
  await page.screenshot({
    path: 'build/evidence/web-d06-f4-bat-horizontal.png', fullPage: true,
  });
  await requireReadableF4('Bat horizontal action');
  await page.mouse.up({ button: 'right' });
  await page.waitForTimeout(850);
  const f4HorizontalStarts = combatStarts.slice(beforeF4Horizontal);
  if (f4HorizontalStarts.length !== 1 ||
      !f4HorizontalStarts[0].includes('id=' + expectedSecondaryAction)) {
    errors.push('D06 equipped F4 right-click did not start Bat horizontal: ' +
      f4HorizontalStarts.join(' | '));
  }

  // Shovel is a one-action weapon. Swap through Q, not a script-only
  // equipment hook, and prove right click/K still executes ordinary Kick
  // in BOTH world and camera-local first-person rendering.
  await page.keyboard.press('q');
  await page.waitForTimeout(460);
  const currentShovel = weaponEvents.filter(
    s => s.includes('ACTION5_WEAPON_EQUIPPED')).at(-1) || '';
  if (!currentShovel.includes('id=shovel')) {
    errors.push('D06 Q swap failed to equip single-action Shovel: ' + currentShovel);
  }
  await page.keyboard.press('2');
  await page.waitForTimeout(400);
  async function checkShovelInput(input, action, label) {
    const before = combatStarts.length;
    if (input === 'left' || input === 'right') {
      await page.mouse.click(700, 420, { button: input });
    } else {
      await page.keyboard.press(input);
    }
    await page.waitForTimeout(780);
    const started = combatStarts.slice(before);
    if (started.length !== 1 || !started[0].includes('id=' + action)) {
      errors.push('D06 ' + label + ' must start ' + action + ': ' +
        started.join(' | '));
    }
  }
  await checkShovelInput('left', 'shovel_swing', 'F2 Shovel LMB');
  await checkShovelInput('right', 'kick', 'F2 Shovel RMB');
  await checkShovelInput('j', 'shovel_swing', 'F2 Shovel J');
  await checkShovelInput('k', 'kick', 'F2 Shovel K');

  await page.mouse.move(640, 360);
  await page.keyboard.press('4');
  await page.waitForTimeout(450);
  const beforeShovelF4 = combatStarts.length;
  await page.mouse.down({ button: 'left' });
  await page.waitForTimeout(160);
  await page.screenshot({
    path: 'build/evidence/web-d06-f4-shovel-overhead.png', fullPage: true,
  });
  await requireReadableF4('Shovel overhead action');
  await page.mouse.up({ button: 'left' });
  await page.waitForTimeout(730);
  const shovelF4Starts = combatStarts.slice(beforeShovelF4);
  if (shovelF4Starts.length !== 1 ||
      !shovelF4Starts[0].includes('id=shovel_swing')) {
    errors.push('D06 F4 Shovel LMB did not start its overhead swing: ' +
      shovelF4Starts.join(' | '));
  }
  const beforeF4Kick = combatStarts.length;
  await page.mouse.down({ button: 'right' });
  await page.waitForTimeout(150);
  await page.screenshot({
    path: 'build/evidence/web-d06-f4-shovel-kick.png', fullPage: true,
  });
  await requireReadableF4('Shovel unassigned Kick');
  await page.mouse.up({ button: 'right' });
  await page.waitForTimeout(750);
  if (combatStarts.slice(beforeF4Kick).length !== 1 ||
      !combatStarts.at(-1).includes('id=kick')) {
    errors.push('D06 F4 Shovel RMB must retain normal Kick');
  }
  console.log('ACTION5_BROWSER_D06_DUAL_INPUT_OK bat=2 shovel=1 shovel_kick=1 views=2,4 keyboards=1');

  await page.evaluate(() => {
    const gameCanvas = document.querySelector('canvas');
    const mirror = document.createElement('canvas');
    mirror.width = gameCanvas.width;
    mirror.height = gameCanvas.height;
    const ctx = mirror.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(gameCanvas, 0, 0);
    const bounds = {
      x: Math.floor(mirror.width * 0.50), y: Math.floor(mirror.height * 0.44),
      w: Math.floor(mirror.width * 0.44), h: Math.floor(mirror.height * 0.51),
    };
    window.__d06Visual = {
      mirror, bounds,
      equipped: ctx.getImageData(bounds.x, bounds.y, bounds.w, bounds.h).data,
    };
  });

  await page.keyboard.press('g');
  await page.waitForTimeout(400);
  // One item remains stowed. Q must equip it even though the current
  // slot is empty, so the player can drop both and return to D05 baseline.
  await page.keyboard.press('q');
  await page.waitForTimeout(400);
  await page.keyboard.press('g');
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'build/evidence/web-d06-f4-dropped.png', fullPage: true });
  await requireReadableF4('dropping both weapons');
  const changedD06 = await page.evaluate(() => {
    const gameCanvas = document.querySelector('canvas');
    const state = window.__d06Visual;
    const ctx = state.mirror.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(gameCanvas, 0, 0);
    const current = ctx.getImageData(
      state.bounds.x, state.bounds.y, state.bounds.w, state.bounds.h).data;
    let changed = 0;
    for (let i = 0; i < current.length; i += 16) {
      if (Math.abs(current[i] - state.equipped[i]) +
          Math.abs(current[i + 1] - state.equipped[i + 1]) +
          Math.abs(current[i + 2] - state.equipped[i + 2]) > 75) changed++;
    }
    delete window.__d06Visual;
    return changed;
  });
  const drops = weaponEvents.filter(s => s.includes('ACTION5_WEAPON_DROPPED'));
  if (drops.length !== 2 || drops.some(s => !s.includes('f4_visual=0')) ||
      changedD06 < 50) {
    errors.push('D06 drop/F4 visual cleanup failed: drops=' + drops.join(' | ') +
      ' changed_pixels=' + changedD06);
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_D06_EQUIPMENT_OK pickup=2 swap=1 mouse=2 f4_swing=1 drop=2 f4=1 pixels=' +
    changedD06);

  // F4 always shows the articulated arm, which punches. Kick adds a
  // lower-framed leg without the obsolete tool. Input
  // remains real keyboard events; no script bridge or synthetic pose.
  await page.keyboard.press('4');
  await page.waitForTimeout(400);
  const f4NoAttack = await page.screenshot();

  // Browser software WebGL2 may render an entire 250 ms action while
  // Playwright waits for a compositor screenshot. Read each REAL rendered
  // canvas frame in-page instead: no synthetic combat action, game hook,
  // pose injection or alternate animation clock is involved.
  await page.evaluate(async () => {
    const canvas = document.querySelector('canvas');
    const mirror = document.createElement('canvas');
    mirror.width = canvas.width;
    mirror.height = canvas.height;
    const ctx = mirror.getContext('2d', { willReadFrequently: true });
    const bounds = {
      x: Math.floor(mirror.width * 0.30),
      y: Math.floor(mirror.height * 0.33),
      w: Math.floor(mirror.width * 0.58),
      h: Math.floor(mirror.height * 0.60),
    };
    const read = () => {
      ctx.drawImage(canvas, 0, 0);
      return ctx.getImageData(bounds.x, bounds.y, bounds.w, bounds.h).data;
    };
    // Read the idle baseline after a real render, not between frame swaps.
    await new Promise(resolve => requestAnimationFrame(resolve));
    const baseline = read();
    const state = { running: true, best: null, maxChanged: 0, frames: 0 };
    state.reset = () => {
      state.best = null;
      state.maxChanged = 0;
      state.frames = 0;
    };
    state.take = () => ({
      png: state.best,
      changed: state.maxChanged,
      frames: state.frames,
    });
    window.__action5F4Capture = state;
    function sample() {
      if (!state.running) return;
      const pixels = read();
      let changed = 0;
      for (let y = 0; y < bounds.h; y += 4) {
        for (let x = 0; x < bounds.w; x += 4) {
          const i = (y * bounds.w + x) * 4;
          if (Math.abs(pixels[i] - baseline[i]) +
              Math.abs(pixels[i + 1] - baseline[i + 1]) +
              Math.abs(pixels[i + 2] - baseline[i + 2]) > 50) {
            changed++;
          }
        }
      }
      state.frames++;
      if (changed >= 45 && changed > state.maxChanged + 10) {
        state.maxChanged = changed;
        state.best = mirror.toDataURL('image/png');
      }
      requestAnimationFrame(sample);
    }
    requestAnimationFrame(sample);
  });

  async function captureActiveF4(actionKey, visualKey, path) {
    await page.evaluate(() => window.__action5F4Capture.reset());
    const from = limbVisibility.length;
    await page.keyboard.down(actionKey);
    let sawActive = false;
    for (let wait = 0; wait < 100; wait++) {
      if (limbVisibility.slice(from).some(line => line.includes('key=' + visualKey))) {
        sawActive = true;
        break;
      }
      await page.waitForTimeout(25);
    }
    // Let the frame sampler collect at least the next composited frame.
    await page.waitForTimeout(150);
    await page.keyboard.up(actionKey);
    const evidence = await page.evaluate(() => window.__action5F4Capture.take());
    console.log('ACTION5_BROWSER_F4_FRAME action=' + visualKey +
      ' frames=' + evidence.frames + ' changed=' + evidence.changed +
      ' event=' + Number(sawActive));
    if (!sawActive || !evidence.png || evidence.changed < 45) {
      errors.push('No active WebGL2 frame for ' + visualKey +
        ' (changed=' + evidence.changed + ', frames=' + evidence.frames + ')');
      return null;
    }
    await writeFile(path, Buffer.from(evidence.png.split(',')[1], 'base64'));
    return evidence;
  }

  const f4Punch = await captureActiveF4(
    'j', 'punch', 'build/evidence/web-f4-combat-punch.png');
  await page.waitForTimeout(500);
  const f4Kick = await captureActiveF4(
    'k', 'kick', 'build/evidence/web-f4-combat-kick.png');
  await page.evaluate(() => { window.__action5F4Capture.running = false; });
  if (!f4Punch || !f4Kick) {
    errors.push('F4 rendered punches/kicks are missing despite real J/K input; ' +
      limbVisibility.join(' | '));
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_F4_COMBAT_LIMBS_OK punch_arm=1 kick_leg=1 screenshots=2');

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



  // The articulated resting F4 arm stays present during jumping; the
  // old fake forearm and training tool are never instantiated.
  await page.keyboard.press('4');
  await page.waitForTimeout(550);
  const f4Standing = await page.screenshot({
    path: 'build/evidence/web-f4-arm-standing.png', fullPage: true,
  });
  await page.keyboard.down(' ');
  await page.waitForTimeout(225);
  const f4Jumping = await page.screenshot({
    path: 'build/evidence/web-f4-arm-jumping.png', fullPage: true,
  });
  await page.keyboard.up(' ');
  if (createHash('sha256').update(f4Standing).digest('hex') ===
      createHash('sha256').update(f4Jumping).digest('hex')) {
    errors.push('F4 jump screenshot did not change after real Space input');
  }
  if (!rigViews.some(line => line.includes('view=4 body_hidden=1 rig=1 tool=1') &&
      line.includes('viewmodel=1'))) {
    errors.push('F4 persistent camera-local arm was not presented');
  }
  if (errors.length) throw Error(errors.join('\\n'));
  console.log('ACTION5_BROWSER_F4_JUMP_ARM_OK viewmodel=1 screenshots=2');

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

  // VT-12: F4 correctly preserves manual mouse yaw if the actor has
  // not changed facing since last leaving F4. Establish a known EAST FPS
  // exit heading, then turn NORTH in F2, so the *real* F4 entry contract
  // must align with that newly changed heading. Finally drive the actor
  // against NorthWall in F4; no teleport or test-only game hooks.
  await page.keyboard.press('2');
  await page.keyboard.down('d');
  await page.waitForTimeout(420);
  await page.keyboard.up('d');
  await page.keyboard.press('4');
  await page.waitForTimeout(200);
  await page.keyboard.press('2');
  await page.waitForTimeout(150);
  await page.keyboard.down('w');
  await page.waitForTimeout(450);
  await page.keyboard.press('4');
  await page.waitForTimeout(350);
  await page.keyboard.down('Shift');
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
