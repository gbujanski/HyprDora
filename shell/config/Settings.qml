pragma Singleton

import QtQuick
import Quickshell

// Ustawienia, które użytkownik może chcieć zmienić bez szukania po kodzie.
Singleton {
    // Pogoda (Open-Meteo, bez klucza). Współrzędne zamiast nazwy miasta,
    // żeby wynik nie zależał od wyszukiwarki miejscowości.
    readonly property string weatherPlace: "Warszawa"
    readonly property real weatherLatitude: 52.23
    readonly property real weatherLongitude: 21.01
    readonly property int weatherInterval: 30 * 60 * 1000
    readonly property int weatherRetry: 5 * 60 * 1000
    // Starszego wyniku nie pokazujemy, żeby pasek nie udawał aktualnej pogody.
    readonly property int weatherMaxAge: 3 * 60 * 60 * 1000

    // Minimalny odstęp w ms między zmianami miesiąca przy przewijaniu kalendarza.
    // Większa wartość spowalnia przewijanie gładzikiem.
    readonly property int calendarScrollDelay: 100

    // Najniższa jasność ekranu jako ułamek mocy podświetlenia; to jest 0% na
    // suwaku i przy klawiszach. 0.004 to ok. 0,4% (na tym ekranie wartość 11 z 2777),
    // ostatnia jeszcze czytelna. Wyżej: jaśniejsze minimum.
    readonly property real brightnessMinimum: 0.016

    // Progi ostrzeżeń o baterii (ułamek naładowania), takie jak w UPower.conf.
    // Przy 2% UPower sam hibernuje albo wyłącza laptopa.
    readonly property real batteryLow: 0.20
    readonly property real batteryCritical: 0.05

    // Statystyki systemu, odczytywane tylko przy otwartym panelu.
    readonly property int statsInterval: 2000

    // Pełny widok procesów, tak samo jak w waybarze.
    readonly property var btopCommand: ["alacritty", "--class", "systui", "-e", "btop"]
}
