document.addEventListener('DOMContentLoaded', function() {

    const page = document.querySelector('pb-page');
    const map = document.querySelector('pb-leaflet-map');
    const jsonData = document.getElementById('geodata').textContent;
    const data = JSON.parse(jsonData);

    page.addEventListener('pb-page-ready', function(ev) {
        map.addEventListener('pb-ready', function(ev) {
            pbEvents.emit("pb-update-map", "map", data);
        });
    });
});