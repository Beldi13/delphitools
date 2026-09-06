import { BASE, check, finish, launch, sleep } from './harness.mjs';

const { browser, page } = await launch();

const measure = () =>
	page.evaluate(() => {
		const btn = document.querySelector('.dt-404-home');
		const tile = document.querySelector('.dt-404-bottom-tile');
		if (!btn || !tile) return null;
		return Math.round(
			tile.getBoundingClientRect().top - btn.getBoundingClientRect().bottom,
		);
	});

for (const [path, w, h] of [
	['/qr-gennyy', 1920, 950],
	['/tools/qr-gennyy', 1366, 650],
	['/tools/qr-gennyy', 390, 700],
]) {
	await page.setViewport({ width: w, height: h });
	await page.goto(`${BASE}${path}`, { waitUntil: 'networkidle0' });
	await sleep(300);
	const gap = await measure();
	check(`${path} at ${w}x${h} renders the 404 page`, gap !== null);
	check(`${path} at ${w}x${h} keeps the button clear of the art`, gap > 0, `${gap}px`);
}

await finish(browser);
