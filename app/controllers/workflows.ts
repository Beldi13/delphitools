import Controller from '@ember/controller';
import { tracked } from '@glimmer/tracking';

export default class WorkflowsController extends Controller {
	queryParams = ['steps'];

	@tracked steps: string | null = null;
}
