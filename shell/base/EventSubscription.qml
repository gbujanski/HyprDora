import QtQuick

// Listens to one of EventSources' sources while it exists and is enabled: a named stream, whose lines
// arrive as event(); a file, whose changes arrive as changed(); or a file read again every pollInterval,
// whose contents arrive in text, with changed().
QtObject {
    id: root

    property string stream: ""
    property string file: ""
    // With file: read it again at this interval, in milliseconds, instead of watching it.
    property int pollInterval: 0
    property bool enabled: true
    // A polled file's contents.
    property string text: ""

    signal event(string line)
    signal changed

    readonly property string key: !enabled ? "" : stream !== "" ? `stream:${stream}` : file === "" ? "" : pollInterval > 0 ? `poll:${pollInterval}:${file}` : `file:${file}`
    // The key it is attached under, kept until it detaches.
    property string attachedKey: ""

    /** Moves to the source of the current key. */
    function reattach() {
        if (attachedKey !== "")
            EventSources.detach(root);
        attachedKey = key;
        if (attachedKey !== "")
            EventSources.attach(root);
    }

    onKeyChanged: reattach()
    Component.onCompleted: reattach()
    Component.onDestruction: {
        if (attachedKey !== "")
            EventSources.detach(root);
    }
}
