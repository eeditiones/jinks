document.addEventListener('DOMContentLoaded', function() {
    const map = document.querySelector('pb-leaflet-map');
    const page = document.querySelector('pb-page');

    if (document.querySelector('pb-split-list')) {
        const endpoint = page.endpoint;
        
        pbEvents.ifReady(map)
        .then(() => {
            const url = `${endpoint}/api/places/all`;
            console.log(`fetching places from: ${url}`);
            fetch(url)
            .then(function(response) {
                return response.json();
            })
            .then(function(json) {
                pbEvents.emit("pb-update-map", "map", json)
            })
            .catch(function(err) {
                // Navigation away from the page aborts the in-flight fetch
                if (err.name !== 'AbortError') {
                    console.error(err);
                }
            });
    
            pbEvents.subscribe('pb-leaflet-marker-click', 'map', function(ev) {
                const id = ev.detail.element.id;
                window.location = `places/${id}`;
            });
        });
    }
});