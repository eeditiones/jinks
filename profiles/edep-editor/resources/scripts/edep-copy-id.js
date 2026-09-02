/**
 * Compact copy-to-clipboard icon for register list rows.
 *
 * @attr {string} value - text to copy
 * @attr {string} label - i18n key for the button title (default: register.copy-place-id)
 * @attr {string} title - static button title (overrides label)
 */
class EdepCopyId extends HTMLElement {
    static get observedAttributes() {
        return ['value', 'label', 'title'];
    }

    constructor() {
        super();
        this.attachShadow({ mode: 'open' });
        this._onI18nUpdate = () => this._updateLabel();
    }

    connectedCallback() {
        this._reparentMisplacedChildren();
        this._render();
        this._updateLabel();
    }

    /**
     * HTML parsers treat serialized empty custom elements as unclosed tags, so
     * following siblings (e.g. pb-geolocation) can end up as light-DOM children.
     */
    _reparentMisplacedChildren() {
        const parent = this.parentNode;
        if (!parent) {
            return;
        }
        [...this.childNodes].forEach((child) => {
            if (child.nodeType === Node.ELEMENT_NODE && child.tagName === 'PB-I18N') {
                return;
            }
            parent.insertBefore(child, this.nextSibling);
        });
    }

    disconnectedCallback() {
        this.querySelector('pb-i18n')?.removeEventListener('pb-i18n-update', this._onI18nUpdate);
    }

    attributeChangedCallback() {
        if (this.shadowRoot) {
            this._updateLabel();
        }
    }

    _render() {
        this.shadowRoot.innerHTML = `
            <style>
                :host {
                    display: inline-flex;
                    vertical-align: middle;
                }
                button {
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    padding: 0.15rem;
                    margin: 0;
                    border: none;
                    background: transparent;
                    color: inherit;
                    cursor: pointer;
                    border-radius: 0.25rem;
                    line-height: 0;
                }
                button:hover {
                    background: rgba(0, 0, 0, 0.06);
                }
                button:focus-visible {
                    outline: 2px solid var(--jinks-form-focus-color1, #E30613);
                    outline-offset: 1px;
                }
                svg {
                    width: 16px;
                    height: 16px;
                    display: block;
                }
            </style>
            <button type="button" part="button">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" aria-hidden="true">
                    <path d="M4 1.5H3a2 2 0 0 0-2 2V14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V3.5a2 2 0 0 0-2-2h-1v1h1a1 1 0 0 1 1 1V14a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V3.5a1 1 0 0 1 1-1h1z"/>
                    <path d="M9.5 1a.5.5 0 0 1 .5.5v1a.5.5 0 0 1-.5.5h-3a.5.5 0 0 1-.5-.5v-1a.5.5 0 0 1 .5-.5zm-3-1A1.5 1.5 0 0 0 5 1.5v1A1.5 1.5 0 0 0 6.5 4h3A1.5 1.5 0 0 0 11 2.5v-1A1.5 1.5 0 0 0 9.5 0z"/>
                </svg>
            </button>
        `;
        this.shadowRoot.querySelector('button').addEventListener('click', () => this._copy());
    }

    _updateLabel() {
        const button = this.shadowRoot?.querySelector('button');
        if (!button) {
            return;
        }

        const title = this.getAttribute('title');
        if (title) {
            button.title = title;
            button.setAttribute('aria-label', title);
            return;
        }

        const labelKey = this.getAttribute('label') || 'register.copy-place-id';
        let i18n = this.querySelector('pb-i18n');
        if (!i18n) {
            i18n = document.createElement('pb-i18n');
            i18n.setAttribute('key', labelKey);
            i18n.hidden = true;
            this.appendChild(i18n);
        } else if (i18n.getAttribute('key') !== labelKey) {
            i18n.setAttribute('key', labelKey);
        }

        i18n.removeEventListener('pb-i18n-update', this._onI18nUpdate);
        i18n.addEventListener('pb-i18n-update', this._onI18nUpdate);

        const apply = () => {
            const text = i18n.textContent?.trim();
            if (text) {
                button.title = text;
                button.setAttribute('aria-label', text);
            }
        };
        apply();
        requestAnimationFrame(apply);
    }

    _copy() {
        const text = this.getAttribute('value')?.trim();
        if (text) {
            navigator.clipboard.writeText(text);
        }
    }
}

if (!customElements.get('edep-copy-id')) {
    customElements.define('edep-copy-id', EdepCopyId);
}
