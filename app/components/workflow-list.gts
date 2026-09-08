import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { LinkTo } from '@ember/routing';
import { service } from '@ember/service';
import { eq } from 'ember-truth-helpers';
import Icon from 'delphitools-v2/components/icon';
import {
	Select,
	SelectContent,
	SelectItem,
	SelectTrigger,
	SelectValue,
} from 'delphitools-v2/components/ui/select';
import {
	ORDINALS,
	SLOTS,
	START_TOOLS,
	WORKFLOWS,
	customWorkflow,
	nextTools,
	stepsPath,
	workflowCategory,
	workflowTools,
	type Workflow,
} from 'delphitools-v2/lib/workflows';
import { getToolById, type Tool } from 'delphitools-v2/lib/tools';
import type FlowService from 'delphitools-v2/services/flow';

const ROWS = WORKFLOWS.map((workflow) => {
	const tools = workflowTools(workflow);
	return {
		workflow,
		category: workflowCategory(workflow),
		slots: Array.from(
			{ length: SLOTS },
			(_, index): Tool | null => tools[index] ?? null,
		),
	};
});

export default class WorkflowList extends Component<{
	Element: HTMLDivElement;
}> {
	@service declare flow: FlowService;

	@tracked picks: string[] = [];

	get slots() {
		const chosen = this.picks.map((id) => getToolById(id) ?? null);
		return Array.from({ length: SLOTS }, (_, index) => {
			const before = chosen[index - 1];
			return {
				index,
				ordinal: ORDINALS[index],
				tool: chosen[index] ?? null,
				value: this.picks[index] ?? '',
				options:
					index === 0
						? START_TOOLS
						: before
							? nextTools(before)
							: [],
			};
		});
	}

	get custom() {
		return customWorkflow(this.picks);
	}

	get stepsPath() {
		return stepsPath(this.picks);
	}

	pick = (index: number, id: string) => {
		this.picks = [...this.picks.slice(0, index), id];
	};

	start = (workflow: Workflow) => {
		const { flow } = this;
		if (
			flow.active &&
			flow.files.length > 0 &&
			!confirm('Discard captures?')
		)
			return;
		void flow.start(workflow);
	};

	<template>
		<div class="dt-wf-list" ...attributes>
			<img
				src="/art/delphi-alien.webp"
				width="815"
				height="1568"
				alt=""
				class="dt-wf-art"
			/>
			<div class="dt-wf-scroll">
				<table class="dt-wf">
					<thead>
						<tr>
							<th
								scope="col"
								class="dt-wf-th"
							>Workflow</th>
							<th
								scope="col"
								class="dt-wf-th"
							>First,</th>
							<th
								scope="col"
								class="dt-wf-th"
							>Then...</th>
							<th
								scope="col"
								class="dt-wf-th"
							>Finally,</th>
							<th
								scope="col"
								class="dt-wf-th"
							></th>
						</tr>
					</thead>
					<tbody>
						<tr
							class="dt-wf-row dt-wf-custom"
						>
							<th
								scope="row"
								class="dt-wf-cell"
							>
								<div
									class="dt-wf-name dt-wf-custom-name"
								>
									<span
										class="dt-wf-custom-title"
									>
										<span
										>Custom</span>
										<span
											class="dt-wf-in"
										>Build
											your
											own</span>
									</span>
									{{#if
										this.custom
									}}
										<LinkTo
											@route="workflow"
											@model={{this.stepsPath}}
											class="dt-icon-btn dt-wf-link"
											title="Share link"
											aria-label="Share link"
										>
											<Icon
												@name="link"
											/>
										</LinkTo>
									{{/if}}
								</div>
							</th>
							{{#each
								this.slots
								key="index"
								as |slot|
							}}
								<td
									class="dt-wf-cell dt-wf-pick"
								>
									<Select
										@value={{slot.value}}
										@disabled={{eq
											slot.options.length
											0
										}}
										@onValueChange={{fn
											this.pick
											slot.index
										}}
									>
										<SelectTrigger
										>
											<SelectValue
												class="dt-wf-pick-value"
											>
												{{#if
													slot.tool
												}}
													<Icon
														@name={{slot.tool.icon}}
													/>
													<span
													>{{slot.tool.name}}</span>
												{{else}}
													<span
														class="dt-wf-pick-placeholder"
													>{{slot.ordinal}}</span>
												{{/if}}
											</SelectValue>
										</SelectTrigger>
										<SelectContent
											class="dt-wf-pick-list"
										>
											{{#each
												slot.options
												key="id"
												as |tool|
											}}
												<SelectItem
													@value={{tool.id}}
												>
													<Icon
														@name={{tool.icon}}
													/>
													{{tool.name}}
												</SelectItem>
											{{/each}}
										</SelectContent>
									</Select>
								</td>
							{{/each}}
							<td class="dt-wf-cell">
								{{#if
									this.custom
								}}
									<button
										type="button"
										class="dt-wf-go"
										{{on
											"click"
											(fn
												this.start
												this.custom
											)
										}}
									>
										Start
										<Icon
											@name="arrow-right"
										/>
									</button>
								{{else}}
									<button
										type="button"
										class="dt-wf-go"
										disabled
									>
										Start
										<Icon
											@name="arrow-right"
										/>
									</button>
								{{/if}}
							</td>
						</tr>
						{{#each
							ROWS key="workflow.id"
							as |row|
						}}
							<tr class="dt-wf-row">
								<th
									scope="row"
									class="dt-wf-cell"
								>
									<button
										type="button"
										class="dt-wf-name"
										{{on
											"click"
											(fn
												this.start
												row.workflow
											)
										}}
									>
										<span
										>{{row.workflow.name}}</span>
										<span
											class="dt-wf-in"
										>{{row.category}}</span>
									</button>
								</th>
								{{#each
									row.slots
									as |tool|
								}}
									<td
										class="dt-wf-cell dt-wf-step"
									>
										{{#if
											tool
										}}
											<Icon
												@name={{tool.icon}}
											/>
											<span
											>{{tool.name}}</span>
										{{/if}}
									</td>
								{{/each}}
								<td
									class="dt-wf-cell"
								>
									<button
										type="button"
										class="dt-wf-go"
										{{on
											"click"
											(fn
												this.start
												row.workflow
											)
										}}
									>
										Start
										<Icon
											@name="arrow-right"
										/>
									</button>
								</td>
							</tr>
						{{/each}}
					</tbody>
				</table>
			</div>
		</div>
	</template>
}
