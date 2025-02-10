const esbuild = require('esbuild');
const path = require('path');

const workerEntryPoints = [
	'vs/language/json/json.worker.js',
	'vs/language/css/css.worker.js',
	'vs/language/html/html.worker.js',
	'vs/editor/editor.worker.js'
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
	entryPoints: ['resources/scripts/jinn-monaco-editor.js'],
	bundle: true,
	format: 'esm',
	minify: true,
	outdir: path.join(__dirname, 'resources/scripts/dist'),
    loader: {
		'.ttf': 'binary'
	}
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
