import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { fn } from '@ember/helper';
import { on } from '@ember/modifier';
import { eq, not } from 'ember-truth-helpers';
import { getSnapshot, subscribe } from 'delphitools-v2/lib/substrata/doc-store';
import {
	getActiveLayerId,
	subscribeSelection,
} from 'delphitools-v2/lib/substrata/selection';
import {
	EXPORT_FORMATS,
	EXPORT_SCALES,
	formatMeta,
	resolveExportDims,
	type ExportFormat,
	type ExportScale,
	type ExportScope,
} from 'delphitools-v2/lib/substrata/export-core';
import { jxlAvailable } from 'delphitools-v2/lib/substrata/export-encode';
import { runExport } from 'delphitools-v2/lib/substrata/export-run';
import { closeModal } from 'delphitools-v2/lib/substrata/modal';
import { TrackedExternal } from 'delphitools-v2/lib/tracked-external';

export default class ExportModal extends Component {
	doc = new TrackedExternal(subscribe, getSnapshot);
	activeLayerId = new TrackedExternal(
		subscribeSelection,
		getActiveLayerId,
	);

	@tracked format: ExportFormat = 'png';
	@tracked scale: ExportScale = 1;
	@tracked quality = 90;
	@tracked wantLayer = false;
	@tracked busy = false;
	@tracked failed: string | null = null;

	// jxl needs secure context
	jxlOk = jxlAvailable();

	willDestroy() {
		super.willDestroy();
		this.doc.unsubscribe();
		this.activeLayerId.unsubscribe();
	}

	get hasLayer() {
		return this.activeLayerId.current !== null;
	}

	get scope(): ExportScope {
		return this.wantLayer && this.hasLayer ? 'layer' : 'artboard';
	}

	get lossy() {
		return formatMeta(this.format).lossy;
	}

	get dims() {
		const ab = this.doc.current?.artboard;
		return ab
			? resolveExportDims(ab.width, ab.height, this.scale)
			: null;
	}

	get output() {
		const d = this.dims;
		return d ? `${d.outW} × ${d.outH} px` : '—';
	}

	get cannotExport() {
		return this.busy || this.doc.current === null;
	}

	// layer export needs alpha
	isFormatDisabled = (id: ExportFormat) =>
		(id === 'jxl' && !this.jxlOk) ||
		(!formatMeta(id).alpha && this.scope === 'layer');

	setFormat = (id: ExportFormat) => {
		this.format = id;
	};

	setScale = (scale: ExportScale) => {
		this.scale = scale;
	};

	setScope = (scope: ExportScope) => {
		this.wantLayer = scope === 'layer';
		if (scope === 'layer' && !formatMeta(this.format).alpha)
			this.format = 'png';
	};

	setQuality = (event: Event) => {
		this.quality = Number(
			(event.currentTarget as HTMLInputElement).value,
		);
	};

	doExport = async () => {
		this.busy = true;
		this.failed = null;
		const outcome = await runExport({
			format: this.format,
			scale: this.scale,
			quality: this.quality,
			scope: this.scope,
		});
		if (this.isDestroyed) return;
		this.busy = false;
		if (outcome.ok) closeModal();
		else this.failed = outcome.reason;
	};

	<template>
		<div class="sub-modal-frame">
			<div class="sub-modal-header">
				<h2 class="sub-modal-title">Export</h2>
			</div>

			<div class="sub-modal-body">
				<section>
					<div
						class="sub-modal-heading"
					>Format</div>
					<div class="segmented sub-exp-seg">
						{{#each
							EXPORT_FORMATS key="id"
							as |f|
						}}
							<button
								type="button"
								class="sub-modal-opt
									{{if
										(eq
											this.format
											f.id
										)
										'is-active'
									}}"
								disabled={{this.isFormatDisabled
									f.id
								}}
								{{on
									"click"
									(fn
										this.setFormat
										f.id
									)
								}}
							>
								{{f.label}}
							</button>
						{{/each}}
					</div>
				</section>

				<section>
					<div
						class="sub-modal-heading"
					>Scale</div>
					<div class="segmented sub-exp-seg">
						{{#each EXPORT_SCALES as |s|}}
							<button
								type="button"
								class="sub-modal-opt
									{{if
										(eq
											this.scale
											s
										)
										'is-active'
									}}"
								{{on
									"click"
									(fn
										this.setScale
										s
									)
								}}
							>
								{{s}}×
							</button>
						{{/each}}
					</div>
				</section>

				<section>
					<div
						class="sub-modal-heading"
					>Scope</div>
					<div class="segmented sub-exp-seg">
						<button
							type="button"
							class="sub-modal-opt
								{{if
									(eq
										this.scope
										'artboard'
									)
									'is-active'
								}}"
							{{on
								"click"
								(fn
									this.setScope
									"artboard"
								)
							}}
						>
							Artboard
						</button>
						<button
							type="button"
							class="sub-modal-opt
								{{if
									(eq
										this.scope
										'layer'
									)
									'is-active'
								}}"
							disabled={{not
								this.hasLayer
							}}
							{{on
								"click"
								(fn
									this.setScope
									"layer"
								)
							}}
						>
							Layer
						</button>
					</div>
				</section>

				{{#if this.lossy}}
					<section>
						<div
							class="sub-modal-heading sub-exp-quality"
						>
							<span>Quality</span>
							<span
							>{{this.quality}}</span>
						</div>
						<input
							type="range"
							class="sub-slider"
							min="1"
							max="100"
							step="1"
							value={{this.quality}}
							aria-label="Quality"
							{{on
								"input"
								this.setQuality
							}}
						/>
					</section>
				{{/if}}

				{{#if this.dims.downscaled}}
					<div class="sub-exp-strip">
						Reduced, this is a device
						limitation
					</div>
				{{/if}}

				{{#if this.failed}}
					<div class="sub-exp-strip is-error">
						Export failed. Try a smaller
						scale?
						<code>({{this.failed}})</code>
					</div>
				{{/if}}

				<div class="sub-exp-strip is-output">
					<span>Output</span>
					<span
						class="sub-exp-dims"
					>{{this.output}}</span>
				</div>
			</div>

			<div class="sub-modal-footer">
				<button
					type="button"
					class="sub-modal-btn is-ghost"
					{{on "click" closeModal}}
				>
					Cancel
				</button>
				<button
					type="button"
					class="sub-modal-btn is-primary"
					disabled={{this.cannotExport}}
					{{on "click" this.doExport}}
				>
					Export
				</button>
			</div>
		</div>
	</template>
}
