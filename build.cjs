const esbuild = require('esbuild');
const path = require('path');
const sass = require('sass');
const fs = require('fs');

const workerEntryPoints = [
	'vs/language/json/json.worker.js',
	'vs/language/css/css.worker.js',
	'vs/language/html/html.worker.js',
	'vs/editor/editor.worker.js'
];

const sassOutputDirs = [
    'profiles/theme-base10/resources/css'
];

build({
	entryPoints: workerEntryPoints.map((entry) => `node_modules/monaco-editor/esm/${entry}`),
	bundle: true,
	format: 'esm',
	minify: true,
	outbase: 'node_modules/monaco-editor/esm/',
	outdir: path.join(__dirname, 'resources/scripts/dist')
});

build({
	entryPoints: [
		'resources/scripts/jinn-monaco.js'
	],
	bundle: true,
	format: 'esm',
	minify: true,
	outdir: path.join(__dirname, 'resources/scripts/dist'),
    loader: {
		'.ttf': 'binary'
	}
});

// Compile SASS
const sassResult = sass.compile('profiles/theme-base10/resources/sass/pico-components.sass', {
    style: 'compressed'
});

// Ensure the output directory exists
sassOutputDirs.forEach(outputDir => {
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }
});

// Write the compiled CSS
sassOutputDirs.forEach(outputDir => {
    fs.writeFileSync(path.join(outputDir, 'pico-components.css'), sassResult.css);
});

/**
 * @param {import ('esbuild').BuildOptions} opts
 */
function build(opts) {
	esbuild.build(opts).then((result) => {
		if (result.errors.length > 0) {
			console.error(result.errors);
		}
		if (result.warnings.length > 0) {
			console.error(result.warnings);
		}
	});
}
