pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Weather from Open-Meteo, cached on disk so the bar has a result right after a restart.
// Without a network the last result stays until it is older than weatherMaxAge.
Singleton {
    id: root

    // { temp, feels, code, isDay, wind, humidity }
    property var current: null
    // [{ date: "YYYY-MM-DD", code, max, min, precipitation }]
    property var daily: []
    property string sunrise: ""
    property string sunset: ""
    property real fetchedAt: 0

    property bool loading: false
    property string error: ""

    readonly property bool available: current !== null

    readonly property string url: !Settings.hasWeatherLocation ? "" : "https://api.open-meteo.com/v1/forecast" + `?latitude=${Settings.weatherLatitude}&longitude=${Settings.weatherLongitude}` + "&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,relative_humidity_2m" + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset" + "&timezone=auto&forecast_days=6"

    property var request: null
    // Whether the saved result for the current location has been looked at, which the schedule waits for.
    property bool cacheRead: false

    onUrlChanged: {
        const pending = request;
        request = null;
        pending?.abort();
        timeout.stop();
        loading = false;
        error = "";
        current = null;
        daily = [];
        fetchedAt = 0;
        cacheRead = false;
        schedule.retrying = false;
        cache.reload();
    }

    /**
     * Returns the age of the last result.
     * @returns {real} milliseconds, Infinity when none
     */
    function age() {
        return fetchedAt > 0 ? Date.now() - fetchedAt : Infinity;
    }

    /** Refreshes only when the result is older than the interval. Called when the calendar opens. */
    function refreshIfStale() {
        if (age() >= Settings.weatherInterval)
            refresh();
    }

    /** Fetches the weather. */
    function refresh() {
        if (loading || url === "")
            return;
        loading = true;
        const xhr = new XMLHttpRequest();
        request = xhr;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || request !== xhr)
                return;
            request = null;
            timeout.stop();
            loading = false;
            if (xhr.status === 200 && apply(xhr.responseText, Date.now())) {
                error = "";
                cache.setText(JSON.stringify({
                    url,
                    fetchedAt,
                    current,
                    daily,
                    sunrise,
                    sunset
                }));
                schedule.succeeded();
            } else {
                fail(xhr.status === 0 ? I18n.t("weather.error.noConnection") : I18n.t("weather.error.server", {
                    status: xhr.status
                }));
            }
        };
        xhr.open("GET", url);
        xhr.send();
        timeout.restart();
    }

    /**
     * Records a failed fetch; the schedule tries again sooner.
     * @param {string} message  user message
     */
    function fail(message) {
        error = message;
        loading = false;
        dropIfTooOld();
        schedule.failed();
    }

    /** Drops a result older than weatherMaxAge. */
    function dropIfTooOld() {
        if (current !== null && age() > Settings.weatherMaxAge) {
            current = null;
            daily = [];
        }
    }

    /**
     * Stores a server response.
     * @param {string} text  response body
     * @param {real} time  fetch timestamp
     * @returns {bool} whether the response was valid
     */
    function apply(text, time) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            return false;
        }
        const c = data?.current;
        const d = data?.daily;
        if (!c || !d || !Array.isArray(d.time))
            return false;
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

    /**
     * Restores the disk cache, which holds processed data rather than a server response.
     * @param {string} text  cache contents
     */
    function applyCache(text) {
        try {
            const saved = JSON.parse(text);
            if (saved.url !== url || !saved.current || !(saved.fetchedAt > 0))
                return;
            current = saved.current;
            daily = saved.daily ?? [];
            sunrise = saved.sunrise ?? "";
            sunset = saved.sunset ?? "";
            fetchedAt = saved.fetchedAt;
            dropIfTooOld();
        } catch (e) {}
    }

    /**
     * Returns a description for a WMO weather code.
     * @param {int} code  WMO code
     * @returns {string}
     */
    function describe(code) {
        switch (code) {
        case 0:
            return I18n.t("weather.code.clear");
        case 1:
            return I18n.t("weather.code.mostlyClear");
        case 2:
            return I18n.t("weather.code.partlyCloudy");
        case 3:
            return I18n.t("weather.code.overcast");
        case 45:
        case 48:
            return I18n.t("weather.code.fog");
        case 51:
        case 53:
        case 55:
            return I18n.t("weather.code.drizzle");
        case 56:
        case 57:
            return I18n.t("weather.code.freezingDrizzle");
        case 61:
            return I18n.t("weather.code.lightRain");
        case 63:
            return I18n.t("weather.code.rain");
        case 65:
            return I18n.t("weather.code.heavyRain");
        case 66:
        case 67:
            return I18n.t("weather.code.freezingRain");
        case 71:
            return I18n.t("weather.code.lightSnow");
        case 73:
            return I18n.t("weather.code.snow");
        case 75:
            return I18n.t("weather.code.heavySnow");
        case 77:
            return I18n.t("weather.code.snowGrains");
        case 80:
        case 81:
            return I18n.t("weather.code.showers");
        case 82:
            return I18n.t("weather.code.violentShowers");
        case 85:
        case 86:
            return I18n.t("weather.code.snowShowers");
        case 95:
            return I18n.t("weather.code.thunderstorm");
        case 96:
        case 99:
            return I18n.t("weather.code.hail");
        default:
            return I18n.t("weather.code.unknown");
        }
    }

    /**
     * Formats a temperature in whole degrees.
     * @param {real} value  temperature
     * @returns {string}
     */
    function formatTemp(value) {
        if (value === null || value === undefined || isNaN(value))
            return "–";
        // Avoids "-0°".
        const rounded = Math.round(value);
        return `${rounded === 0 ? 0 : rounded}°`;
    }

    FileView {
        id: cache
        path: Quickshell.cachePath("weather.json")
        // The schedule starts from the saved result, so a restarted shell does not fetch a fresh one again.
        onLoaded: {
            root.applyCache(text());
            schedule.lastRun = root.fetchedAt;
            root.cacheRead = true;
        }
        onLoadFailed: {
            schedule.lastRun = 0;
            root.cacheRead = true;
        }
    }

    // Weather is small, so it is fetched on a metered network too.
    ScheduledTask {
        id: schedule
        interval: Settings.weatherInterval
        retryInterval: Settings.weatherRetry
        enabled: root.url !== "" && root.cacheRead
        allowMetered: true
        onRun: root.refresh()
    }

    Timer {
        id: timeout
        interval: 15000
        onTriggered: {
            const xhr = root.request;
            root.request = null;
            xhr?.abort();
            root.fail(I18n.t("weather.error.timeout"));
        }
    }

    IpcHandler {
        target: "weather"

        function refresh(): void {
            root.refresh();
        }
        function describe(): string {
            return JSON.stringify({
                available: root.available,
                loading: root.loading,
                error: root.error,
                fetchedAt: root.fetchedAt,
                current: root.current,
                daily: root.daily,
                sunrise: root.sunrise,
                sunset: root.sunset
            });
        }
    }
}
