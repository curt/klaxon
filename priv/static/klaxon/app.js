const geoOptions = {
    enableHighAccuracy: true,
    timeout: 5000,
    maximumAge: 0,
};

function geoSuccess(pos) {
    const crd = pos.coords;
    const lat = document.getElementById("post_lat") ?? document.getElementById("place_lat")
    const lon = document.getElementById("post_lon") ?? document.getElementById("place_lon")
    const ele = document.getElementById("post_ele") ?? document.getElementById("place_ele")
    lat.value = crd.latitude;
    lon.value = crd.longitude;
    ele.value = crd.altitude;
}

function geoError(pos) {

}

function geoGrab() {
    navigator.geolocation.getCurrentPosition(geoSuccess, geoError, geoOptions)
}