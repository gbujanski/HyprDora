pragma Singleton

import QtQuick
import Quickshell

// Nerd Font glyphs given as code points, independent of editors and file encodings.
Singleton {
    /**
     * Returns the character for a code point.
     * @param {int} code  code point
     * @returns {string}
     */
    function glyph(code) {
        return String.fromCodePoint(code);
    }

    /**
     * Returns the Wi-Fi icon for a signal level.
     * @param {real} strength  signal, 0..1
     * @returns {string}
     */
    function wifi(strength) {
        if (strength > 0.75)
            return glyph(0xF0928);
        if (strength > 0.5)
            return glyph(0xF0925);
        if (strength > 0.25)
            return glyph(0xF0922);
        return glyph(0xF091F);
    }
    readonly property string wifiOff: glyph(0xF092E)
    readonly property string lock: glyph(0xF033E)
    readonly property string settings: glyph(0xF0493)
    readonly property string idle: glyph(0xF04B2)
    readonly property string coffee: glyph(0xF0176)
    readonly property string update: glyph(0xF06B0)
    readonly property string vpn: glyph(0xF099D)
    readonly property string arrowUp: glyph(0xF005D)
    readonly property string arrowDown: glyph(0xF0045)
    readonly property string ethernet: glyph(0xF0200)
    readonly property string webcam: glyph(0xF05A0)
    readonly property string screenShare: glyph(0xF1483)
    readonly property string microphoneOn: glyph(0xF036C)
    readonly property string language: glyph(0xF05CA)
    readonly property string place: glyph(0xF034E)
    readonly property string search: glyph(0xF0349)
    readonly property string trash: glyph(0xF0A7A)
    readonly property string close: glyph(0xF0156)
    readonly property string camera: glyph(0xF0100)
    readonly property string video: glyph(0xF0567)
    readonly property string record: glyph(0xF044A)
    readonly property string captureArea: glyph(0xF0A73)
    readonly property string captureScreen: glyph(0xF0379)
    readonly property string captureWindow: glyph(0xF05AF)
    readonly property string alert: glyph(0xF0026)
    readonly property string plus: glyph(0xF0415)
    /**
     * Returns the password visibility icon.
     * @param {bool} visible  whether the text is shown
     * @returns {string}
     */
    function eye(visible) {
        return glyph(visible ? 0xF0208 : 0xF0209);
    }

    /**
     * Returns the volume icon.
     * @param {real} level  volume, 0..1
     * @param {bool} muted  whether muted
     * @returns {string}
     */
    function volume(level, muted) {
        if (muted || level <= 0)
            return glyph(0xF0581);
        if (level < 0.34)
            return glyph(0xF057F);
        if (level < 0.67)
            return glyph(0xF0580);
        return glyph(0xF057E);
    }

    /**
     * Returns the microphone icon.
     * @param {bool} muted  whether muted
     * @returns {string}
     */
    function microphone(muted) {
        return glyph(muted ? 0xF036D : 0xF036C);
    }
    readonly property string chevronLeft: glyph(0xF0141)
    readonly property string chevronRight: glyph(0xF0142)
    readonly property string chevronDown: glyph(0xF0140)
    readonly property string chevronUp: glyph(0xF0143)
    readonly property string monitor: glyph(0xF0379)
    readonly property string back: glyph(0xF004D)
    readonly property string check: glyph(0xF012C)
    readonly property string tune: glyph(0xF062E)
    readonly property string application: glyph(0xF03D8)

    readonly property string bluetooth: glyph(0xF00AF)
    readonly property string bluetoothOff: glyph(0xF00B2)
    readonly property string brightness: glyph(0xF00DF)
    readonly property string keyboard: glyph(0xF030C)
    readonly property string balanced: glyph(0xF05D1)

    /**
     * Returns an icon for a Bluetooth device type.
     * @param {string} icon  BlueZ icon name
     * @returns {string}
     */
    function bluetoothDevice(icon) {
        const name = icon ?? "";
        if (name.includes("headset") || name.includes("headphone"))
            return glyph(0xF02CB);
        if (name.includes("audio"))
            return glyph(0xF04C3);
        if (name.includes("mouse"))
            return glyph(0xF037D);
        if (name.includes("keyboard"))
            return glyph(0xF030C);
        if (name.includes("phone"))
            return glyph(0xF011C);
        if (name.includes("computer"))
            return glyph(0xF0322);
        if (name.includes("gaming"))
            return glyph(0xF0297);
        return bluetooth;
    }
    readonly property string bluetoothConnected: glyph(0xF00B1)

    /**
     * Returns the battery icon.
     * @param {real} level  charge, 0..1
     * @param {bool} charging  whether charging
     * @returns {string}
     */
    function battery(level, charging) {
        if (charging)
            return glyph(0xF0084);
        if (level >= 0.95)
            return glyph(0xF0079);
        if (level < 0.05)
            return glyph(0xF0083);
        return glyph(0xF007A + Math.max(0, Math.min(8, Math.floor(level * 10) - 1)));
    }

    readonly property string music: glyph(0xF075A)
    readonly property string play: glyph(0xF040A)
    readonly property string pause: glyph(0xF03E4)
    readonly property string next: glyph(0xF04AD)
    readonly property string previous: glyph(0xF04AE)
    readonly property string swap: glyph(0xF04E1)

    readonly property string power: glyph(0xF0425)
    readonly property string sleep: glyph(0xF04B2)
    readonly property string logout: glyph(0xF0343)
    readonly property string restart: glyph(0xF0709)

    readonly property string bell: glyph(0xF009A)
    readonly property string bellBadge: glyph(0xF116B)
    readonly property string bellOff: glyph(0xF009B)
    readonly property string performance: glyph(0xF0463)
    readonly property string powerSaver: glyph(0xF032A)

    readonly property string cpu: glyph(0xF035B)
    readonly property string memory: glyph(0xF061A)
    readonly property string processes: glyph(0xF012A)
    readonly property string flash: glyph(0xF0241)
    readonly property string health: glyph(0xF02D1)

    readonly property string calendar: glyph(0xF00ED)
    readonly property string refresh: glyph(0xF0450)
    readonly property string thermometer: glyph(0xF050F)
    readonly property string wind: glyph(0xF059D)
    readonly property string humidity: glyph(0xF058E)
    readonly property string umbrella: glyph(0xF054A)
    readonly property string sunrise: glyph(0xF059C)
    readonly property string sunset: glyph(0xF059B)

    /**
     * Returns the icon for a WMO weather code.
     * @param {int} code  WMO code
     * @param {bool} isDay  whether it is daytime
     * @returns {string}
     */
    function weather(code, isDay) {
        const day = isDay ?? true;
        switch (code) {
        case 0:
            return glyph(day ? 0xF0599 : 0xF0594);
        case 1:
        case 2:
            return glyph(day ? 0xF0595 : 0xF0F31);
        case 3:
            return glyph(0xF0590);
        case 45:
        case 48:
            return glyph(0xF0591);
        case 51:
        case 53:
        case 55:
        case 61:
        case 63:
            return glyph(0xF0597);
        case 65:
        case 80:
        case 81:
        case 82:
            return glyph(0xF0596);
        case 56:
        case 57:
        case 66:
        case 67:
            return glyph(0xF067F);
        case 71:
        case 73:
        case 77:
        case 85:
            return glyph(0xF0598);
        case 75:
        case 86:
            return glyph(0xF0F36);
        case 95:
            return glyph(0xF067E);
        case 96:
        case 99:
            return glyph(0xF0592);
        default:
            return glyph(0xF0590);
        }
    }
}
