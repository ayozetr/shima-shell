pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Current weather, from Open-Meteo.
//
// The Plasma widget's data cannot be read from outside, so we fetch it
// ourselves. Open-Meteo needs no API key and returns exactly what a
// single icon needs: a WMO code and whether it is daytime. BBC, which
// is what the Plasma widget uses, has no documented public API.
Singleton {
    id: root

    property bool   ready: false
    property int    code: -1        // WMO weather code
    property bool   isDay: true
    property real   temperature: 0
    property string place: ""

    readonly property bool enabled: Config.data.weatherEnabled ?? true
    readonly property real lat: Config.data.weatherLat ?? 0
    readonly property real lon: Config.data.weatherLon ?? 0
    readonly property bool fahrenheit: Config.data.weatherFahrenheit ?? false
    readonly property string model: Config.data.weatherModel ?? "ukmo_seamless"

    // Rounds half down: at exactly 24.5, JavaScript's Math.round gives
    // 25 while BBC (and therefore Plasma's widget) shows 24. Only the
    // exact half changes; everything else rounds as usual.
    readonly property string temperatureText:
        root.ready ? Math.ceil(root.temperature - 0.5) + "°" : ""

    // WMO code to the freedesktop icon names every theme ships.
    readonly property string iconName: {
        if (!root.ready) return "";
        const n = root.isDay ? "" : "-night";
        const c = root.code;
        if (c === 0)                 return "weather-clear" + n;
        if (c === 1)                 return "weather-few-clouds" + n;
        if (c === 2)                 return "weather-clouds" + n;
        if (c === 3)                 return "weather-many-clouds";
        if (c === 45 || c === 48)    return "weather-fog";
        if (c >= 51 && c <= 55)      return "weather-showers-scattered" + n;
        if (c === 56 || c === 57)    return "weather-freezing-rain";
        if (c >= 61 && c <= 65)      return "weather-showers";
        if (c === 66 || c === 67)    return "weather-freezing-rain";
        if (c >= 71 && c <= 77)      return "weather-snow";
        if (c >= 80 && c <= 82)      return "weather-showers";
        if (c === 85 || c === 86)    return "weather-snow";
        if (c === 95)                return "weather-storm";
        if (c === 96 || c === 99)    return "weather-hail";
        return "weather-clear" + n;
    }

    readonly property string conditionText: {
        const c = root.code;
        if (c === 0)                 return "Despejado";
        if (c === 1)                 return "Poco nuboso";
        if (c === 2)                 return "Parcialmente nublado";
        if (c === 3)                 return "Nublado";
        if (c === 45 || c === 48)    return "Niebla";
        if (c >= 51 && c <= 57)      return "Llovizna";
        if (c >= 61 && c <= 67)      return "Lluvia";
        if (c >= 71 && c <= 77)      return "Nieve";
        if (c >= 80 && c <= 82)      return "Chubascos";
        if (c === 85 || c === 86)    return "Nevadas";
        if (c >= 95)                 return "Tormenta";
        return "";
    }

    // Refreshed every 15 minutes: the weather does not move faster than
    // that and there is no reason to hammer a free service.
    Timer {
        interval: 15 * 60 * 1000
        running: root.enabled && root.lat !== 0
        repeat: true
        triggeredOnStart: true
        onTriggered: fetch.running = true
    }

    Process {
        id: fetch
        command: ["sh", "-c",
            "curl -sf --max-time 10 'https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + root.lat + "&longitude=" + root.lon
            + "&current=temperature_2m,weather_code,is_day"
            + "&models=" + root.model
            + (root.fahrenheit ? "&temperature_unit=fahrenheit" : "")
            + "&timezone=auto'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const c = JSON.parse(text).current;
                    root.temperature = c.temperature_2m;
                    root.code = c.weather_code;
                    root.isDay = c.is_day === 1;
                    root.ready = true;
                } catch (e) {
                    // A failed request just leaves the last reading up.
                }
            }
        }
    }

    // ── Inheriting the location from the Plasma widget ─────────
    //
    // Its config keeps the place as "Candelaria, Spain, ES", which
    // Open-Meteo's geocoder resolves happily.
    Process {
        id: importer
        command: ["sh", "-c",
            "grep -m1 '^placeDisplayName=' "
            + "\"$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc\" "
            + "2>/dev/null | cut -d= -f2-"]
        stdout: StdioCollector {
            onStreamFinished: {
                // The widget stores it as "Candelaria, Spain, ES", so
                // the last piece is the country code we must honour.
                const name = text.trim();
                if (!name) return;
                const parts = name.split(",").map(x => x.trim());
                const country = (parts.length > 1
                    && parts[parts.length - 1].length === 2)
                    ? parts[parts.length - 1].toUpperCase() : "";
                root.lookup(parts[0], country);
            }
        }
    }

    function importFromPlasma() { importer.running = true; }

    // ── Geocoding ──────────────────────────────────────────────
    property var searchResults: []

    // `country` is the two-letter code to prefer when a name exists in
    // several places: there is a Candelaria in Tenerife and another in
    // the Philippines, and the search returns the Philippine one first.
    function lookup(query, country) {
        if (!query) return;
        geocode.wantCountry = country || "";
        geocode.exec(["sh", "-c",
            "curl -sf --max-time 10 'https://geocoding-api.open-meteo.com/v1/search"
            + "?name=" + encodeURIComponent(query.split(",")[0].trim())
            + "&count=10&language=es&format=json'"]);
    }

    Process {
        id: geocode
        property string wantCountry: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim()) return;
                try {
                    const results = JSON.parse(text).results || [];
                    root.searchResults = results;

                    // Only an automatic import picks on its own; a
                    // manual search waits for you to choose.
                    if (!geocode.wantCountry || !results.length) return;

                    const match = results.find(
                        r => r.country_code === geocode.wantCountry);
                    if (match) root.setPlace(match);
                    geocode.wantCountry = "";
                } catch (e) {}
            }
        }
    }

    function setPlace(result) {
        Config.data.weatherLat = result.latitude;
        Config.data.weatherLon = result.longitude;
        Config.data.weatherPlace = result.name
            + (result.admin1 ? ", " + result.admin1 : "")
            + " (" + result.country_code + ")";
        Config.save();
        root.place = Config.data.weatherPlace;
        fetch.running = true;
    }

    Component.onCompleted: {
        root.place = Config.data.weatherPlace ?? "";
        // First run: inherit whatever the Plasma weather widget has.
        if ((Config.data.weatherLat ?? 0) === 0) root.importFromPlasma();
    }
}
