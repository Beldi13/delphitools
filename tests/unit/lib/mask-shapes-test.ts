import { module, test } from 'qunit';
import {
	DEFAULT_MASK,
	MASK_COLUMNS,
	MASK_SHAPES,
	VARIANTS,
} from 'delphitools-v2/lib/mask-shapes';

const family = (id: string) => id.replace(/-\d+$/, '');

module('Unit | lib | mask-shapes', function () {
	test('every shape is a closed path inside the box', function (assert) {
		assert.strictEqual(MASK_SHAPES.length, MASK_COLUMNS * VARIANTS);
		const ids = new Set<string>();
		const perFamily = new Map<string, number>();
		for (const shape of MASK_SHAPES) {
			ids.add(shape.id);
			perFamily.set(
				family(shape.id),
				(perFamily.get(family(shape.id)) ?? 0) + 1,
			);
			assert.ok(/^M[\d.\s\-LCZM]+Z$/.test(shape.d), shape.id);
			const numbers = shape.d.match(/-?\d+(?:\.\d+)?/g) ?? [];
			assert.ok(numbers.length >= 6, shape.id);
			const outOfBox = numbers
				.map(Number)
				.filter((n) => n < -0.5 || n > 100.5);
			assert.deepEqual(outOfBox, [], shape.id);
		}
		assert.strictEqual(ids.size, MASK_SHAPES.length);
		assert.ok([...perFamily.values()].every((n) => n === VARIANTS));
		assert.ok(MASK_SHAPES.includes(DEFAULT_MASK));
	});

	test('the sheet is shuffled', function (assert) {
		const firstColumn = new Set(
			MASK_SHAPES.filter(
				(_, i) => i % MASK_COLUMNS === 0,
			).map((shape) => family(shape.id)),
		);
		assert.ok(firstColumn.size > 1);
	});
});
