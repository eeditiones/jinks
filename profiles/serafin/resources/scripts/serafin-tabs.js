/*
 * When a sidebar tab is shown, Leaflet maps inside it were initialised while the
 * panel was hidden (zero size) and render blank until told to recompute. After
 * layout.js toggles `.tab-panel[hidden]` on a tab click, invalidate any map that
 * is now visible.
 */
document.addEventListener('click', (event) => {
    if (!event.target.closest('.after-tab-btn')) {
        return;
    }
    // let layout.js update the hidden state first, then fix the map
    window.setTimeout(() => {
        document.querySelectorAll('.after .tab-panel:not([hidden]) pb-leaflet-map').forEach((map) => {
            if (map.map && typeof map.map.invalidateSize === 'function') {
                map.map.invalidateSize();
            }
        });
    }, 50);
});
