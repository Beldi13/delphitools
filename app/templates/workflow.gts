import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { service } from '@ember/service';
import { LinkTo } from '@ember/routing';
import RouteTemplate from 'ember-route-template';
import { pageTitle } from 'ember-page-title';
import Icon from 'delphitools-v2/components/icon';
import {
	ORDINALS,
	workflowTools,
	type Workflow,
} from 'delphitools-v2/lib/workflows';
import type FlowService from 'delphitools-v2/services/flow';

interface Signature {
	Args: { model: Workflow };
}

class WorkflowTemplate extends Component<Signature> {
	@service declare flow: FlowService;

	get legs() {
		return workflowTools(this.args.model).map((tool, index) => ({
			tool,
			ordinal: ORDINALS[index],
		}));
	}

	start = () => {
		const { flow } = this;
		if (
			flow.active &&
			flow.files.length > 0 &&
			!confirm('Discard captures?')
		)
			return;
		void flow.start(this.args.model);
	};

	<template>
		{{pageTitle "Workflow"}}

		<div class="dt-pass-room">
			<article class="dt-pass">
				<div class="dt-pass-main">
					<p class="dt-pass-band">
						<Icon @name="workflow" />
						delphitools Workflow:
					</p>
					<ol class="dt-pass-legs">
						{{#each
							this.legs key="tool.id"
							as |leg|
						}}
							<li class="dt-pass-leg">
								<span
									class="dt-pass-ord"
								>{{leg.ordinal}}</span>
								<span
									class="dt-pass-tool"
								>
									<Icon
										@name={{leg.tool.icon}}
									/>
									<span
									>{{leg.tool.name}}</span>
								</span>
							</li>
						{{/each}}
					</ol>
				</div>
				<div class="dt-pass-stub">
					<span
						class="dt-pass-barcode"
						aria-hidden="true"
					></span>
					<button
						type="button"
						class="dt-wf-go dt-pass-go"
						{{on "click" this.start}}
					>
						Let's go
						<Icon @name="arrow-right" />
					</button>
				</div>
			</article>
			<LinkTo @route="workflows" class="dt-pass-all">
				All workflows
			</LinkTo>
		</div>
	</template>
}

export default RouteTemplate(WorkflowTemplate);
