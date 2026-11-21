// Run after build_pwa.py: CHROME_EXECUTABLE=/path/to/chrome node test/web/pwa_browser_smoke.mjs
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {spawn} from 'node:child_process';
import {createServer} from 'node:http';
import {mkdtemp, readFile, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {resolve, join, extname} from 'node:path';

const root = resolve('build/web');
const profile = await mkdtemp(join(tmpdir(), 'musaic-pwa-'));
let online = true;
const overrides = new Map();
const requests = [];
const types = {'.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png'};
const server = createServer(async (request, response) => {
  if (!online) { response.writeHead(503).end(); return; }
  try {
    const path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    requests.push(path);
    const file = resolve(root, `.${path === '/' ? '/index.html' : path}`);
    if (!file.startsWith(root + '/')) throw Error('Outside build');
    response.setHeader('Content-Type', types[extname(file)] || 'application/octet-stream');
    response.setHeader('Cache-Control', 'no-cache');
    response.end(overrides.get(path) ?? await readFile(file));
  } catch { response.writeHead(404).end(); }
});
await new Promise(done => server.listen(0, '127.0.0.1', done));
const origin = `http://127.0.0.1:${server.address().port}`;
const chrome = spawn(process.env.CHROME_EXECUTABLE || 'google-chrome', [
  '--no-first-run', '--no-default-browser-check', '--lang=en-US',
  '--remote-debugging-port=0', `--user-data-dir=${profile}`, '--window-size=1100,700', 'about:blank',
], {stdio: 'ignore'});
let socket;
const sleep = ms => new Promise(done => setTimeout(done, ms));
async function until(check, description, timeout = 90000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    try { if (await check()) return; } catch { /* Navigation replaces the JS context. */ }
    await sleep(100);
  }
  throw Error(`Timed out: ${description}`);
}
try {
  let port;
  await until(async () => {
    try { port = (await readFile(join(profile, 'DevToolsActivePort'), 'utf8')).split('\n')[0]; return true; }
    catch { return false; }
  }, 'Chrome startup');
  const tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  socket = new WebSocket(tabs.find(tab => tab.type === 'page').webSocketDebuggerUrl);
  await new Promise(done => socket.addEventListener('open', done, {once: true}));
  let sequence = 0;
  const pending = new Map();
  socket.addEventListener('message', ({data}) => {
    const message = JSON.parse(data);
    if (!message.id) {
      if (message.method === 'Runtime.exceptionThrown') console.error(JSON.stringify(message.params.exceptionDetails));
      if (message.method === 'Network.responseReceived' && message.params.response.status >= 400) console.error(message.params.response.status, message.params.response.url);
      return;
    }
    const call = pending.get(message.id);
    pending.delete(message.id);
    message.error ? call.reject(Error(JSON.stringify(message.error))) : call.resolve(message.result);
  });
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    pending.set(id, {resolve, reject});
    socket.send(JSON.stringify({id, method, params}));
  });
  const evaluate = async expression => {
    const result = await send('Runtime.evaluate', {expression, awaitPromise: true, returnByValue: true, timeout: 90000});
    if (result.exceptionDetails) throw Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  };
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Network.enable');
  await send('Page.addScriptToEvaluateOnNewDocument', {source: "window.firstFrame = false; window.addEventListener('flutter-first-frame', () => window.firstFrame = true);"});
  await send('Page.navigate', {url: origin});
  await until(() => evaluate('window.firstFrame === true'), 'online Flutter first frame');
  console.log('Flutter first frame');
  await until(() => evaluate('navigator.serviceWorker.getRegistration().then(registration => registration?.active?.state === \"activated\")'), 'offline worker activation');
  console.log('Opening controlled page');
  await send('Page.navigate', {url: origin});
  console.log('Navigation requested');
  await until(() => evaluate('window.firstFrame && !!navigator.serviceWorker.controller'), 'first controlled page');
  console.log('First frame and worker activated');
  assert.deepEqual((await send('Page.getInstallabilityErrors')).installabilityErrors, []);
  assert.equal(await evaluate(`Array.from(document.querySelectorAll('button')).some(button => /^(Install Musaic|安装 Musaic)$/.test(button.textContent))`), false);
  console.log('Installability passed; no custom install button');
  const cachesBefore = await evaluate('caches.keys()');
  assert.equal(cachesBefore.filter(key => key.startsWith('musaic-pwa:')).length, 1);
  // Desktop browsers start on the canvas with the manual switch off.
  const viewport = await evaluate('({width: innerWidth, height: innerHeight})');
  await send('Page.bringToFront');
  await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");
  const clickAt = async (x, y) => {
    await send('Input.dispatchMouseEvent', {type: 'mousePressed', x, y, button: 'left', clickCount: 1});
    await send('Input.dispatchMouseEvent', {type: 'mouseReleased', x, y, button: 'left', clickCount: 1});
  };
  const labeledControl = label => evaluate(`(() => {
    for (const element of document.querySelectorAll('[aria-label],flt-semantics')) {
      const name = element.getAttribute('aria-label') || element.textContent;
      if (!name?.split('\\n').includes(${JSON.stringify(label)})) continue;
      const rect = element.getBoundingClientRect();
      const x = rect.x + rect.width / 2;
      const y = rect.y + rect.height / 2;
      if (rect.width && rect.height && x > 0 && y > 0 && x < innerWidth && y < innerHeight) {
        return {x, y};
      }
    }
    return null;
  })()`);
  const clickLabel = async label => {
    await until(() => labeledControl(label), label, 10000);
    const {x, y} = await labeledControl(label);
    await clickAt(x, y);
  };
  await until(() => labeledControl('Not playing'), 'desktop canvas', 10000);
  assert.equal(await labeledControl('切换到 CoverFlow'), null);
  const capsuleX = viewport.width / 2;
  const capsuleY = viewport.height - 64;
  for (let attempt = 0; attempt < 3 && !await labeledControl('Settings'); attempt++) {
    await send('Input.dispatchMouseEvent', {type: 'mouseMoved', x: capsuleX, y: capsuleY});
    await sleep(250);
    await send('Input.dispatchMouseEvent', {type: 'mousePressed', x: capsuleX, y: capsuleY, button: 'left', buttons: 1, clickCount: 1});
    for (let distance = 20; distance <= 160; distance += 20) {
      await send('Input.dispatchMouseEvent', {type: 'mouseMoved', x: capsuleX, y: capsuleY - distance, buttons: 1});
      await sleep(20);
    }
    await send('Input.dispatchMouseEvent', {type: 'mouseReleased', x: capsuleX, y: capsuleY - 160, button: 'left', clickCount: 1});
    await sleep(700);
  }
  await clickLabel('Settings');
  await sleep(450);
  await clickLabel('Appearance & display');
  await sleep(550);
  await clickLabel('Manual rotation');
  await until(() => labeledControl('Enter fullscreen'), 'fullscreen menu entry');
  await sleep(600);
  await clickLabel('Enter fullscreen');
  await until(() => evaluate('!!document.fullscreenElement'), 'enter fullscreen from menu');
  console.log('Menu fullscreen entry passed');
  await clickLabel('Exit fullscreen');
  await until(() => evaluate('!document.fullscreenElement'), 'exit fullscreen from menu');
  await until(() => labeledControl('Enter fullscreen'), 'exit state synchronized');
  console.log('Menu fullscreen exit passed');
  await sleep(2000);
  await clickLabel('Enter fullscreen');
  await until(() => evaluate('!!document.fullscreenElement'), 'reenter fullscreen');
  await evaluate('document.exitFullscreen()');
  await until(() => labeledControl('Enter fullscreen'), 'external fullscreen exit synchronized');
  await clickLabel('Back');
  await sleep(500);
  await clickAt(10, 10);
  await clickLabel('切换到 CoverFlow');
  await until(() => labeledControl('切换到画布'), 'Cover Flow return control', 10000);
  await sleep(1500);
  const screenshot = async name => {
    const result = await send('Page.captureScreenshot');
    await writeFile(join(tmpdir(), name), Buffer.from(result.data, 'base64'));
    return result.data;
  };
  await sleep(1000);
  // Restore focus to the album surface before exercising actual browser input.
  await send('Input.dispatchMouseEvent', {type: 'mousePressed', x: 550, y: 350, button: 'left', clickCount: 1});
  await send('Input.dispatchMouseEvent', {type: 'mouseReleased', x: 550, y: 350, button: 'left', clickCount: 1});
  await sleep(1500);
  const initial = await screenshot('musaic-pwa-online.png');
  await send('Input.dispatchKeyEvent', {type: 'keyDown', key: 'ArrowRight', code: 'ArrowRight', windowsVirtualKeyCode: 39});
  await send('Input.dispatchKeyEvent', {type: 'keyUp', key: 'ArrowRight', code: 'ArrowRight', windowsVirtualKeyCode: 39});
  await sleep(1500);
  const keyed = await screenshot('musaic-pwa-keyboard.png');
  assert.ok(keyed !== initial, 'Arrow key must visibly change the album');
  await send('Input.dispatchMouseEvent', {type: 'mouseWheel', x: 550, y: 350, deltaX: 250, deltaY: 0});
  await sleep(1500);
  assert.ok(await screenshot('musaic-pwa-trackpad.png') !== keyed, 'Horizontal scroll must change the album');
  await send('Input.dispatchMouseEvent', {type: 'mouseMoved', x: viewport.width - 38, y: viewport.height - 38});
  await clickLabel('切换到画布');
  await until(() => labeledControl('切换到 CoverFlow'), 'return to canvas', 10000);
  // Acquire the first worker without claiming a page midway through loading.
  await send('Page.reload');
  await until(() => evaluate('window.firstFrame && !!navigator.serviceWorker.controller'), 'controlled page');
  await evaluate("document.querySelector('flt-semantics-placeholder')?.click()");
  await until(() => labeledControl('切换到 CoverFlow'), 'saved manual rotation', 10000);
  console.log('Manual rotation switches in both directions and survives reload');
  const originalScript = await readFile(join(root, 'pwa.js'), 'utf8');
  const updatedScript = originalScript + '\n// upgrade smoke test\n';
  const worker = await readFile(join(root, 'service-worker.js'), 'utf8');
  const files = JSON.parse(worker.match(/const FILES = (.*);/)[1]);
  files.find(file => file.path === 'pwa.js').integrity = 'sha256-' + createHash('sha256').update(updatedScript).digest('base64');
  overrides.set('/service-worker.js', worker.replace(/const VERSION = .*;/, 'const VERSION = "upgrade-smoke";').replace(/const FILES = .*;/, `const FILES = ${JSON.stringify(files)};`));
  const update = () => evaluate(`(async () => {
    const registration = await navigator.serviceWorker.getRegistration();
    await registration.update();
    const worker = registration.installing;
    if (!worker) return registration.waiting ? 'installed' : 'none';
    if (['installed', 'redundant'].includes(worker.state)) return worker.state;
    return new Promise(resolve => worker.addEventListener('statechange', () => {
      if (['installed', 'redundant'].includes(worker.state)) resolve(worker.state);
    }));
  })()`);
  // A partially deployed release must fail integrity and preserve the usable cache.
  overrides.set('/pwa.js', originalScript + '\n// incorrect deployment\n');
  assert.equal(await update(), 'redundant');
  assert.deepEqual(await evaluate('caches.keys()'), cachesBefore);
  overrides.set('/pwa.js', updatedScript);
  requests.length = 0;
  assert.equal(await update(), 'installed');
  assert.deepEqual(requests.filter(path => path !== '/service-worker.js'), ['/pwa.js']);
  assert.equal(await evaluate("fetch('pwa.js').then(response => response.text())"), originalScript);
  assert.equal((await evaluate('caches.keys()')).length, 2);
  await send('Page.navigate', {url: 'about:blank'});
  await sleep(1000);
  await send('Page.navigate', {url: origin});
  await until(() => evaluate('window.firstFrame && !!navigator.serviceWorker.controller'), 'upgraded app');
  await until(async () => (await evaluate('caches.keys()')).length === 1, 'old cache cleanup');
  assert.equal(await evaluate("fetch('pwa.js').then(response => response.text())"), updatedScript);
  console.log('PASS: mixed deployment rejected; upgrade downloads only one changed asset; old tab stays consistent');
  // Disable the origin, not just the page network: workers must also be offline.
  console.log('Online interaction and installability passed; reloading offline');
  online = false;
  const beforeReload = await evaluate('performance.timeOrigin');
  await send('Network.setCacheDisabled', {cacheDisabled: true});
  await send('Page.reload');
  await until(() => evaluate(`window.firstFrame === true && performance.timeOrigin > ${beforeReload}`), 'offline Flutter first frame');
  await sleep(1500);
  await screenshot('musaic-pwa-offline.png');
  console.log('PASS: installable, keyboard, horizontal scroll, and offline reload');
} finally {
  socket?.close();
  chrome.kill();
  await new Promise(done => chrome.exitCode !== null ? done() : chrome.once('exit', done));
  server.closeAllConnections();
  await new Promise(done => server.close(done));
  await rm(profile, {recursive: true, force: true});
}
