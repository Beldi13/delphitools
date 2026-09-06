import Component from '@glimmer/component';
import { cached } from '@glimmer/tracking';
import { fn } from '@ember/helper';
import { on } from '@ember/modifier';
import { service } from '@ember/service';
import { LinkTo } from '@ember/routing';
import Icon from 'delphitools-v2/components/icon';
import { queryOrEmpty } from 'delphitools-v2/components/tool-grid';
import { toolsForFile } from 'delphitools-v2/lib/omni';
import type { Tool } from 'delphitools-v2/lib/tools';
import type FlowService from 'delphitools-v2/services/flow';

type Entry = Pick<Tool, 'id' | 'name' | 'icon'>;

interface AtlasOpenInSignature {
	Args: {
		file?: File | null;
		self?: string;
		tools?: Entry[];
		query?: Record<string, string>;
	};
}

export default class AtlasOpenIn extends Component<AtlasOpenInSignature> {
	@service declare flow: FlowService;

	@cached
	get tools(): Entry[] {
		if (this.args.tools) return this.args.tools;
		const file = this.args.file;
		if (!file) return [];
		return toolsForFile(file).filter(
			(tool) => tool.id !== this.args.self && !tool.route,
		);
	}

	pick = (id: string) => {
		const file = this.args.file;
		if (file) this.flow.handoff = { toolId: id, file };
	};

	<template>
		{{#if this.tools.length}}
			<div class="dt-atlas-open">
				{{#each this.tools key="id" as |tool|}}
					<LinkTo
						@route="tools.tool"
						@model={{tool.id}}
						@query={{queryOrEmpty @query}}
						data-tool={{tool.id}}
						{{on
							"click"
							(fn this.pick tool.id)
						}}
					>
						<Icon @name={{tool.icon}} />
						<span>{{tool.name}}</span>
					</LinkTo>
				{{/each}}
			</div>
		{{/if}}
	</template>
}
