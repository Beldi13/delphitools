import Component from '@glimmer/component';
import { cached, tracked } from '@glimmer/tracking';
import { on } from '@ember/modifier';
import { eq } from 'ember-truth-helpers';
import Icon from 'delphitools-v2/components/icon';
import AtlasOpenIn from 'delphitools-v2/components/atlas-open-in';
import filePaste from 'delphitools-v2/modifiers/file-paste';
import { formatBytes } from 'delphitools-v2/lib/image-compress';
import exifr from 'exifr';

const ACCEPT = 'image/*';

const DROP_TITLE = 'Drop an image here';
const DROP_HINT = 'or click to select a file, or paste';

const NOT_AN_IMAGE = 'Only image files are supported.';
const READ_ERROR = "Couldn't read that file's metadata.";

const COPIED_MS = 1500;

interface Row {
	label: string;
	value: string;
}

interface Section {
	title: string;
	isCamera: boolean;
	rows: Row[];
}

type ExifData = Record<string, unknown>;
type Dimensions = { w: number; h: number };
type GpsPoint = { lat: number; lon: number; alt?: number; altRef?: number };

// excluded from buildsections
const HERO_CAMERA_KEYS = new Set([
	'make',
	'model',
	'lensmake',
	'lensmodel',
	'lens',
	'lensspecification',
	'software',
]);

// excluded from buildsections
const HERO_FILE_KEYS = new Set(['format', 'imageformat']);

const MAX_CELL_CHARS = 180;
const MAX_REPORT_VALUE_CHARS = 500;

function asString(value: unknown): string | undefined {
	return typeof value === 'string' ? value : undefined;
}

function formatValue(value: unknown): string {
	if (value == null) return '';
	if (value instanceof Date) {
		return value.toLocaleString();
	}
	if (Array.isArray(value)) {
		return value.map(formatValue).join(', ');
	}
	if (typeof value === 'object') {
		try {
			const obj = value as Record<string, unknown>;
			if (
				obj.value !== undefined &&
				typeof obj.value === 'string'
			)
				return String(obj.value);
			return JSON.stringify(value);
		} catch {
			return Object.prototype.toString.call(value);
		}
	}
	if (typeof value === 'number') {
		return Number.isInteger(value)
			? String(value)
			: String(Math.round(value * 1e6) / 1e6);
	}
	// eslint-disable-next-line @typescript-eslint/no-base-to-string
	return String(value);
}

function gpsFromExif(data: ExifData): GpsPoint | null {
	const lat = (data.latitude ?? data.GPSLatitude ?? data.gpsLatitude) as
		number | undefined;
	const lon = (data.longitude ??
		data.GPSLongitude ??
		data.gpsLongitude) as number | undefined;
	const alt = (data.GPSAltitude ?? data.gpsAltitude) as
		number | undefined;
	// altref 1: below sea-level
	const altRef = (data.GPSAltitudeRef ?? data.gpsAltitudeRef) as
		number | undefined;
	if (
		typeof lat === 'number' &&
		typeof lon === 'number' &&
		Number.isFinite(lat) &&
		Number.isFinite(lon)
	) {
		const resolvedAlt =
			typeof alt === 'number'
				? altRef === 1
					? -Math.abs(alt)
					: Math.abs(alt)
				: undefined;
		return { lat, lon, alt: resolvedAlt, altRef };
	}
	return null;
}

const LABEL_ACRONYMS: Record<string, string> = {
	Iso: 'ISO',
	Gps: 'GPS',
	Exif: 'Exif',
	Xmp: 'XMP',
	Iptc: 'IPTC',
	'F Number': 'F-Number',
	'Y Cb Cr': 'YCbCr',
};

const LABEL_OVERRIDES: Record<string, string> = {
	Name: 'File Name',
	Size: 'File Size',
	Type: 'MIME Type',
	'Date Time Original': 'Date Taken',
	'Focal Length In35mm Format': '35mm Equivalent',
};

