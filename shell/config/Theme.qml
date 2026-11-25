pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Dark or light, chosen under Appearance in the settings.
    readonly property bool light: Settings.theme === "light"

    readonly property var dark: ({
            background: "#181818",
            // Between the background and a surface: an unfolded list and the row it unfolds from.
            surfaceLow: "#212121",
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
            surfaceLow: "#eeeeee",
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
    readonly property color surfaceLow: palette.surfaceLow
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
    // Week numbers and day names in the calendar.
    readonly property int fontSizeTiny: 10
    // The launcher's search field and the calendar's date.
    readonly property int fontSizeLarge: 18
    // A code to compare, such as when pairing Bluetooth.
    readonly property int fontSizeHuge: 24
    // The temperature in the weather.
    readonly property int fontSizeDisplay: 28
    readonly property int iconSize: 16
    // Beside text in a row: arrows, a lock, repetition.
    readonly property int iconSizeSmall: 14
    // A tile's, a list row's or the indicator's icon.
    readonly property int iconSizeLarge: 20
    // In place of an application's image, when there is none.
    readonly property int iconSizeImage: 22
    // In place of a cover.
    readonly property int iconSizeCover: 28
    // The large icon at the head of a panel, such as the battery's or the weather's.
    readonly property int iconSizeHero: 34

    // Sizes
    readonly property int barHeight: 30
    readonly property int spacing: 4
    readonly property int radius: 6
    // Scroll bars, marks and handles.
    readonly property int radiusTiny: 2
    // The screens in the display layout.
    readonly property int radiusSmall: 4

    // Animations
    readonly property int animFast: 120
    readonly property int animPanel: 160

    // Panels
    readonly property int panelWidth: 380
    readonly property int panelMargin: 6
    readonly property int panelPadding: 14
    readonly property int panelRadius: 12
}
