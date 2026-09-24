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
    // Zero means "no town chosen yet", which is why it is also the
    // default; anything outside the globe is somebody's typo.
    readonly property real lat: Config.number(Config.data.weatherLat, 0, -90, 90)
    readonly property real lon: Config.number(Config.data.weatherLon, 0, -180, 180)
    readonly property bool fahrenheit: Config.data.weatherFahrenheit ?? false
    // These two end up in a command line, and the configuration file
    // is not ours alone: the importer below copies them out of Plasma's
    // applet settings, which anything that touches an applet can write
    // — a global theme downloaded from store.kde.org included. So each
    // is checked against what it is allowed to be, and a value that
    // fails is not used at all rather than passed along.
    readonly property var models: ["ukmo_seamless", "ecmwf_ifs025", "best_match"]
    readonly property string model: {
        const m = Config.data.weatherModel ?? "ukmo_seamless";
        return root.models.indexOf(m) !== -1 ? m : "ukmo_seamless";
    }
    // A BBC location id is a plain number and nothing else.
    readonly property string bbcId: {
        const id = String(Config.data.weatherBbcId ?? "");
        return /^[0-9]+$/.test(id) ? id : "";
    }
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
        // The pipeline needs a shell, so the address is handed over as
        // a positional argument instead of being pasted into the
        // command text. The shell then never reads it as syntax, no
        // matter what it contains.
        command: ["sh", "-c",
            "curl -sf --max-time 10 \"$1\" "
            + "| grep -oE 'Temperature: -?[0-9]+' | head -1 "
            + "| grep -oE '\\-?[0-9]+'",
            "shima",
            "https://weather-broker-cdn.api.bbci.co.uk/en/observation/rss/"
            + root.bbcId]
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
        // Run without a shell: there is nothing to pipe here, and with
        // no shell in the way there is no quoting to get wrong.
        command: ["curl", "-sf", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + root.lat + "&longitude=" + root.lon
            + "&current=temperature_2m,weather_code,is_day"
            + "&models=" + root.model
            + (root.fahrenheit ? "&temperature_unit=fahrenheit" : "")
            + "&timezone=auto"]
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
                    // Checked before it is stored, not only before it
                    // is used: this is the one place a value from
                    // outside gets into our own configuration file.
                    const id = raw.slice(bar + 1).trim();
                    if (/^[0-9]+$/.test(id)) {
                        Config.data.weatherBbcId = id;
                        Config.save();
                    }
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
    // What was last asked for. Type "Santa Cruz", keep going to
    // "Santander", and the slow first answer used to land on top of
    // the second — and here that is not a list going stale, it is the
    // wrong town written into the configuration on the next click.
    property string searchQuery: ""

    function lookup(query, country) {
        if (!query) return;
        root.searchQuery = query;
        geocode.wantCountry = country || "";
        // Nothing is interpolated into the script — the place name and
        // the address go in as arguments. That mattered once: the URL
        // used to be wrapped in single quotes, which a place name
        // closes all by itself, and encodeURIComponent leaves the
        // apostrophe alone, so L'Hospitalet broke the search with no
        // message.
        //
        // The first line printed is the question, so the answer says
        // what it answers. Holding the query here instead does not
        // survive the moment: starting a search stops the one running,
        // and whatever it had already collected comes back afterwards,
        // by which time anything written down here has moved on.
        geocode.exec(["sh", "-c",
            'printf "%s\\n" "$1"; exec curl -sf --max-time 10 "$2"',
            "shima", query,
            "https://geocoding-api.open-meteo.com/v1/search"
            + "?name=" + encodeURIComponent(query.split(",")[0].trim())
            + "&count=10&language=es&format=json"]);
    }

    Process {
        id: geocode
        property string wantCountry: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const end = text.indexOf("\n");
                if (end < 0) return;
                if (text.slice(0, end) !== root.searchQuery) return;
                const body = text.slice(end + 1);

                // Cleared here rather than after a match: a name with
                // no results at all left it set, and the next search —
                // a manual one, with nothing asking to be picked —
                // chose a town by itself.
                const wanted = geocode.wantCountry;
                geocode.wantCountry = "";

                if (!body.trim()) return;
                try {
                    const results = JSON.parse(body).results || [];
                    root.searchResults = results;

                    // Only an automatic import picks on its own; a
                    // manual search waits for you to choose.
                    if (!wanted || !results.length) return;

                    const match = results.find(
                        r => r.country_code === wanted);
                    if (match) root.setPlace(match);
                } catch (e) {}
            }
        }
    }

    // Backing out of the search: stop showing what was found for text
    // that is no longer there.
    function clearSearch() {
        root.searchQuery = "";
        root.searchResults = [];
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

    // Read when the settings arrive, not when this is built. A
    // singleton is born before its file has been read, so asking at
    // construction gets the defaults — and the default latitude is
    // zero, which is exactly the "nothing chosen yet" the line below
    // is looking for. So the import from Plasma's widget ran at every
    // single start and wrote its location over the one you picked. On
    // a machine where both point at the same town it is invisible;
    // anywhere else your choice came back changed after every login.
    Connections {
        target: Config
        function onReady() {
            root.place = Config.data.weatherPlace ?? "";
            // First run: inherit whatever the Plasma weather widget has.
            if ((Config.data.weatherLat ?? 0) === 0) root.importFromPlasma();
        }
    }
}
