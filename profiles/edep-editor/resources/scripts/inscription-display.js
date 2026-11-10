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

    let bibPopover;

    function popover() {
        if (!bibPopover) {
            bibPopover = document.createElement('div');
            bibPopover.className = 'inscription-bibref-popover';
            bibPopover.setAttribute('popover', 'auto');
            bibPopover.style.cssText = 'margin:0;max-width:32rem;padding:.75rem 1rem;border:1px solid #ccc;border-radius:4px;box-shadow:0 2px 8px rgba(0,0,0,.2);position:fixed;inset:auto;';
            document.body.appendChild(bibPopover);
        }
        return bibPopover;
    }

    function showBibref(el) {
        const tag = el.dataset.tag;
        if (!tag) {
            return;
        }
        const pop = popover();
        pop.textContent = '…';
        const rect = el.getBoundingClientRect();
        pop.style.left = Math.max(8, Math.min(rect.left, window.innerWidth - 520)) + 'px';
        pop.style.top = (rect.bottom + 4) + 'px';
        pop.showPopover();
        fetchBib(tag).then((bib) => {
            if (bib) {
                pop.innerHTML = bib;
            } else {
                pop.textContent = tag;
            }
        });
    }

    function bibrefTarget(ev) {
        return ev.composedPath().find((node) => node.classList && node.classList.contains('inscription-bibref'));
    }

    document.addEventListener('click', (ev) => {
        const el = bibrefTarget(ev);
        if (el) {
            showBibref(el);
        }
    });
    document.addEventListener('keydown', (ev) => {
        const el = (ev.key === 'Enter' || ev.key === ' ') && bibrefTarget(ev);
        if (el) {
            ev.preventDefault();
            showBibref(el);
        }
    });

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
