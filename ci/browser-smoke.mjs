// Run with Playwright in CI after serving build/web on port 8765.
// An actual Chromium/WebGL canvas is required; loading index.html alone is insufficient.
import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';

const issues = [];
const browser = await chromium.launch({
  headless: true,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-webgl'],
});
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('pageerror', error => issues.push('pageerror: ' + error.message));
  page.on('console', message => {
    if (message.type() === 'error') issues.push('console: ' + message.text());
  });
  page.on('requestfailed', req => issues.push('request: ' + req.url() + ': ' + req.failure()?.errorText));
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
    issues.push('WebGL2 game canvas is unavailable or invalid');
  }
  if (issues.length) throw Error(issues.join('\n'));
  console.log('ACTION5_BROWSER_SMOKE_OK ' + url);
} finally {
  await browser.close();
}
