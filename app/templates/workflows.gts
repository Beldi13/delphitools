import Component from '@glimmer/component';
import { hash } from '@ember/helper';
import { on } from '@ember/modifier';
import { service } from '@ember/service';
import { LinkTo } from '@ember/routing';
import RouteTemplate from 'ember-route-template';
import { pageTitle } from 'ember-page-title';
import Icon from 'delphitools-v2/components/icon';
import WorkflowList from 'delphitools-v2/components/workflow-list';
import {
	ORDINALS,
	workflowFromQuery,
	workflowTools,
} from 'delphitools-v2/lib/workflows';
import type FlowService from 'delphitools-v2/services/flow';

const DESCRIPTION = 'Execute tool sequences';

interface Signature {
	Args: { controller: { steps: string | null } };
}

class WorkflowsTemplate extends Component<Signature> {
	@service declare flow: FlowService;

	get custom() {
		return workflowFromQuery(this.args.controller.steps);
	}

	get steps() {
		const custom = this.custom;
		return custom
			? workflowTools(custom).map((tool, index) => ({
					tool,
					ordinal: ORDINALS[index],
				}))
			: [];
	}

	start = () => {
		const { flow, custom } = this;
		if (!custom) return;
		if (
			flow.active &&
			flow.files.length > 0 &&
			!confirm('Discard captures?')
		)
			return;
		void flow.start(custom);
	};

	<template>
		{{pageTitle "Workflows"}}

		<div class="dt-tool-page">
			<div class="dt-tool-body">
				<header class="dt-tool-header is-capped">
					<span class="dt-tool-icon">
						<Icon @name="workflow" />
					</span>
					<div class="dt-tool-heading">
						<div class="dt-tool-titles">
							<h1>Workflows</h1>
						</div>
						<p
							class="dt-tool-desc"
						>{{DESCRIPTION}}</p>
					</div>
				</header>

				{{#if this.custom}}
					<section class="dt-wf-prepare">
						<p class="dt-wf-prepare-kicker">
							<Icon
								@name="workflow"
							/>
							delphitools Workflow:
						</p>
						<ol class="dt-wf-prepare-steps">
							{{#each
								this.steps
								key="tool.id"
								as |step|
							}}
								<li
									class="dt-wf-prepare-step"
								>
									<span
										class="dt-wf-prepare-ord"
									>{{step.ordinal}}</span>
									<Icon
										@name={{step.tool.icon}}
									/>
									<span
									>{{step.tool.name}}</span>
								</li>
							{{/each}}
						</ol>
						<div
							class="dt-wf-prepare-actions"
						>
							<button
								type="button"
								class="dt-wf-go dt-wf-prepare-go"
								{{on
									"click"
									this.start
								}}
							>
								Let's go
								<Icon
									@name="arrow-right"
								/>
							</button>
							<LinkTo
								@route="workflows"
								@query={{hash
									steps=null
								}}
								class="dt-wf-prepare-all"
							>
								All workflows
							</LinkTo>
						</div>
					</section>
				{{else}}
					<WorkflowList />
				{{/if}}
			</div>
		</div>
	</template>
}

export default RouteTemplate(WorkflowsTemplate);
