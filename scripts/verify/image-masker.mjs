import { mkdtempSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch, visit, check, sleep, finish } from './harness.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '../..');
const work = mkdtempSync(join(tmpdir(), 'dt-masker-'));

// viewbox-only svg fixture
const svgPath = join(work, 'notch.svg');
writeFileSync(
	svgPath,
	'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><path d="M0 0H10V10H5V5H0Z"/></svg>',
);

const { browser, page } = await launch();
const cdp = await page.createCDPSession();
await cdp.send('Browser.setDownloadBehavior', {
	behavior: 'allow',
	downloadPath: work,
});
await visit(page, '/tools/image-masker');

const pixel = (x, y) =>
	page.evaluate(
		(x, y) => {
			const canvas = document.querySelector('.dt-masker-canvas');
			const ctx = canvas.getContext('2d');
			return [...ctx.getImageData(x, y, 1, 1).data];
		},
		x,
		y,
	);
const text = (selector) =>
	page.evaluate(
		(s) => document.querySelector(s)?.textContent.replace(/\s+/g, ' ').trim(),
		selector,
	);

check('grid starts folded', !(await page.$('.dt-masker-grid')));
await page.click('.dt-masker-toggle');
await sleep(400);
const grid = await page.evaluate(() => {
	const el = document.querySelector('.dt-masker-grid');
	return {
		cells: el.querySelectorAll('.dt-masker-cell').length,
		paths: el.querySelectorAll('path[d]').length,
		scrollsX: el.scrollWidth > el.clientWidth,
		scrollsY: el.scrollHeight > el.clientHeight,
	};
});
check(
	'grid has 12 variants per family',
	grid.cells >= 252 && grid.cells % 12 === 0,
	`${grid.cells}`,
);
check('every cell has a path', grid.paths === grid.cells);
check('grid scrolls on both axes', grid.scrollsX && grid.scrollsY);

const gridBox = await (await page.$('.dt-masker-grid')).boundingBox();
const scrollLeft = () =>
	page.evaluate(() => document.querySelector('.dt-masker-grid').scrollLeft);
const selectedBefore = await page.evaluate(
	() => document.querySelector('.dt-masker-cell.is-active')?.title,
);
await page.mouse.move(gridBox.x + 400, gridBox.y + 120);
await page.mouse.down();
for (let i = 1; i <= 10; i++) {
	await page.mouse.move(gridBox.x + 400 - i * 25, gridBox.y + 120);
	await sleep(16);
}
await page.mouse.up();
const atRelease = await scrollLeft();
await sleep(300);
const afterGlide = await scrollLeft();
const selectedAfter = await page.evaluate(
	() => document.querySelector('.dt-masker-cell.is-active')?.title,
);
check('mouse drag scrolls the grid', atRelease > 150, `${atRelease}`);
check(
	'release keeps gliding',
	afterGlide > atRelease + 5,
	`${atRelease} -> ${afterGlide}`,
);
check('drag does not select a cell', selectedBefore === selectedAfter, selectedAfter);

const before = await pixel(512, 512);
check('default shape paints the centre', before[3] === 255, before.join(','));
const corner = await pixel(2, 2);
check('outside the shape is transparent', corner[3] === 0, corner.join(','));

await page.click('.dt-masker-cell[title="Heart 1"]');
await sleep(200);
const current = await text('.dt-masker-current');
check('clicking a cell selects it', current === 'Heart 1', current);
const heartTop = await pixel(512, 60);
check('heart notch is transparent', heartTop[3] === 0, heartTop.join(','));

const zoomVertical = await page.evaluate(
	() => getComputedStyle(document.querySelector('.dt-masker-zoom input')).writingMode,
);
check('zoom slider is vertical', zoomVertical === 'vertical-lr', zoomVertical);

const imageInput = await page.$('.dt-masker-bar input[accept="image/*"]');
await imageInput.uploadFile(join(root, 'public/delphi.png'));
await sleep(600);
const dims = await text('.dt-masker-dims');
check('image loads and reports size', dims === '685 × 685', dims);
const painted = await pixel(512, 512);
check(
	'image replaces the placeholder',
	painted[3] === 255 && painted.slice(0, 3).join(',') !== '154,154,154',
	painted.join(','),
);
const summary = await text('.dt-masker-summary');
check('1x output matches the image pixels', summary === '685 × 685', summary);

await page.evaluate(() => {
	const input = document.querySelector('.dt-masker-zoom input');
	input.value = '0.4';
	input.dispatchEvent(new Event('input', { bubbles: true }));
});
await sleep(150);
const outsideImage = await pixel(300, 300);
check(
	'zoomed out, the mask stays grey where the image ends',
	outsideImage.join(',') === '154,154,154,255',
	outsideImage.join(','),
);
check('zoomed out, 1x output grows', (await text('.dt-masker-summary')) === '1713 × 1713');
await page.click('.dt-masker-icon-btn');
await sleep(100);

const svgInput = await page.$('.dt-masker-bar input[accept=".svg,image/svg+xml"]');
await svgInput.uploadFile(svgPath);
await sleep(600);
const svgState = await page.evaluate(() => ({
	label: document.querySelector('.dt-masker-current')?.textContent.trim(),
	active: !!document.querySelector('.dt-masker-cell.is-active'),
}));
check('svg upload becomes the mask', svgState.label === 'notch', svgState.label);
check('svg mask clears the grid selection', !svgState.active);
const notchHole = await pixel(200, 800);
const notchFill = await pixel(800, 200);
check(
	'svg alpha drives the mask',
	notchHole[3] === 0 && notchFill[3] === 255,
	`${notchHole[3]} ${notchFill[3]}`,
);

await page.evaluate(() =>
	[...document.querySelectorAll('.dt-masker-choice')]
		.find((b) => b.textContent.trim() === '2x')
		.click(),
);
await sleep(100);
check('2x doubles the output', (await text('.dt-masker-summary')) === '1370 × 1370');
await page.click('.dt-masker-download');
let file;
for (let i = 0; i < 40 && !file; i++) {
	await sleep(250);
	file = readdirSync(work).find((f) => f.endsWith('.png'));
}
check('download produces a png', !!file, file);
if (file) {
	const bytes = readFileSync(join(work, file));
	const width = bytes.readUInt32BE(16);
	const height = bytes.readUInt32BE(20);
	check('png header', bytes.subarray(1, 4).toString() === 'PNG');
	check('png is the chosen size', width === 1370 && height === 1370, `${width}x${height}`);
	check('filename carries image and mask', file === 'delphi-notch.png', file);
}

await page.screenshot({ path: join(work, 'image-masker.png'), fullPage: true });
console.log(`screenshot: ${join(work, 'image-masker.png')}`);

await finish(browser);