function prettyLabel(key: string): string {
	// exifr keys are camelcase
	let s = key.replace(/_/g, ' ').trim();
	s = s.replace(/([a-z0-9])([A-Z])/g, '$1 $2');
	s = s.replace(/([A-Z])([A-Z][a-z])/g, '$1 $2');
	s = s
		.split(/\s+/)
		.map(
			(w) =>
				w.charAt(0).toUpperCase() +
				w.slice(1).toLowerCase(),
		)
		.join(' ');

	for (const [word, acronym] of Object.entries(LABEL_ACRONYMS)) {
		s = s.replace(new RegExp(`\\b${word}\\b`, 'g'), acronym);
	}

	return LABEL_OVERRIDES[s] ?? s;
}

const ENUM_LABELS: Record<string, Record<string, string>> = {
	colorspace: { '1': 'sRGB', '65535': 'Uncalibrated' },
	ycbcrpositioning: { '1': 'Centered', '2': 'Co-sited' },
	contrast: { '0': 'Normal', '1': 'Soft', '2': 'Hard' },
	saturation: { '0': 'Normal', '1': 'Low', '2': 'High' },
	sharpness: { '0': 'Normal', '1': 'Soft', '2': 'Hard' },
	customrendered: { '0': 'Normal', '1': 'Custom' },
	exposuremode: { '0': 'Auto', '1': 'Manual', '2': 'Auto bracket' },
	whitebalance: { '0': 'Auto', '1': 'Manual' },
	scenecapturetype: {
		'0': 'Standard',
		'1': 'Landscape',
		'2': 'Portrait',
		'3': 'Night scene',
	},
	gaincontrol: { '0': 'None', '1': 'Low gain up', '2': 'High gain up' },
	sensingmethod: {
		'1': 'Not defined',
		'2': 'One-chip color area',
		'3': 'Two-chip color area',
	},
	filesource: { '3': 'Digital camera' },
	scenetype: { '1': 'Directly photographed' },
	subjectdistancerange: {
		'0': 'Unknown',
		'1': 'Macro',
		'2': 'Close view',
		'3': 'Distant view',
	},
	exposureprogram: {
		'0': 'Not defined',
		'1': 'Manual',
		'2': 'Normal program',
		'3': 'Aperture priority',
		'4': 'Shutter priority',
		'5': 'Creative program',
		'6': 'Action program',
		'7': 'Portrait mode',
		'8': 'Landscape mode',
	},
	meteringmode: {
		'0': 'Unknown',
		'1': 'Average',
		'2': 'Center-weighted average',
		'3': 'Spot',
		'4': 'Multi-spot',
		'5': 'Multi-segment',
		'6': 'Partial',
		'255': 'Other',
	},
	lightsource: {
		'0': 'Unknown',
		'1': 'Daylight',
		'2': 'Fluorescent',
		'3': 'Tungsten (incandescent)',
		'4': 'Flash',
		'9': 'Fine weather',
		'10': 'Cloudy weather',
		'11': 'Shade',
		'12': 'Daylight fluorescent',
		'13': 'Day white fluorescent',
		'14': 'Cool white fluorescent',
		'15': 'White fluorescent',
		'16': 'Warm white fluorescent',
		'17': 'Standard light A',
		'18': 'Standard light B',
		'19': 'Standard light C',
		'20': 'D55',
		'21': 'D65',
		'22': 'D75',
		'23': 'D50',
		'24': 'ISO studio tungsten',
		'255': 'Other',
	},
	resolutionunit: { '2': 'Inches', '3': 'cm' },
	gpsmeasuremode: { '2': '2D measurement', '3': '3D measurement' },
};

