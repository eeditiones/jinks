(() => {
    const MAX_ITEMS = 50;
    const TEI_NS = 'http://www.tei-c.org/ns/1.0';
    const XML_NS = 'http://www.w3.org/XML/1998/namespace';
    const inited = new WeakSet();

    function placesUrl(geopicker) {
        const inst = geopicker.querySelector('fx-instance[id="i-geodata"]');
        const fromInstance = inst && inst.getAttribute('src');
        if (fromInstance) {
            return fromInstance;
        }
        const sub = geopicker.querySelector('fx-submission[id="s-load-places"]');
        return (sub && sub.getAttribute('url')) || '';
    }

    function parsePlaces(xmlText) {
        const doc = new DOMParser().parseFromString(xmlText, 'application/xml');
        const seen = new Map();
        Array.from(doc.getElementsByTagNameNS(TEI_NS, 'place')).forEach((place) => {
            const id = (
                place.getAttributeNS(XML_NS, 'id') ||
                place.getAttribute('xml:id') ||
                ''
            ).trim();
            if (!id || seen.has(id)) {
                return;
            }
            const nameEl = place.getElementsByTagNameNS(TEI_NS, 'placeName')[0];
            seen.set(id, {
                id,
                name: ((nameEl && nameEl.textContent) || '').trim()
            });
        });
        return Array.from(seen.values());
    }

    function matches(item, query) {
        if (!query) {
            return true;
        }
        return `${item.name} ${item.id}`.toLowerCase().includes(query);
    }

    async function loadPlaces(geopicker) {
        const url = placesUrl(geopicker);
        if (!url) {
            geopicker._geoPlaces = [];
            return [];
        }
        const response = await fetch(url, { credentials: 'same-origin' });
        if (!response.ok) {
            geopicker._geoPlaces = geopicker._geoPlaces || [];
            return geopicker._geoPlaces;
        }
        const places = parsePlaces(await response.text());
        geopicker._geoPlaces = places;
        return places;
    }

    function initControl(geopicker) {
        const control = geopicker.querySelector('fx-control');
        const input = control && control.querySelector('input.widget, input');
        if (!control || !input || inited.has(input)) {
            return;
        }
        inited.add(input);

        const stripNativeList = () => {
            if (input.getAttribute('list')) {
                input.removeAttribute('list');
            }
        };
        stripNativeList();
        input.setAttribute('autocomplete', 'off');
        input.setAttribute('spellcheck', 'false');
        input.setAttribute('role', 'combobox');
        input.setAttribute('aria-autocomplete', 'list');
        input.setAttribute('aria-expanded', 'false');

        let list = control.querySelector(':scope > .geo-suggest-list');
        if (!list) {
            list = document.createElement('ul');
            list.className = 'geo-suggest-list';
            list.setAttribute('role', 'listbox');
            list.hidden = true;
            input.after(list);
        }
        if (!list.id) {
            list.id = 'place-suggest-list';
        }
        input.setAttribute('aria-controls', list.id);

        let active = -1;
        let visible = [];

        const close = () => {
            list.hidden = true;
            list.innerHTML = '';
            active = -1;
            visible = [];
            input.setAttribute('aria-expanded', 'false');
        };

        const highlight = (index) => {
            const items = list.querySelectorAll('.geo-suggest-item');
            items.forEach((item, i) => {
                const selected = i === index;
                item.setAttribute('aria-selected', selected ? 'true' : 'false');
                if (selected) {
                    item.scrollIntoView({ block: 'nearest' });
                }
            });
            active = index;
        };

        const apply = (item) => {
            if (!item) {
                return;
            }
            input.value = item.id;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            close();
        };

        const render = (places) => {
            stripNativeList();
            const query = (input.value || '').trim().toLowerCase();
            const source = Array.isArray(places) ? places : (geopicker._geoPlaces || []);
            const unique = [];
            const seen = new Set();
            source.forEach((item) => {
                if (!item.id || seen.has(item.id)) {
                    return;
                }
                seen.add(item.id);
                if (matches(item, query)) {
                    unique.push(item);
                }
            });
            visible = unique.slice(0, MAX_ITEMS);
            list.innerHTML = '';

            if (!visible.length) {
                const empty = document.createElement('li');
                empty.className = 'geo-suggest-empty';
                empty.textContent = query ? 'No matching places' : 'No places loaded';
                list.appendChild(empty);
            } else {
                visible.forEach((item, index) => {
                    const li = document.createElement('li');
                    li.className = 'geo-suggest-item';
                    li.setAttribute('role', 'option');
                    li.setAttribute('aria-selected', 'false');
                    li.dataset.index = String(index);

                    const name = document.createElement('span');
                    name.className = 'geo-suggest-name';
                    name.textContent = item.name || item.id;

                    const id = document.createElement('span');
                    id.className = 'geo-suggest-id';
                    id.textContent = item.id;

                    li.appendChild(name);
                    if (item.id && item.name) {
                        li.appendChild(id);
                    }
                    list.appendChild(li);
                });
            }

            list.hidden = false;
            input.setAttribute('aria-expanded', 'true');
            highlight(visible.length ? 0 : -1);
        };

        const open = () => {
            const cached = geopicker._geoPlaces;
            if (cached && cached.length) {
                render(cached);
            } else {
                render([]);
            }
            loadPlaces(geopicker).then((places) => {
                if (document.activeElement === input && !list.hidden) {
                    render(places);
                }
            });
        };

        input.addEventListener('focus', open);
        input.addEventListener('click', open);
        input.addEventListener('input', () => render());
        input.addEventListener('keydown', (event) => {
            if (list.hidden && (event.key === 'ArrowDown' || event.key === 'ArrowUp')) {
                open();
                event.preventDefault();
                return;
            }
            if (list.hidden) {
                return;
            }
            if (event.key === 'ArrowDown') {
                event.preventDefault();
                highlight(Math.min(active + 1, visible.length - 1));
            } else if (event.key === 'ArrowUp') {
                event.preventDefault();
                highlight(Math.max(active - 1, 0));
            } else if (event.key === 'Enter') {
                if (active >= 0 && visible[active]) {
                    event.preventDefault();
                    apply(visible[active]);
                }
            } else if (event.key === 'Escape') {
                event.preventDefault();
                close();
            }
        });

        list.addEventListener('mousedown', (event) => {
            const item = event.target.closest('.geo-suggest-item');
            if (!item) {
                return;
            }
            event.preventDefault();
            apply(visible[Number(item.dataset.index)]);
        });

        document.addEventListener('mousedown', (event) => {
            if (!control.contains(event.target)) {
                close();
            }
        });

        new MutationObserver(stripNativeList).observe(input, {
            attributes: true,
            attributeFilter: ['list']
        });

        loadPlaces(geopicker);
    }

    const boot = () => {
        document.querySelectorAll('fx-fore#geopicker').forEach(initControl);
    };

    const watchHost = () => {
        const host = document.querySelector('fx-control.fore-control');
        if (host && !host.dataset.geoWatch) {
            host.dataset.geoWatch = 'true';
            new MutationObserver(boot).observe(host, { childList: true });
        }
        boot();
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', watchHost);
    } else {
        watchHost();
    }
    document.addEventListener('ready', watchHost);
})();
