pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Dark or light, chosen under Appearance in the settings.
    readonly property bool light: Settings.theme === "light"

    readonly property var dark: ({
            background: "#181818",
            surface: "#2a2a2a",
            surfaceHover: "#333333",
            foreground: "#e6e6e6",
            muted: "#9a9a9a",
            dim: "#5c5c5c",
            accent: "#2fcf5e",
            accentText: "#0c1a10",
            accentSoft: "#1d3a26",
            warning: "#ff9900",
            error: "#fb4b4b"
        })
    // A darker green and amber keep the accents readable on a light background.
    readonly property var lightPalette: ({
            background: "#f6f6f6",
            surface: "#e6e6e6",
            surfaceHover: "#dadada",
            foreground: "#1e1e1e",
            muted: "#5e5e5e",
            dim: "#a2a2a2",
            accent: "#1f9e46",
            accentText: "#ffffff",
            accentSoft: "#d3efdb",
            warning: "#c46f00",
            error: "#d43838"
        })
    readonly property var palette: light ? lightPalette : dark

    // Colors
    readonly property color background: palette.background
    readonly property color surface: palette.surface
    readonly property color surfaceHover: palette.surfaceHover
    readonly property color foreground: palette.foreground
    readonly property color muted: palette.muted
    readonly property color dim: palette.dim
    readonly property color accent: palette.accent
    readonly property color accentText: palette.accentText
    readonly property color accentSoft: palette.accentSoft
    readonly property color warning: palette.warning
    readonly property color error: palette.error
    readonly property color captureDim: "#80000000"

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
