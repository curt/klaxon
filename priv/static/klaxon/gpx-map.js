// gpx-map.js

function initializeGPXMap(mapId, gpxUrl) {
    // Check if Leaflet is loaded
    if (typeof L === "undefined") {
        console.error("Leaflet is not loaded. Ensure Leaflet.js is included in your HTML.");
        return;
    }

    // Create the map
    const map = L.map(mapId).setView([0, 0], 5);

    // Add a tile layer
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors",
    }).addTo(map);

    // Define custom icons using jsDelivr-hosted Leaflet images
    const defaultMarker = L.icon({
        iconUrl: "https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-icon.png",
        shadowUrl: "https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-shadow.png",
        iconSize: [25, 41],
        iconAnchor: [12, 41],
        popupAnchor: [1, -34],
        shadowSize: [41, 41]
    });

    const redMarker = L.icon({
        iconUrl: "https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-icon-2x.png",
        shadowUrl: "https://cdn.jsdelivr.net/npm/leaflet@1.9.4/dist/images/marker-shadow.png",
        iconSize: [25, 41],
        iconAnchor: [12, 41],
        popupAnchor: [1, -34],
        shadowSize: [41, 41]
    });

    // Load GPX track with start and end markers
    new L.GPX(gpxUrl, {
        async: true,
        marker_options: {
            startIconUrl: "https://cdn.jsdelivr.net/npm/leaflet-gpx@1.5.0/pin-icon-start.png",
            endIconUrl: "https://cdn.jsdelivr.net/npm/leaflet-gpx@1.5.0/pin-icon-end.png",
            shadowUrl: "https://cdn.jsdelivr.net/npm/leaflet-gpx@1.5.0/pin-shadow.png",
            wptIconUrls: {
                "": "https://cdn.jsdelivr.net/npm/leaflet-gpx@1.5.0/pin-icon-wpt.png",
            },
        }
    }).on("loaded", function (e) {
        map.fitBounds(e.target.getBounds());
    }).addTo(map);
}

// Export function for modular usage
export { initializeGPXMap };
