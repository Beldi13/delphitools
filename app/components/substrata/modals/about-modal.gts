import type { TOC } from '@ember/component/template-only';
import { LinkTo } from '@ember/routing';
import AboutDelphitoolsBody from 'delphitools-v2/components/about-delphitools';
import { VERSION } from 'delphitools-v2/lib/build-flags';

export const AboutSubstrataModal: TOC<object> = <template>
	<div class="sub-modal-frame">
		<div class="sub-modal-header">
			<h2 class="sub-modal-title">About Substrata</h2>
		</div>
		<div class="sub-about">
			<div class="sub-about-row">
				<span class="sub-about-name">Substrata</span>
				<span
					class="sub-about-version"
				>v{{VERSION}}</span>
			</div>
			<p class="sub-about-text">
				Substrata is a simple, uncomplicated image
				editor for the browser, based on Fabric.JS.
			</p>
			<div class="sub-about-foot">
				<LinkTo @route="index" class="sub-about-link">
					delphitools
				</LinkTo>
			</div>
		</div>
	</div>
</template>;

export const AboutDelphitoolsModal: TOC<object> = <template>
	<div class="sub-modal-frame is-wide">
		<div class="sub-modal-header">
			<h2 class="sub-modal-title">About delphitools</h2>
		</div>
		<div class="sub-about is-scroll">
			<AboutDelphitoolsBody />
		</div>
	</div>
</template>;
