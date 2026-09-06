import type { TOC } from '@ember/component/template-only';
import { TOOLS } from 'delphitools-v2/components/substrata/omnibar/omnibar';

interface Row {
	keys: string;
	action: string;
}

const TOOL_ROWS: Row[] = TOOLS.flatMap((tool) =>
	tool.subs.map((sub) => ({ keys: sub.key, action: sub.label })),
);

// mirrors editor-shortcuts.ts
const GROUPS: { title: string; rows: Row[] }[] = [
	{ title: 'Tools', rows: TOOL_ROWS },
	{
		title: 'Edit',
		rows: [
			{ keys: '⌘Z', action: 'Undo' },
			{ keys: '⇧⌘Z / Ctrl+Y', action: 'Redo' },
			{ keys: '⌘A', action: 'Select all' },
			{ keys: '⌘D', action: 'Duplicate' },
			{ keys: '⌘G', action: 'Group' },
			{ keys: '⇧⌘G', action: 'Ungroup' },
			{ keys: '⌘]', action: 'Bring Forward' },
			{ keys: '⌘[', action: 'Send Backward' },
			{ keys: '⇧⌘]', action: 'Bring to Front' },
			{ keys: '⇧⌘[', action: 'Send to Back' },
			{ keys: '⌫', action: 'Delete selection' },
			{ keys: '← ↑ → ↓', action: 'Nudge selection (⇧ ×10)' },
			{ keys: '⏎', action: 'Extract pixel selection' },
			{ keys: 'Esc', action: 'Deselect / leave crop' },
		],
	},
	{
		title: 'Scene',
		rows: [
			{ keys: '⌘S', action: 'Save' },
			{ keys: '⇧⌘S', action: 'Save a copy' },
			{ keys: '⌘O', action: 'Open' },
			{ keys: '⌘I', action: 'Import image' },
			{ keys: '⌘E', action: 'Export' },
		],
	},
	{
		title: 'View',
		rows: [
			{ keys: '⌘0', action: 'Zoom to Fit' },
			{ keys: '⌘1', action: 'Zoom to 100%' },
			{ keys: 'Space + drag', action: 'Pan' },
			{ keys: 'Scroll', action: 'Pan' },
			{ keys: '⌘ Scroll / pinch', action: 'Zoom' },
			{
				keys: 'Two fingers (touch)',
				action: 'Pan + pinch zoom',
			},
		],
	},
];

const ShortcutsModal: TOC<object> = <template>
	<div class="sub-modal-frame is-wide">
		<div class="sub-modal-header">
			<h2 class="sub-modal-title">Keyboard shortcuts</h2>
		</div>
		<div class="sub-sc-grid">
			{{#each GROUPS key="title" as |group|}}
				<section>
					<div
						class="sub-modal-heading"
					>{{group.title}}</div>
					<table class="sub-sc-table">
						<tbody>
							{{#each
								group.rows
								key="@index"
								as |row|
							}}
								<tr>
									<td
										class="sub-sc-keys"
									>{{row.keys}}</td>
									<td
									>{{row.action}}</td>
								</tr>
							{{/each}}
						</tbody>
					</table>
				</section>
			{{/each}}
		</div>
	</div>
</template>;

export default ShortcutsModal;
