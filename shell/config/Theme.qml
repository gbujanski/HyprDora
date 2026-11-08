pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Colors
    readonly property color background: "#181818"
    readonly property color surface: "#2a2a2a"
    readonly property color surfaceHover: "#333333"
    readonly property color foreground: "#e6e6e6"
    readonly property color muted: "#9a9a9a"
    readonly property color dim: "#5c5c5c"
    readonly property color accent: "#2fcf5e"
    readonly property color accentText: "#0c1a10"
    readonly property color accentSoft: "#1d3a26"
    readonly property color warning: "#ff9900"
    readonly property color error: "#fb4b4b"

    // Fonts
    readonly property string fontFamily: "Adwaita Sans"
    readonly property string iconFamily: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 13
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeTitle: 15
    readonly property int iconSize: 16

    // Sizes
    readonly property int barHeight: 30
    readonly property int spacing: 4
    readonly property int radius: 6

    // Animations
    readonly property int animFast: 120
    readonly property int animPanel: 160

    // Panels
    readonly property int panelWidth: 380
    readonly property int panelMargin: 6
    readonly property int panelPadding: 14
    readonly property int panelRadius: 12
}
