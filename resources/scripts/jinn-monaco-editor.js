import * as monaco from 'monaco-editor/esm/vs/editor/editor.main.js';

const workersDir = new URL('vs', import.meta.url).toString();
self.MonacoEnvironment = {
	getWorkerUrl: function (moduleId, label) {
		if (label === 'json') {
			return `${workersDir}/language/json/json.worker.js`;
		}
		if (label === 'css' || label === 'scss' || label === 'less') {
			return `${workersDir}/language/css/css.worker.js`;
		}
		if (label === 'html') {
			return `${workersDir}/language/html/html.worker.js`;
		}
		return `${workersDir}/editor/editor.worker.js`;
	}
};

export class JinnMonacoEditor extends HTMLElement {

    static get observedAttributes() {
        return ['value', 'language'];
    }

    attributeChangedCallback (name, oldValue, newValue) {
        if (!this.__initialized) { return; }
        if (oldValue !== newValue) {
            this[name] = newValue;
        }
    }

    constructor() {
        super();
        this.editor = null;
    }

    get value() {
        return this.editor.getValue();
    }

    set value(value) {
        this.editor.setValue(value);
    }

    async connectedCallback() {
        this.style.display = 'block';
        if (!this.style.width) { this.style.width = '100%' };
        if (!this.style.height) { this.style.height = '100%' };

        const schema = this.getAttribute('schema');
        if (schema) {
            const response = await fetch(schema);
            const json = await response.json();
            monaco.languages.json.jsonDefaults.setDiagnosticsOptions({
                validate: true,
                allowComments: true,
                schemas: [{
                    uri: json.$id,
                    fileMatch: ['*'],
                    schema: json
                }]
            });

            monaco.languages.registerCompletionItemProvider('json', {
                provideCompletionItems: () => {
                    const suggestions = json.properties ? Object.keys(json.properties).map(key => ({
                        label: key,
                        kind: monaco.languages.CompletionItemKind.Property,
                        documentation: json.properties[key].description || '',
                        insertText: key
                    })) : [];
                    return { suggestions: suggestions };
                }
            });
        }

        const computedStyle = getComputedStyle(this);
        const fontSize = parseInt(computedStyle.fontSize) || 14;

        monaco.editor.defineTheme('customTheme', {
            base: 'vs-dark',
            inherit: true,
            rules: [],
            colors: {
                'editorHoverWidget.background': '#f0f0f0'
            }
        });

        monaco.editor.setTheme('customTheme');

        this.editor = monaco.editor.create(this, {
            language: this.getAttribute('language') || 'json',
            automaticLayout: true,
            fontSize: fontSize,
            scrollBeyondLastLine: false,
            minimap: {
                enabled: false
            },
            readOnly: this.hasAttribute('readonly')
        });

        if (this.hasAttribute('value')) {
            this.editor.setValue(this.getAttribute('value'));
        }

        this.editor.onDidChangeModelContent(() => {
            this.dispatchEvent(new CustomEvent('change', {
                detail: this.editor.getValue()
            }));
        });
    }
}

customElements.define('jinn-monaco-editor', JinnMonacoEditor);
