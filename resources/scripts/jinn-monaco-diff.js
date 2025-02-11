import * as monaco from 'monaco-editor/esm/vs/editor/editor.main.js';

export class JinnMonacoDiff extends HTMLElement {

    constructor() {
        super();
        this.editor = null;
    }

    async connectedCallback() {
        this.style.display = 'block';

        const computedStyle = getComputedStyle(this);
        const fontSize = parseInt(computedStyle.fontSize) || 14;

        this.editor = monaco.editor.createDiffEditor(this, {
            automaticLayout: true,
            fontSize: fontSize,
            renderSideBySide: true
        });
    }

    diff(original, modified, mimeType) {
        this.editor.setModel({
            original: monaco.editor.createModel(original, mimeType),
            modified: monaco.editor.createModel(modified, mimeType)
        });
    }

    close() {
        this.editor.dispose();
        this.parentNode.removeChild(this);
    }
}
customElements.define('jinn-monaco-diff', JinnMonacoDiff);