pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property BacklightDevice display: BacklightDevice {
        deviceClass: "backlight"
        exponent: 3
        minimumFraction: Settings.brightnessMinimum
    }

    readonly property BacklightDevice keyboard: BacklightDevice {
        deviceClass: "leds"
        nameContains: "kbd_backlight"
    }

    IpcHandler {
        target: "brightness"

        function describe(): string {
            return JSON.stringify({
                display: {
                    device: root.display.device,
                    raw: root.display.raw,
                    max: root.display.maxRaw,
                    level: root.display.level
                },
                keyboard: {
                    device: root.keyboard.device,
                    raw: root.keyboard.raw,
                    max: root.keyboard.maxRaw,
                    level: root.keyboard.level
                }
            });
        }
        // For the brightness keys, which show the indicator: step 0.05 / step -0.05.
        function step(delta: real): void {
            root.display.step(delta);
            Indicator.show("display");
        }
        function set(value: real): void {
            root.display.setLevel(value);
        }
        function get(): real {
            return root.display.level;
        }
        function stepKeyboard(delta: real): void {
            root.keyboard.step(delta);
            Indicator.show("keyboard");
        }
        function setDisplay(value: real): void {
            root.display.setLevel(value);
        }
        function setKeyboard(value: real): void {
            root.keyboard.setLevel(value);
        }
    }
}
