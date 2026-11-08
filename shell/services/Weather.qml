pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Pogoda z Open-Meteo: pobierana co 30 min, z kopią na dysku, żeby po restarcie
// shella pasek od razu miał wynik. Bez sieci zostaje ostatni wynik, dopóki nie
// jest starszy niż weatherMaxAge.
Singleton {
    id: root

    // { temp, feels, code, isDay, wind, humidity }
    property var current: null
    // [{ date: "RRRR-MM-DD", code, max, min, precipitation }]
    property var daily: []
    property string sunrise: ""
    property string sunset: ""
    property real fetchedAt: 0

    property bool loading: false
    property string error: ""

    readonly property bool available: current !== null

    readonly property string url: "https://api.open-meteo.com/v1/forecast"
        + `?latitude=${Settings.weatherLatitude}&longitude=${Settings.weatherLongitude}`
        + "&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,relative_humidity_2m"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
        + "&timezone=auto&forecast_days=6"

    property var request: null

    function age() {
        return fetchedAt > 0 ? Date.now() - fetchedAt : Infinity;
    }

    // Odświeża tylko wtedy, gdy wynik jest starszy niż interwał. Wołane przy
    // otwarciu kalendarza i po odzyskaniu sieci (np. po wybudzeniu, gdy
    // timer stał razem z systemem).
    function refreshIfStale() {
        if (age() >= Settings.weatherInterval) refresh();
    }

    function refresh() {
        if (loading) return;
        loading = true;
        const xhr = new XMLHttpRequest();
        request = xhr;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || request !== xhr) return;
            request = null;
            timeout.stop();
            loading = false;
            if (xhr.status === 200 && apply(xhr.responseText, Date.now())) {
                error = "";
                cache.setText(JSON.stringify({ fetchedAt, current, daily, sunrise, sunset }));
                retry.stop();
            } else {
                fail(xhr.status === 0 ? "Brak połączenia z serwerem pogody" : `Błąd serwera pogody (${xhr.status})`);
            }
        };
        xhr.open("GET", url);
        xhr.send();
        timeout.restart();
    }

    function fail(message) {
        error = message;
        loading = false;
        dropIfTooOld();
        retry.restart();
    }

    function dropIfTooOld() {
        if (current !== null && age() > Settings.weatherMaxAge) {
            current = null;
            daily = [];
        }
    }

    function apply(text, time) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return false;
        }
        const c = data?.current;
        const d = data?.daily;
        if (!c || !d || !Array.isArray(d.time)) return false;
        current = {
            temp: c.temperature_2m,
            feels: c.apparent_temperature,
            code: c.weather_code,
            isDay: c.is_day === 1,
            wind: c.wind_speed_10m,
            humidity: c.relative_humidity_2m
        };
        daily = d.time.map((date, i) => ({
            date,
            code: d.weather_code[i],
            max: d.temperature_2m_max[i],
            min: d.temperature_2m_min[i],
            precipitation: d.precipitation_probability_max?.[i] ?? null
        }));
        sunrise = (d.sunrise?.[0] ?? "").slice(11, 16);
        sunset = (d.sunset?.[0] ?? "").slice(11, 16);
        fetchedAt = time;
        return true;
    }

    // Kopia na dysku zawiera już przetworzone dane, a nie odpowiedź serwera.
    function applyCache(text) {
        try {
            const saved = JSON.parse(text);
            if (!saved.current || !(saved.fetchedAt > 0)) return;
            current = saved.current;
            daily = saved.daily ?? [];
            sunrise = saved.sunrise ?? "";
            sunset = saved.sunset ?? "";
            fetchedAt = saved.fetchedAt;
            dropIfTooOld();
        } catch (e) {}
    }

    // Kody WMO używane przez Open-Meteo.
    function describe(code) {
        switch (code) {
        case 0: return "Bezchmurnie";
        case 1: return "Przeważnie bezchmurnie";
        case 2: return "Częściowe zachmurzenie";
        case 3: return "Pochmurno";
        case 45: case 48: return "Mgła";
        case 51: case 53: case 55: return "Mżawka";
        case 56: case 57: return "Marznąca mżawka";
        case 61: return "Słaby deszcz";
        case 63: return "Deszcz";
        case 65: return "Ulewny deszcz";
        case 66: case 67: return "Marznący deszcz";
        case 71: return "Słaby śnieg";
        case 73: return "Śnieg";
        case 75: return "Intensywny śnieg";
        case 77: return "Ziarnisty śnieg";
        case 80: case 81: return "Przelotny deszcz";
        case 82: return "Gwałtowna ulewa";
        case 85: case 86: return "Przelotny śnieg";
        case 95: return "Burza";
        case 96: case 99: return "Burza z gradem";
        default: return "Nieznana pogoda";
        }
    }

    function formatTemp(value) {
        if (value === null || value === undefined || isNaN(value)) return "–";
        // Bez „-0°”.
        const rounded = Math.round(value);
        return `${rounded === 0 ? 0 : rounded}°`;
    }

    FileView {
        id: cache
        path: Quickshell.cachePath("weather.json")
        onLoaded: {
            root.applyCache(text());
            root.refreshIfStale();
        }
        onLoadFailed: root.refresh()
    }

    Timer {
        interval: Settings.weatherInterval
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: retry
        interval: Settings.weatherRetry
        onTriggered: root.refresh()
    }

    Timer {
        id: timeout
        interval: 15000
        onTriggered: {
            const xhr = root.request;
            root.request = null;
            xhr?.abort();
            root.fail("Serwer pogody nie odpowiada");
        }
    }

    Connections {
        target: Network
        function onConnectedChanged() {
            if (Network.connected) root.refreshIfStale();
        }
    }

    IpcHandler {
        target: "weather"

        function refresh(): void { root.refresh(); }
        function describe(): string {
            return JSON.stringify({ available: root.available, loading: root.loading, error: root.error, fetchedAt: root.fetchedAt, current: root.current, daily: root.daily, sunrise: root.sunrise, sunset: root.sunset });
        }
    }
}
