import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {runInNewContext} from 'node:vm';
const script = await readFile(new URL('../../web/pwa.js', import.meta.url), 'utf8');

function shell(standalone = false) {
  const events = {};
  const buttons = [];
  runInNewContext(script, {
    console,
    window: {addEventListener: (name, fn) => events[name] = fn,
      matchMedia: () => ({matches: standalone})},
    navigator: {language: 'zh-CN'},
    document: {body: {append: node => buttons.push(node)}, createElement: () => ({
      style: {}, addEventListener(name, fn) { this[name] = fn; },
      remove() { buttons.splice(buttons.indexOf(this), 1); },
    })},
  });
  return {events, buttons};
}

test('install button invokes a browser prompt once and removes consumed event', async () => {
  const {events, buttons} = shell();
  let prompted = 0;
  let prevented = 0;
  const event = {preventDefault: () => prevented++, prompt: async () => prompted++,
    userChoice: Promise.resolve({outcome: 'dismissed'})};
  events.beforeinstallprompt(event);
  events.beforeinstallprompt(event);
  assert.equal(buttons.length, 1);
  assert.equal(buttons[0].textContent, '安装 Musaic');
  await buttons[0].click();
  assert.equal(prompted, 1);
  assert.equal(prevented, 2);
  assert.equal(buttons.length, 0);
});

test('installed app has no install button; appinstalled removes a pending button', () => {
  const installed = shell(true);
  installed.events.beforeinstallprompt({});
  assert.equal(installed.buttons.length, 0);
  const browser = shell();
  browser.events.beforeinstallprompt({preventDefault() {}});
  browser.events.appinstalled();
  assert.equal(browser.buttons.length, 0);
});

test('a rejected prompt is handled and cannot remove a newer install event', async () => {
  const {events, buttons} = shell();
  let reject;
  const choice = new Promise((_, fail) => reject = fail);
  events.beforeinstallprompt({preventDefault() {}, prompt: () => choice});
  const first = buttons[0].click();
  assert.equal(buttons.length, 0);
  events.beforeinstallprompt({preventDefault() {}, prompt: async () => {}, userChoice: Promise.resolve()});
  reject(Error('browser dismissed install'));
  await first;
  assert.equal(buttons.length, 1);
  await buttons[0].click();
  assert.equal(buttons.length, 0);
});
