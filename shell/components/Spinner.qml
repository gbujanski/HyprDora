import QtQuick
import qs.config

// Rotating arc shown while something searches or loads. Drawn rather than taken from the icon font,
// whose glyphs sit off center and would wobble while turning.
Item {
    id: root

    property bool running: true
    property color color: Theme.muted

    implicitWidth: 12
    implicitHeight: 12
    visible: running

    Canvas {
        id: arc
        anchors.fill: parent
        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.lineWidth = 2;
            context.lineCap = "round";
            context.strokeStyle = root.color;
            context.beginPath();
            context.arc(width / 2, height / 2, width / 2 - 1.5, 0, Math.PI * 1.5);
            context.stroke();
        }

        RotationAnimator on rotation {
            running: root.running && root.visible
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
    }

    onColorChanged: arc.requestPaint()
}
