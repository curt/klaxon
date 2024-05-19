const geoOptions = {
    enableHighAccuracy: true,
    timeout: 5000,
    maximumAge: 0,
};

function geoSuccess(pos) {
    const crd = pos.coords;
    const lat = document.getElementById("post_lat")
    const lon = document.getElementById("post_lon")
    const ele = document.getElementById("post_ele")
    lat.value = crd.latitude;
    lon.value = crd.longitude;
    ele.value = crd.altitude;
}

function geoError(pos) {

}

function geoGrab() {
    navigator.geolocation.getCurrentPosition(geoSuccess, geoError, geoOptions)
}

function addGeoJsonToMap(map, geoJsonPath) {
    let xhr = new XMLHttpRequest();
    xhr.open('GET', geoJsonPath);
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.responseType = 'json';
    xhr.onload = function () {
        if (xhr.status !== 200) return
        var layer = L.geoJSON(xhr.response, {
            style: {
                "color": "#ff0000",
                "weight": 20,
                "opacity": 1
            }
        }).addTo(map);
    };
    xhr.send();
}
