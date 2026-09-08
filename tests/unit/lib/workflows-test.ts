import { module, test } from 'qunit';
import { getToolById } from 'delphitools-v2/lib/tools';
import {
	CUSTOM_PREFIX,
	START_TOOLS,
	WORKFLOWS,
	canFollow,
	customWorkflow,
	getWorkflowById,
	nextTools,
	pendingFor,
	workflowFromPath,
	workflowTools,
} from 'delphitools-v2/lib/workflows';

const item = (name: string, type: string) => ({
	file: new File(['x'], name, { type }),
});

module('Unit | lib | workflows', function () {
	test('every step names a registry tool that can take a hand-off', function (assert) {
		for (const workflow of WORKFLOWS) {
			assert.strictEqual(
				workflowTools(workflow).length,
				workflow.steps.length,
				`${workflow.id}: every step resolves`,
			);
			for (const id of workflow.steps.slice(1)) {
				const tool = getToolById(id)!;
				const takesHandoff =
					Boolean(tool.accepts?.length) ||
					tool.carryColour === true;
				assert.true(
					takesHandoff,
					`${workflow.id}: ${id} accepts files or a colour`,
				);
			}
		}
		assert.strictEqual(
			new Set(WORKFLOWS.map((w) => w.id)).size,
			WORKFLOWS.length,
			'ids are unique',
		);
	});

	test('every listed workflow is a valid custom chain', function (assert) {
		for (const workflow of WORKFLOWS)
			assert.ok(customWorkflow(workflow.steps), workflow.id);
	});

	test('custom chains follow produces into accepts', function (assert) {
		const tool = (id: string) => getToolById(id)!;
		assert.ok(customWorkflow(['video-trimmer', 'video-to-gif']));
		assert.notOk(
			customWorkflow(['video-trimmer', 'pdf-compressor']),
			'a video does not enter a pdf tool',
		);
		assert.notOk(customWorkflow(['image-masker']), 'one step');
		assert.notOk(
			customWorkflow([
				'paste-image',
				'metadata-stripper',
				'image-compressor',
				'social-cropper',
			]),
			'four steps',
		);
		assert.notOk(
			customWorkflow(['substrata', 'image-compressor']),
			'routed tools stay out',
		);
		assert.notOk(customWorkflow(['image-compressor', 'substrata']));
		assert.notOk(customWorkflow(['nope', 'image-compressor']));
		assert.ok(
			customWorkflow([
				'pixel-picker',
				'gradient-genny',
				'image-compressor',
			]),
			'colour, then png',
		);
		assert.notOk(
			customWorkflow(['pixel-picker', 'image-compressor']),
			'a colour is not an image',
		);
		assert.ok(
			customWorkflow(['auto-subtitle', 'subtitle-converter']),
			'extension-only accepts',
		);
		assert.ok(
			customWorkflow(['voice-recorder', 'audio-normaliser']),
		);
		assert.false(
			canFollow(
				tool('voice-recorder'),
				tool('video-trimmer'),
			),
			'audio webm is not video',
		);
		assert.ok(customWorkflow(['pdf-organiser', 'pdf-compressor']));
		assert.notOk(
			customWorkflow(['video-trimmer', 'video-atlas']),
			'a viewer cannot end a chain',
		);
		assert.true(
			START_TOOLS.every(
				(t) =>
					t.produces?.length &&
					!t.route &&
					!t.external,
			),
		);
		const afterRecording = nextTools(tool('screen-recorder')).map(
			(t) => t.id,
		);
		assert.true(afterRecording.includes('video-trimmer'));
		assert.false(afterRecording.includes('image-compressor'));
		assert.deepEqual(nextTools(tool('word-counter')), []);
	});

	test('custom ids round-trip through getWorkflowById and the path', function (assert) {
		const steps = ['paste-image', 'metadata-stripper'];
		const custom = customWorkflow(steps)!;
		assert.strictEqual(
			custom.id,
			`${CUSTOM_PREFIX}${steps.join('.')}`,
		);
		assert.deepEqual(getWorkflowById(custom.id), custom);
		assert.deepEqual(workflowFromPath(steps.join('.')), custom);
		assert.strictEqual(
			workflowFromPath('paste-image.pdf-compressor'),
			undefined,
		);
		assert.strictEqual(workflowFromPath(''), undefined);
		assert.strictEqual(getWorkflowById('custom:'), undefined);
	});

	test('pendingFor takes the newest match per accept pattern, once', function (assert) {
		const a = item('a.png', 'image/png');
		const b = item('b.png', 'image/png');
		const v = item('cut.webm', 'video/webm');
		const s = item('cues.srt', '');
		const bag = [a, v, b, s];

		assert.deepEqual(
			pendingFor(bag, 'image/*'),
			[b],
			'newest image',
		);
		assert.deepEqual(
			pendingFor(bag, 'video/*,.srt,.vtt'),
			[v, s],
			'one per pattern, bag order',
		);
		assert.deepEqual(
			pendingFor(bag, 'image/*,image/png'),
			[b],
			'two patterns hitting one file deliver it once',
		);
		assert.deepEqual(
			pendingFor(bag, '.pdf'),
			[],
			'nothing matches',
		);
		assert.deepEqual(
			pendingFor(bag),
			[s],
			'no accept list: newest file',
		);
		assert.deepEqual(pendingFor([], 'image/*'), [], 'empty bag');
	});
});