// noise: blobs and plumbing
const IGNORED_KEYS = new Set([
	// exifr file path key
	'directory',
	'hdrplusmakernote',
	'makernote',
	'makernotes',
	'usercomment',
	'thumbnail',
	'thumbnailimage',
	'previewimage',
	'embeddedimage',
	// mpf: multi-picture format
	'mpf',
	// sensor calibration blobs
	'cfapattern',
	'cfaplane',
	'cfalayout',
	'oecf',
	'spatialfrequencyresponse',
	'devicesettingdescription',
	'imageboundary',
	'printim',
	'printimversion',
	'interopoffset',
	'interopversion',
	// tiff offsets: huge arrays
	'stripoffsets',
	'stripbytecounts',
	'tileoffsets',
	'tilebytecounts',
	'rowsperstrip',
	'whitepoint',
	'primarychromaticities',
	'ycbcrcoefficients',
	'referenceblackwhite',
	'subjectarea',
	'subjectlocation',
	// byte arrays, not strings
	'exifversion',
	'flashpixversion',
	// opaque component ordering array
	'componentsconfiguration',
	'gpsversionid',
	'gpsprocessingmethod',
	'gpsareainformation',
	// xp tags: kilobytes padding
	'xptitle',
	'xpcomment',
	'xpauthor',
	'xpkeywords',
	'xpsubject',
	'documentid',
	'instanceid',
	'originaldocumentid',
	'renditionclass',
	'preservedfilename',
	// camera raw xmp structs
	'look',
	'pointcolors',
	'masks',
	'retouchinfo',
	'applicationnotes',
	'padding',
	'offsetschema',
	'relatedsoundfile',
]);

// exif infinity sentinel, rounded
const EXIF_INFINITY_THRESHOLD = 4294967245;

const NUMERIC_VALUE_FORMATTERS: Record<
	string,
	(raw: number, base: string) => string
> = {
	subjectdistance: (raw, base) =>
		raw >= EXIF_INFINITY_THRESHOLD ? 'Infinity' : `${base} m`,
	exposuretime: (raw, base) => {
		if (raw <= 0 || raw >= 1) return base;
		const denom = Math.round(1 / raw);
		return denom > 0 ? `${base} (1/${denom}s)` : base;
	},
	exposurecompensation: (_raw, base) => `${base} EV`,
	fnumber: (_raw, base) => (base.startsWith('f/') ? base : `f/${base}`),
	focallength: (_raw, base) => `${base} mm`,
	focallengthin35mmformat: (_raw, base) => `${base} mm`,
	digitalzoomratio: (raw, base) => {
		if (!Number.isFinite(raw)) return '—';
		return raw === 0 ? 'No zoom' : `${base}×`;
	},
};

function prettyValue(key: string, raw: unknown): string {
	const base = formatValue(raw);
	const k = key.toLowerCase();

	const enumMap = ENUM_LABELS[k];
	if (enumMap) {
		const mapped = enumMap[String(raw)];
		if (mapped) return mapped;
	}

	if (typeof raw === 'number') {
		// digitalzoomratio guards non-finite itself
		if (!Number.isFinite(raw) && k !== 'digitalzoomratio')
			return '—';
		const formatter = NUMERIC_VALUE_FORMATTERS[k];
		if (formatter) return formatter(raw, base);
	}

	if (k === 'iso' || k === 'isospeedratings') {
		if (typeof raw === 'number' || Array.isArray(raw))
			return `ISO ${base}`;
	}

	return base;
}

function sectionForKey(key: string): string {
	const k = key.toLowerCase();
	if (
		k.startsWith('gps') ||
		k === 'latitude' ||
		k === 'longitude' ||
		k === 'gpsaltitude'
	)
		return 'Location';
	if (
		/(make|model|lens|bodyserial|lensserial|camera|software|artist|hostcomputer|copyright|owner)/.test(
			k,
		)
	)
		return 'Camera';
	if (
		/(fnumber|exposure|iso|shutter|focal|flash|whitebalance|metering|brightness|lightsource|aperture)/.test(
			k,
		)
	)
		return 'Capture';
	if (
		/(datetime|createdate|modifydate|gpsdate|offsettime|subsec)/.test(
			k,
		)
	)
		return 'Dates';
	if (
		k.startsWith('xmp') ||
		k.includes('xmlns') ||
		k.startsWith('dc:') ||
		k.startsWith('xmp:')
	)
		return 'XMP';
	if (
		k.startsWith('iptc') ||
		k === 'caption' ||
		k === 'keywords' ||
		k === 'city' ||
		k === 'country'
	)
		return 'IPTC';
	if (
		/(imagewidth|imageheight|imagesize|orientation|resolution|colordata|bitspersample|photometric|compress)/.test(
			k,
		)
	)
		return 'Image';
	return 'Other';
}

