import Route from '@ember/routing/route';
import { service } from '@ember/service';
import type RouterService from '@ember/routing/router-service';
import { workflowFromPath, type Workflow } from 'delphitools-v2/lib/workflows';

export default class WorkflowRoute extends Route<Workflow> {
	@service declare router: RouterService;

	beforeModel() {
		const { steps } = this.paramsFor('workflow') as {
			steps: string;
		};
		if (!workflowFromPath(steps))
			this.router.replaceWith('workflows');
	}

	model({ steps }: { steps: string }): Workflow {
		return workflowFromPath(steps)!;
	}
}
