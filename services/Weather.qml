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
    readonly property string bbcId: Config.data.weatherBbcId ?? ""
    readonly property bool useBbc: (Config.data.weatherProvider ?? "bbc") === "bbc"
                                   && root.bbcId !== ""

    // Only the temperature comes from BBC: its observation feed reports
    // the current conditions as "Not available" often enough that the
    // icon would keep vanishing. Open-Meteo's code also tells day from
    // night, which is what picks the sun or the moon.
    property real bbcTemperature: 0
    property bool bbcReady: false

    // Rounds half down: at exactly 24.5, JavaScript's Math.round gives
    // 25 while BBC (and therefore Plasma's widget) shows 24. Only the
    // exact half changes; everything else rounds as usual.
    readonly property real shownTemperature:
        (root.useBbc && root.bbcReady) ? root.bbcTemperature : root.temperature

    readonly property string temperatureText:
        root.ready ? Math.ceil(root.shownTemperature - 0.5) + "°" : ""

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
        if (c === 0)                 return I18n.t.wxClear;
        if (c === 1)                 return I18n.t.wxMostlyClear;
        if (c === 2)                 return I18n.t.wxPartlyCloudy;
        if (c === 3)                 return I18n.t.wxCloudy;
        if (c === 45 || c === 48)    return I18n.t.wxFog;
        if (c >= 51 && c <= 57)      return I18n.t.wxDrizzle;
        if (c >= 61 && c <= 67)      return I18n.t.wxRain;
        if (c >= 71 && c <= 77)      return I18n.t.wxSnow;
        if (c >= 80 && c <= 82)      return I18n.t.wxShowers;
        if (c === 85 || c === 86)    return I18n.t.wxSnowShowers;
        if (c >= 95)                 return I18n.t.wxThunderstorm;
        return "";
    }

    // Refreshed every 15 minutes: the weather does not move faster than
    // that and there is no reason to hammer a free service.
    Timer {
        interval: 15 * 60 * 1000
        running: root.enabled && root.lat !== 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fetch.running = true;
            if (root.useBbc) bbcFetch.running = true;
        }
    }

    // The feed is RSS, so the reading is pulled out with a regular
    // expression rather than parsed: one number from one line.
    Process {
        id: bbcFetch
        command: ["sh", "-c",
            "curl -sf --max-time 10 "
            + "'https://weather-broker-cdn.api.bbci.co.uk/en/observation/rss/"
            + root.bbcId + "' "
            + "| grep -oE 'Temperature: -?[0-9]+' | head -1 "
            + "| grep -oE '\\-?[0-9]+'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim(), 10);
                if (!isNaN(v)) {
                    root.bbcTemperature = v;
                    root.bbcReady = true;
                }
            }
        }
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
            "grep -m1 '^placeInfo=' "
            + "\"$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc\" "
            + "2>/dev/null | cut -d= -f2-"]
        stdout: StdioCollector {
            onStreamFinished: {
                // The widget stores it as
                // "Candelaria, Spain, ES|2520283": a name whose last
                // piece is the country code, and BBC's own id.
                const raw = text.trim();
                if (!raw) return;
                const bar = raw.indexOf("|");
                if (bar > 0) {
                    Config.data.weatherBbcId = raw.slice(bar + 1).trim();
                    Config.save();
                }
                const name = bar > 0 ? raw.slice(0, bar) : raw;
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