function filteredExifEntries(exif: ExifData): [string, unknown][] {
	return Object.entries(exif)
		.filter(([key, raw]) => {
			if (key === 'errors') return false;
			const lk = key.toLowerCase();
			if (IGNORED_KEYS.has(lk)) return false;
			if (lk.includes('makernote') || lk.includes('hdrplus'))
				return false;
			if (lk.includes('serial')) return false;
			// xmp edit-history subtrees
			if (
				lk.includes('history') ||
				lk.includes('derivedfrom') ||
				lk.includes('manifest') ||
				lk.includes('ingredient') ||
				lk.includes('pantry')
			)
				return false;
			if (raw instanceof Uint8Array) return false;
			if (raw instanceof ArrayBuffer) return false;
			if (HERO_CAMERA_KEYS.has(lk)) return false;
			if (HERO_FILE_KEYS.has(lk)) return false;
			return true;
		})
		.sort(([a], [b]) => a.localeCompare(b));
}

const SECTION_ORDER = [
	'Camera',
	'Capture',
	'Image',
	'Location',
	'Dates',
	'XMP',
	'IPTC',
	'Other',
];

function buildSections(exif: ExifData | null): Section[] {
	if (!exif) return [];
	const buckets = new Map<string, Row[]>();
	for (const [key, raw] of filteredExifEntries(exif)) {
		let value = prettyValue(key, raw);
		if (!value) continue;
		if (value.length > MAX_CELL_CHARS) {
			const preview = value.slice(0, MAX_CELL_CHARS);
			value = `${preview} … (+${value.length - MAX_CELL_CHARS} chars)`;
		}
		const section = sectionForKey(key);
		if (!buckets.has(section)) buckets.set(section, []);
		buckets.get(section)!.push({ label: prettyLabel(key), value });
	}
	const out: Section[] = [];
	for (const title of SECTION_ORDER) {
		const rows = buckets.get(title);
		if (rows?.length)
			out.push({ title, isCamera: title === 'Camera', rows });
	}
	for (const [title, rows] of buckets) {
		if (!SECTION_ORDER.includes(title)) {
			out.push({ title, isCamera: false, rows });
		}
	}
	return out;
}

function reportText(
	exif: ExifData | null,
	gps: GpsPoint | null,
	fileName: string,
	fileSize: number,
	dims: Dimensions | null,
): string {
	if (!exif && !gps) return '';
	const lines: string[] = [];
	lines.push(`File: ${fileName} (${formatBytes(fileSize)})`);
	if (dims) lines.push(`Dimensions: ${dims.w} × ${dims.h}`);
	lines.push('');
	if (!exif || Object.keys(exif).length === 0) {
		lines.push('No EXIF/XMP/IPTC metadata found.');
	} else {
		for (const [k, v] of filteredExifEntries(exif)) {
			let val = prettyValue(k, v);
			if (val.length > MAX_REPORT_VALUE_CHARS) {
				val = `${val.slice(0, MAX_REPORT_VALUE_CHARS)} … (truncated)`;
			}
			lines.push(`${prettyLabel(k)}: ${val}`);
		}
	}
	if (gps) {
		lines.push('');
		lines.push(
			`GPS: ${gps.lat.toFixed(6)}, ${gps.lon.toFixed(6)}${gps.alt !== undefined ? ` alt ${Math.round(gps.alt)}m` : ''}`,
		);
	}
	return lines.join('\n');
}

