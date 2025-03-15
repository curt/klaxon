// gpx-map.js

function initializeGPXMap(mapId, infoId, sliderId, gpxUrl) {
    // Check if Leaflet is loaded
    if (typeof L === "undefined") {
        console.error("Leaflet is not loaded. Ensure Leaflet.js is included in your HTML.");
        return;
    }

    // Create the map
    const map = L.map(mapId).setView([0, 0], 5);

    var trackpoints = [];
    var times = [];
    var totalDistance = 0;
    var trackDistances = [];
    var marker = L.marker([0, 0]).addTo(map).bindPopup("Start");

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

        // Extract track points
        e.target.eachLayer(function (layer) {
            if (layer.getLayers() instanceof Array) {
                layer.getLayers().forEach(innerLayer => {
                    if (typeof innerLayer.getLatLngs === "function") {
                        var latlngs = innerLayer.getLatLngs().flat();
                        trackpoints = latlngs;

                        // Calculate cumulative distances
                        totalDistance = 0;
                        trackDistances = [0]; // First point starts at 0 distance

                        for (var i = 1; i < latlngs.length; i++) {
                            var d = latlngs[i - 1].distanceTo(latlngs[i]);
                            totalDistance += d;
                            trackDistances.push(totalDistance);
                        }
                    }
                });
            }
        });
    }).on("addpoint", function (e) {
        let desc = e.element.querySelector('desc')?.textContent || "No description available";
        e.point.bindPopup(desc, { maxWidth: 512 }).openPopup();
    }).addTo(map);

    const formatDate = (date) => {
        const pad = (num) => num.toString().padStart(2, '0');
        return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())} ${pad(date.getUTCHours())}:${pad(date.getUTCMinutes())}:${pad(date.getUTCSeconds())} UTC`;
    };

    // Update marker position based on slider
    document.getElementById(sliderId).addEventListener('input', function () {
        if (trackpoints.length === 0) return;

        var percentage = this.value / 100;
        var targetDistance = totalDistance * percentage;
        var index = trackDistances.findIndex(d => d >= targetDistance);

        if (index === -1) return;

        var latlng = trackpoints[index];
        const formattedTime = latlng.meta?.time ? formatDate(new Date(latlng.meta.time)) : "N/A";
        const message = `Lat: ${latlng.lat.toFixed(6)}, Lng: ${latlng.lng.toFixed(6)}, Distance: ${(targetDistance / 1000).toFixed(2)}km, Time: ${formattedTime}`;
        marker.setLatLng(latlng).bindPopup(message).openPopup();
        document.getElementById(infoId).innerHTML = message;
    });
}

// Export function for modular usage
export { initializeGPXMap };
