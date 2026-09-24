import QtQuick
import Quickshell
import "../services"

// Settings: the weather, and the place it is read for.
Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 2

    // The values, which write themselves when touched.
    readonly property var c: Config.data

    Controls.Section_ { text: I18n.t.secWeather }

    Controls.Row_ {
        label: I18n.t.showWeather
        hint: I18n.t.showWeatherHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.weatherEnabled ?? true
            onToggled: (v) => { root.c.weatherEnabled = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.whatShows
        visible: root.c.weatherEnabled ?? true
        Controls.Choice_ {
            options: [{value: "both", label: I18n.t.both},
                      {value: "icon", label: I18n.t.iconOnly},
                      {value: "temp", label: I18n.t.degreesOnly}]
            value: {
                const i = root.c.weatherShowIcon ?? true;
                const t = root.c.weatherShowTemp ?? true;
                return (i && t) ? "both" : (i ? "icon" : "temp");
            }
            onPicked: (v) => {
                root.c.weatherShowIcon = (v !== "temp");
                root.c.weatherShowTemp = (v !== "icon");
                Config.save();
            }
        }
    }

    Controls.Row_ {
        label: I18n.t.provider
        hint: I18n.t.providerHint
        visible: root.c.weatherEnabled ?? true
        Controls.Choice_ {
            options: [{value: "bbc", label: "BBC"},
                      {value: "openmeteo", label: "Open-Meteo"}]
            value: root.c.weatherProvider ?? "bbc"
            onPicked: (v) => { root.c.weatherProvider = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.source
        hint: I18n.t.sourceHint
        visible: root.c.weatherEnabled ?? true
        Controls.Choice_ {
            options: [{value: "best_match",    label: I18n.t.autoSource},
                      {value: "ukmo_seamless", label: "Met Office"},
                      {value: "ecmwf_ifs025",  label: "ECMWF"}]
            value: root.c.weatherModel ?? "best_match"
            onPicked: (v) => { root.c.weatherModel = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.units
        visible: root.c.weatherEnabled ?? true
        Controls.Choice_ {
            options: [{value: "c", label: "°C"}, {value: "f", label: "°F"}]
            value: (root.c.weatherFahrenheit ?? false) ? "f" : "c"
            onPicked: (v) => { root.c.weatherFahrenheit = (v === "f"); Config.save(); }
        }
    }

    Controls.Section_ {
        text: I18n.t.secLocation
        visible: root.c.weatherEnabled ?? true
    }

    PlacePicker {
        width: parent.width
        visible: root.c.weatherEnabled ?? true
        topPadding: 4
    }

    Controls.Row_ {
        label: I18n.t.inheritPlasma
        hint: I18n.t.inheritPlasmaHint
        visible: root.c.weatherEnabled ?? true
        Controls.Button_ {
            anchors.right: parent.right
            label: I18n.t.import
            onTriggered: { root.c.weatherLat = 0; Weather.importFromPlasma(); }
        }
    }
}