export default class ImageAtlasTool extends Component {
	@tracked file: File | null = null;
	@tracked url: string | null = null;
	@tracked fileName = '';
	@tracked fileSize = 0;
	@tracked mimeType = '';
	@tracked dims: Dimensions | null = null;
	@tracked exif: ExifData | null = null;
	@tracked gps: GpsPoint | null = null;
	@tracked busy = false;
	@tracked error = '';
	@tracked copied = false;

	#token = 0;
	#copiedTimer?: ReturnType<typeof setTimeout>;

	willDestroy() {
		super.willDestroy();
		this.#token++;
		clearTimeout(this.#copiedTimer);
		this.#release();
	}

	get hasImage() {
		return this.url !== null;
	}

	@cached
	get exifSections(): Section[] {
		return buildSections(this.exif);
	}

	@cached
	get sections(): Section[] {
		if (!this.hasImage) return [];
		const sections: Section[] = [];

		const fileRows: Row[] = [
			{ label: prettyLabel('Name'), value: this.fileName },
			{
				label: prettyLabel('Size'),
				value: formatBytes(this.fileSize),
			},
			{
				label: prettyLabel('Type'),
				value: this.mimeType || '—',
			},
		];
		if (this.dims) {
			fileRows.push({
				label: prettyLabel('Dimensions'),
				value: `${this.dims.w} × ${this.dims.h}`,
			});
		}
		if (this.exif?.['Format'] || this.exif?.['ImageFormat']) {
			const fmt = (this.exif['Format'] ??
				this.exif['ImageFormat']) as string;
			fileRows.push({
				label: prettyLabel('Format'),
				value: formatValue(fmt),
			});
		}
		sections.push({
			title: 'File',
			isCamera: false,
			rows: fileRows,
		});

		// hero grid is 2×2
		if (this.exif) {
			const e = this.exif;
			const make = asString(e['Make']);
			const model = asString(e['Model']);
			const lensMake =
				asString(e['LensMake']) ??
				asString(e['Lens Make']);
			const lensModel =
				e['LensModel'] ??
				e['Lens'] ??
				e['LensSpecification'];
			const rows: Row[] = [];
			if (make)
				rows.push({
					label: prettyLabel('Make'),
					value: prettyValue('Make', make),
				});
			if (model)
				rows.push({
					label: prettyLabel('Model'),
					value: prettyValue('Model', model),
				});
			if (lensMake)
				rows.push({
					label: prettyLabel('LensMake'),
					value: prettyValue(
						'LensMake',
						lensMake,
					),
				});
			if (lensModel)
				rows.push({
					label: prettyLabel('LensModel'),
					value: prettyValue(
						'LensModel',
						lensModel,
					),
				});
			// pad hero to 2×2
			if (rows.length === 2 && e['Software']) {
				rows.push({
					label: prettyLabel('LensModel'),
					value: '—',
				});
				rows.push({
					label: prettyLabel('Software'),
					value: prettyValue(
						'Software',
						e['Software'],
					),
				});
			}
			if (rows.length > 0) {
				sections.push({
					title: 'Camera',
					isCamera: true,
					rows,
				});
			}
		}

		// merge leftover camera rows
		const heroCameraSection = sections.find((sec) => sec.isCamera);
		for (const s of this.exifSections) {
			if (s.isCamera && heroCameraSection) {
				heroCameraSection.rows.push(...s.rows);
				continue;
			}
			sections.push(s);
		}

		return sections;
	}

	get hasMetadata(): boolean {
		return !!this.exif && Object.keys(this.exif).length > 0;
	}

	get summary() {
		if (!this.exif && !this.busy) return '';
		if (this.busy) return 'Reading…';
		const n = this.exif
			? Object.keys(this.exif).filter((k) => k !== 'errors')
					.length
			: 0;
		const dim = this.dims ? `${this.dims.w}×${this.dims.h}` : '';
		const meta =
			n === 0
				? 'no metadata'
				: n === 1
					? '1 field'
					: `${n} fields`;
		return [dim, meta].filter(Boolean).join(' · ');
	}

	#release() {
		if (this.url) URL.revokeObjectURL(this.url);
		this.url = null;
	}

