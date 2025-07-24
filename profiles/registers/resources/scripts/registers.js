document.addEventListener('DOMContentLoaded', function() {
    const map = document.querySelector('pb-leaflet-map');

    document.addEventListener('pb-page-ready', function(ev) {
        if (document.querySelector('pb-split-list')) {
            const endpoint = ev.detail.endpoint;
            
            map.addEventListener('pb-ready', function(ev) {
                const url = `${endpoint}/api/places/all`;
                console.log(`fetching places from: ${url}`);
                fetch(url)
                .then(function(response) {
                    return response.json();
                })
                .then(function(json) {
                    pbEvents.emit("pb-update-map", "map", json)
                });
        
                pbEvents.subscribe('pb-leaflet-marker-click', 'map', function(ev) {
                    const id = ev.detail.element.id;
                    window.location = `places/${id}`;
                });
            });
        }
    });
});