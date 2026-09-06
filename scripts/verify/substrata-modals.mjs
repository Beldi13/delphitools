import { readFileSync } from 'node:fs';
import puppeteer from 'puppeteer-core';

const VERSION = JSON.parse(
	readFileSync(new URL('../../package.json', import.meta.url), 'utf8'),
).version;
const EDITOR_URL = process.env.EDITOR_URL ?? 'http://localhost:3000/editor';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let failures = 0;
const check = (label, ok, detail = '') => {
	console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${detail ? `  [${detail}]` : ''}`);
	if (!ok) failures++;
};

const browser = await puppeteer.launch({
	executablePath:
		'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
	headless: 'new',
	args: ['--window-size=1500,950'],
});
const page = await browser.newPage();
await page.setViewport({ width: 1460, height: 900 });
page.on('pageerror', (e) => console.log('PAGEERROR:', e.message));
page.on('dialog', (d) => d.accept());
await page.goto(EDITOR_URL, { waitUntil: 'networkidle0' });
await page.waitForFunction(() => window.__substrata, { timeout: 20000 });
await sleep(400);

const dialogOpen = () =>
	page.evaluate(
		() => document.querySelector('dialog.sub-modal')?.open ?? false,
	);
const has = (selector) =>
	page.evaluate((s) => !!document.querySelector(s), selector);
const clickText = async (selector, text) => {
	const hit = await page.evaluate(
		([s, t]) => {
			const el = [...document.querySelectorAll(s)].find(
				(e) => e.textContent.trim() === t,
			);
			if (!el) return false;
			el.click();
			return true;
		},
		[selector, text],
	);
	if (!hit) throw new Error(`no ${selector} with text "${text}"`);
	await sleep(200);
};
const menu = (label) => clickText('.sub-topbar-menu-btn', label);
const item = (label) => clickText('.sub-topbar-item-label', label);
const escape = async () => {
	await page.keyboard.press('Escape');
	await sleep(200);
};

check('editor starts with no modal', !(await dialogOpen()));

await menu('Scene');
await item('Export…');
check('scene > export opens the export modal', await dialogOpen());
check('export modal renders its options', await has('.sub-exp-seg'));
await escape();
check('escape closes it', !(await dialogOpen()));

await page.click('.sub-topbar-export');
await sleep(200);
check('top-bar export button opens it too', await dialogOpen());
await clickText('.sub-modal-btn.is-ghost', 'Cancel');
check('cancel closes it', !(await dialogOpen()));

await page.keyboard.down('Meta');
await page.keyboard.press('e');
await page.keyboard.up('Meta');
await sleep(200);
check('cmd+e opens it', await dialogOpen());
await clickText('.sub-modal-btn.is-primary', 'Export');
await page
	.waitForFunction(
		() => !document.querySelector('dialog.sub-modal').open,
		{ timeout: 8000 },
	)
	.catch(() => {});
check('export runs and closes the modal', !(await dialogOpen()));

await menu('Help');
await item('Keyboard shortcuts');
check('help > keyboard shortcuts opens', await has('.sub-sc-grid'));
await escape();

await menu('Help');
await item('About Substrata');
const version = await page
	.$eval('.sub-about-version', (el) => el.textContent.trim())
	.catch(() => '');
check(
	'help > about substrata shows the package version',
	version === `v${VERSION}`,
	version,
);
await escape();

await menu('Help');
await item('About delphitools');
check(
	'help > about delphitools shows the shared body',
	await has('.sub-modal .dt-about-body'),
);
await escape();
check('nothing left open', !(await dialogOpen()));

await browser.close();
console.log(failures ? `\nFAILURES: ${failures}` : '\nALL PASS');
process.exitCode = failures ? 1 : 0;