	load = (file: File) => void this.#load(file);

	async #load(file: File) {
		if (!file.type.startsWith('image/')) {
			this.error = NOT_AN_IMAGE;
			return;
		}
		const token = ++this.#token;
		this.busy = true;
		this.error = '';
		this.dims = null;
		this.exif = null;
		this.gps = null;
		this.#release();
		this.file = file;
		this.fileName = file.name;
		this.fileSize = file.size;
		this.mimeType = file.type;
		this.url = URL.createObjectURL(file);

		try {
			const data = (await exifr.parse(file, {
				tiff: true,
				exif: true,
				gps: true,
				ifd0: true,
				ifd1: true,
				xmp: true,
				iptc: true,
				icc: false,
				jfif: true,
				ihdr: true,
				makerNote: false,
				userComment: false,
				mergeOutput: true,
				translateKeys: true,
				translateValues: true,
				reviveValues: true,
			} as unknown as Record<string, unknown>)) as
				ExifData | undefined;

			if (token !== this.#token) return;

			let gps = gpsFromExif(data ?? {});
			if (!gps) {
				try {
					const g = (await exifr.gps(file)) as
						| {
								latitude?: number;
								longitude?: number;
						  }
						| undefined;
					if (
						g?.latitude != null &&
						g?.longitude != null
					)
						gps = {
							lat: g.latitude,
							lon: g.longitude,
						};
				} catch (err) {
					console.warn(
						'exifr.gps fallback failed',
						err,
					);
				}
			}
			if (token !== this.#token) return;

			this.exif =
				data && Object.keys(data).length ? data : {};
			this.gps = gps;
		} catch (err) {
			if (token !== this.#token) return;
			console.error('exifr failed:', err);
			this.error = READ_ERROR;
			this.exif = {};
		} finally {
			if (token === this.#token) this.busy = false;
		}
	}

	chooseFile = (event: Event) => {
		const input = event.target as HTMLInputElement;
		const file = input.files?.[0];
		if (file) this.load(file);
		input.value = '';
	};

	drop = (event: DragEvent) => {
		event.preventDefault();
		const file = event.dataTransfer?.files[0];
		if (file) this.load(file);
	};

	dragOver = (event: DragEvent) => {
		event.preventDefault();
	};

	onImageLoad = (event: Event) => {
		const img = event.target as HTMLImageElement;
		if (img.naturalWidth) {
			this.dims = {
				w: img.naturalWidth,
				h: img.naturalHeight,
			};
		}
	};

	onImageError = () => {
		this.error = READ_ERROR;
	};

	copy = () => void this.#copy();

	async #copy() {
		if (!this.exif && !this.gps) return;
		try {
			await navigator.clipboard.writeText(
				reportText(
					this.exif,
					this.gps,
					this.fileName,
					this.fileSize,
					this.dims,
				),
			);
		} catch (err) {
			console.warn('Clipboard write refused:', err);
			return;
		}
		this.copied = true;
		clearTimeout(this.#copiedTimer);
		this.#copiedTimer = setTimeout(
			() => (this.copied = false),
			COPIED_MS,
		);
	}

	clear = () => {
		this.#token++;
		this.#release();
		this.file = null;
		this.fileName = '';
		this.fileSize = 0;
		this.mimeType = '';
		this.dims = null;
		this.exif = null;
		this.gps = null;
		this.busy = false;
		this.error = '';
	};

	<template>
		<div class="dt-ia" {{filePaste this.load accept=ACCEPT}}>
			<div
				class="dt-ia-frame"
				{{on "drop" this.drop}}
				{{on "dragover" this.dragOver}}
			>
				<div class="dt-ia-bar">
					<label
						class="dt-ia-file"
						aria-label="Open image file"
					>
						<input
							type="file"
							class="dt-sr-only"
							accept={{ACCEPT}}
							{{on
								"change"
								this.chooseFile
							}}
						/>
						<Icon @name="image" />
						<span
							class="dt-ia-filename"
						>{{if
								this.fileName
								this.fileName
								"Choose image"
							}}</span>
					</label>
					{{#if this.busy}}
						<span
							class="dt-ia-status"
							role="status"
						>Reading…</span>
					{{else if this.summary}}
						<span
							class="dt-ia-status"
						>{{this.summary}}</span>
					{{/if}}
					<button
						type="button"
						class="dt-ia-btn"
						disabled={{unless
							this.exif
							true
						}}
						{{on "click" this.copy}}
					>
						<Icon
							@name={{if
								this.copied
								"check"
								"copy"
							}}
						/>
						<span>Copy report</span>
					</button>
					<button
						type="button"
						class="dt-ia-clear"
						disabled={{unless
							this.hasImage
							true
						}}
						aria-label="Clear"
						{{on "click" this.clear}}
					>
						<Icon @name="x" />
					</button>
				</div>

				<div class="dt-ia-stage">
					{{#if this.hasImage}}
						<img
							src={{this.url}}
							alt={{this.fileName}}
							loading="eager"
							decoding="async"
							{{on
								"load"
								this.onImageLoad
							}}
							{{on
								"error"
								this.onImageError
							}}
						/>
					{{else}}
						<label class="dt-ia-drop">
							<input
								type="file"
								class="dt-sr-only"
								accept={{ACCEPT}}
								{{on
									"change"
									this.chooseFile
								}}
							/>
							<Icon @name="image" />
							<span
								class="dt-ia-drop-title"
							>{{DROP_TITLE}}</span>
							<span
								class="dt-ia-drop-hint"
							>{{DROP_HINT}}</span>
						</label>
					{{/if}}
				</div>

				{{#each this.sections key="title" as |panel|}}
					{{#if (eq panel.title "Other")}}
						<details class="dt-ia-advanced">
							<summary
								class="dt-ia-summary"
							>
								<span
								>{{panel.title}}
									({{panel.rows.length}})</span>
								<Icon
									@name="chevron-down"
								/>
							</summary>
							<dl class="dt-ia-meta">
								{{#each
									panel.rows
									key="label"
									as |row|
								}}
									<div
										class="dt-ia-cell"
									>
										<dt
										>{{row.label}}</dt>
										<dd
										>{{row.value}}</dd>
									</div>
								{{/each}}
							</dl>
						</details>
					{{else}}
						<section
							class="dt-ia-panel
								{{if
									panel.isCamera
									'is-camera'
								}}"
						>
							<h3
								class="dt-ia-panel-title"
							>{{panel.title}}</h3>
							<dl
								class="dt-ia-meta
									{{if
										panel.isCamera
										'is-hero'
									}}"
							>
								{{#each
									panel.rows
									key="label"
									as |row|
								}}
									<div
										class="dt-ia-cell"
									>
										<dt
										>{{row.label}}</dt>
										<dd
										>{{row.value}}</dd>
									</div>
								{{/each}}
							</dl>
						</section>
					{{/if}}
				{{/each}}

				{{#if this.exif}}
					{{#if (eq this.hasMetadata false)}}
						<p class="dt-ia-empty">No EXIF /
							XMP / IPTC metadata
							found. This image looks
							clean.</p>
					{{/if}}
					{{#if this.gps}}
						<p class="dt-ia-empty">
							<a
								href="https://www.openstreetmap.org/?mlat={{this.gps.lat}}&mlon={{this.gps.lon}}#map=15/{{this.gps.lat}}/{{this.gps.lon}}"
								target="_blank"
								rel="noopener noreferrer"
							>Open location on
								OpenStreetMap</a>
						</p>
					{{/if}}
				{{/if}}

				<AtlasOpenIn
					@file={{this.file}}
					@self="image-atlas"
				/>

				{{#if this.error}}
					<p
						class="dt-ia-error"
						role="alert"
					>{{this.error}}</p>
				{{/if}}
			</div>
		</div>
	</template>
}
