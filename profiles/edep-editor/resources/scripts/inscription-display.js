if (!window.__edepInscriptionToggle) {
    window.__edepInscriptionToggle = true;
    document.addEventListener('click', (ev) => {
        const button = ev.composedPath().find((node) => node.classList && node.classList.contains('inscription-view-toggle'));
        if (!button) {
            return;
        }
        const sheet = button.closest('.inscription');
        if (sheet) {
            sheet.classList.toggle('diplomatic');
        }
    });
}

if (!window.__edepZoteroRefs) {
    window.__edepZoteroRefs = true;

    const bibByTag = new Map();
    let endpoint = '';

    function appEndpoint() {
        if (endpoint) {
            return endpoint.replace(/\/$/, '');
        }
        const page = document.querySelector('pb-page');
        const fromPage = page && (page.endpoint || page.getAttribute('endpoint'));
        if (fromPage) {
            return String(fromPage).replace(/\/$/, '');
        }
        const src = document.querySelector('script[src*="inscription-display.js"]')?.src || '';
        const marker = '/resources/scripts/inscription-display.js';
        const at = src.indexOf(marker);
        return at >= 0 ? src.slice(0, at) : '';
    }

    function fetchBib(tag) {
        if (bibByTag.has(tag)) {
            return bibByTag.get(tag);
        }
        const base = appEndpoint();
        const url = new URL((base ? base + '/' : '') + 'api/zotero/items/suggest', document.baseURI);
        url.searchParams.set('tag', tag);
        url.searchParams.set('limit', '1');
        const pending = fetch(url.toString(), {
            headers: { Accept: 'application/json' },
            credentials: 'include',
        })
            .then((response) => (response.ok ? response.json() : []))
            .then((items) => (Array.isArray(items) && items[0] && typeof items[0].bib === 'string' ? items[0].bib : ''))
            .catch(() => '');
        bibByTag.set(tag, pending);
        return pending;
    }

    function resolveReferences(root) {
        root.querySelectorAll('.inscription-zotero').forEach((el) => {
            if (el.dataset.zoteroState) {
                return;
            }
            const tag = (el.textContent || '').trim();
            if (!tag) {
                return;
            }
            el.dataset.zoteroState = 'pending';
            fetchBib(tag).then((bib) => {
                if (!el.isConnected || !bib) {
                    if (el.isConnected && !bib) {
                        el.dataset.zoteroState = 'missing';
                    }
                    return;
                }
                el.innerHTML = bib;
                el.dataset.zoteroState = 'resolved';
            });
        });
    }

    function scan() {
        document.querySelectorAll('pb-view').forEach((view) => {
            if (view.shadowRoot) {
                resolveReferences(view.shadowRoot);
            }
        });
    }

    if (window.pbEvents) {
        window.pbEvents.subscribe('pb-page-ready', null, (ev) => {
            endpoint = (ev.detail && ev.detail.endpoint) || endpoint;
            scan();
        });
    }
    document.addEventListener('pb-update', scan);
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', scan);
    } else {
        scan();
    }
}
