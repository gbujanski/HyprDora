import QtQuick
import qs.config
import qs.components
import qs.services

// Weather location, found by name through the Open-Meteo place search while the user types.
Column {
    id: root

    property var results: []
    // "", "searching", "empty" or "error".
    property string status: ""
    property var request: null
    property string lastQuery: ""
    readonly property int minimumLength: 3

    /**
     * Schedules a search after typing pauses, or clears the results for a short query.
     * @param {string} text  current field contents
     */
    function queue(text) {
        if (text.trim().length >= minimumLength) {
            typingPause.restart();
            return;
        }
        typingPause.stop();
        cancel();
        results = [];
        status = "";
        lastQuery = "";
    }

    /** Stops a running search. */
    function cancel() {
        const xhr = request;
        request = null;
        xhr?.abort();
        timeout.stop();
    }

    /**
     * Searches for places by name.
     * @param {string} text  place name typed by the user
     */
    function search(text) {
        const query = text.trim();
        if (query.length < minimumLength || query === lastQuery)
            return;
        lastQuery = query;
        cancel();
        const xhr = new XMLHttpRequest();
        request = xhr;
        status = "searching";
        results = [];
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || root.request !== xhr)
                return;
            root.request = null;
            timeout.stop();
            root.finish(xhr);
        };
        xhr.open("GET", `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(query)}&count=6&language=${I18n.language}&format=json`);
        xhr.send();
        timeout.restart();
    }

    /**
     * Turns a finished search into the result list.
     * @param {XMLHttpRequest} xhr  finished request
     */
    function finish(xhr) {
        if (xhr.status !== 200) {
            status = "error";
            lastQuery = "";
            return;
        }
        try {
            const places = JSON.parse(xhr.responseText).results ?? [];
            results = places.map(p => ({
                        name: p.name,
                        detail: [p.admin1, p.country].filter(Boolean).join(", "),
                        latitude: p.latitude,
                        longitude: p.longitude
                    }));
            status = results.length > 0 ? "" : "empty";
        } catch (e) {
            status = "error";
            lastQuery = "";
        }
    }

    /**
     * Saves a found place as the weather location.
     * @param {object} place  search result
     */
    function choose(place) {
        Settings.set("weather", {
            place: place.name,
            latitude: place.latitude,
            longitude: place.longitude
        });
        results = [];
        status = "";
        lastQuery = "";
        typingPause.stop();
        field.clear();
    }

    spacing: 6

    // Long enough not to search between keystrokes of normal typing.
    Timer {
        id: typingPause
        interval: 300
        onTriggered: root.search(field.text)
    }

    Timer {
        id: timeout
        interval: 10000
        onTriggered: {
            const xhr = root.request;
            root.request = null;
            xhr?.abort();
            root.status = "error";
            root.lastQuery = "";
        }
    }

    Row {
        width: parent.width
        spacing: 8

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.place
            color: Settings.hasWeatherLocation ? Theme.accent : Theme.muted
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 60
            text: Settings.hasWeatherLocation ? Settings.weatherPlace : I18n.t("weather.notSet")
            color: Settings.hasWeatherLocation ? Theme.foreground : Theme.muted
            elide: Text.ElideRight
        }
    }

    TextField {
        id: field
        width: parent.width
        placeholder: I18n.t("weather.search")
        onTextChanged: root.queue(text)
        onAccepted: {
            typingPause.stop();
            root.search(text);
        }
        onCancelled: Panels.settingsMenuOpen = false
    }

    Row {
        visible: root.status !== ""
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.status === "searching"
            text: Icons.loading
            color: Theme.muted

            RotationAnimator on rotation {
                running: root.status === "searching"
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.status === "searching" ? I18n.t("weather.searching") : root.status === "empty" ? I18n.t("weather.noPlaces") : I18n.t("weather.searchFailed")
            color: root.status === "error" ? Theme.error : Theme.muted
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    Repeater {
        model: root.results

        ListRow {
            required property var modelData
            width: root.width
            text: modelData.detail !== "" ? `${modelData.name}, ${modelData.detail}` : modelData.name
            onClicked: root.choose(modelData)
        }
    }

    TextButton {
        visible: Settings.hasWeatherLocation
        text: I18n.t("weather.clearPlace")
        onClicked: Settings.set("weather", undefined)
    }
}
