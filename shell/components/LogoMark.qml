import QtQuick
import QtQuick.Shapes
import qs.config

// HyprDora's mark as a one-colour glyph: a lowercase h drawn as one round stroke, a stem and an arch, sized like an
// icon from the icon font.
Item {
    id: root

    property color color: Theme.foreground
    property int size: Theme.iconSize

    readonly property real stroke: Math.max(2, Math.round(size * 0.14))
    readonly property real glyphHeight: Math.round(size * 0.875)
    readonly property real glyphWidth: Math.round(glyphHeight * 0.62)
    // Centres of the stroke's ends, kept inside the glyph's box.
    readonly property real leftEdge: stroke / 2
    readonly property real rightEdge: glyphWidth - stroke / 2
    readonly property real topEdge: stroke / 2
    readonly property real bottomEdge: glyphHeight - stroke / 2
    readonly property real archRadius: (rightEdge - leftEdge) / 2
    // Where the arch leaves the stem, a little above the middle.
    readonly property real archTop: glyphHeight * 0.36

    implicitWidth: size
    implicitHeight: size

    Shape {
        // Centred on whole pixels, so the stems stay sharp.
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: root.glyphWidth
        height: root.glyphHeight
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            startX: root.leftEdge
            startY: root.topEdge

            PathLine {
                x: root.leftEdge
                y: root.bottomEdge
            }
            PathMove {
                x: root.leftEdge
                y: root.archTop + root.archRadius
            }
            PathArc {
                x: root.rightEdge
                y: root.archTop + root.archRadius
                radiusX: root.archRadius
                radiusY: root.archRadius
            }
            PathLine {
                x: root.rightEdge
                y: root.bottomEdge
            }
        }
    }
}
