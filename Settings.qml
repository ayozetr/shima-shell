import QtQuick
import Quickshell
import "services"
import "components"

FloatingWindow {
    id: win

    visible: SettingsWindow.open
    implicitWidth: 520
    implicitHeight: 640
    title: "Ajustes de Shima"
    color: "#0e0e0e"

    // Shortcut to the values, which write themselves when touched.
    readonly property var c: Config.data

    Flickable {
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 2

            Text {
                text: "Shima Shell"
                color: Theme.textPrimary
                font.pixelSize: 22
                font.weight: Font.DemiBold
                bottomPadding: 2
            }
            Text {
                text: "Los cambios se aplican al momento."
                color: Theme.textTertiary
                font.pixelSize: 11
                bottomPadding: 6
            }

            // ── SCREENS ─────────────────────────────────────────
            Controls.Section_ {
                text: "PANTALLAS"
                visible: Quickshell.screens.length > 1
            }

            ScreenPicker {
                width: parent.width
                visible: Quickshell.screens.length > 1
                topPadding: 6
            }

            Item {
                width: 1; height: 8
                visible: Quickshell.screens.length > 1
            }

            // ── DOCK ────────────────────────────────────────────
            Controls.Section_ { text: "DOCK" }

            Controls.Row_ {
                label: "Posición"
                Controls.Choice_ {
                    options: [{value: "bottom", label: "Abajo"}, {value: "top", label: "Arriba"}]
                    value: win.c.dockPosition ?? "bottom"
                    onPicked: (v) => { win.c.dockPosition = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Flotante"
                hint: "Despegado del borde de la pantalla"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.dockFloating ?? false
                    onToggled: (v) => { win.c.dockFloating = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Separación del borde"
                visible: win.c.dockFloating ?? false
                Controls.Slider_ {
                    from: 0; to: 40; step: 1; suffix: " px"
                    value: win.c.dockMargin ?? 10
                    onMoved: (v) => { win.c.dockMargin = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Ocultar automáticamente"
                hint: "Se asoma al acercar el ratón al borde"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.dockAutoHide ?? false
                    onToggled: (v) => { win.c.dockAutoHide = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Tarda en esconderse"
                visible: win.c.dockAutoHide ?? false
                Controls.Slider_ {
                    from: 200; to: 2000; step: 50; suffix: " ms"
                    value: win.c.dockHideDelay ?? 700
                    onMoved: (v) => { win.c.dockHideDelay = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Transparencia"
                Controls.Slider_ {
                    from: 0.2; to: 1; step: 0.01
                    value: win.c.dockOpacity ?? 0.8
                    onMoved: (v) => { win.c.dockOpacity = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Desenfoque de fondo"
                hint: "Usa ext_background_effect de KWin"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.dockBlur ?? true
                    onToggled: (v) => { win.c.dockBlur = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Radio de las esquinas"
                Controls.Slider_ {
                    from: 0; to: 40; step: 1; suffix: " px"
                    value: win.c.dockCornerRadius ?? 28
                    onMoved: (v) => { win.c.dockCornerRadius = v; Config.save(); }
                }
            }

            // ── APPLICATIONS ────────────────────────────────────
            Controls.Section_ { text: "APLICACIONES DEL DOCK" }

            PinnedEditor {
                width: parent.width
                topPadding: 6
            }

            Item { width: 1; height: 8 }

            Controls.Row_ {
                label: "Botón de aplicaciones"
                hint: "Abre el menú de inicio desde el dock"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.showLauncher ?? true
                    onToggled: (v) => { win.c.showLauncher = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Mostrar apps abiertas"
                hint: "Añade al dock lo que tengas abierto aunque no esté anclado"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.showRunning ?? true
                    onToggled: (v) => { win.c.showRunning = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Heredar de la barra de tareas"
                hint: "Sustituye la lista por lo que tengas anclado en Plasma"
                Controls.Button_ {
                    anchors.right: parent.right
                    label: "Importar"
                    onTriggered: Apps.importFromPlasma()
                }
            }

            Item { width: 1; height: 6 }

            // ── ICONS ───────────────────────────────────────────
            Controls.Section_ { text: "ICONOS" }

            Controls.Row_ {
                label: "Forma"
                Controls.Choice_ {
                    options: [{value: "squircle", label: "Redondeado"},
                              {value: "circle",   label: "Círculo"},
                              {value: "square",   label: "Cuadrado"}]
                    value: win.c.iconShape ?? "squircle"
                    onPicked: (v) => { win.c.iconShape = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Curvatura"
                hint: "Sólo con la forma redondeada"
                visible: (win.c.iconShape ?? "squircle") === "squircle"
                Controls.Slider_ {
                    from: 5; to: 50; step: 1; suffix: " %"
                    value: win.c.iconRadiusPct ?? 33
                    onMoved: (v) => { win.c.iconRadiusPct = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Tamaño"
                hint: "El hueco y el relleno se recalculan solos"
                Controls.Slider_ {
                    from: 32; to: 88; step: 2; suffix: " px"
                    value: win.c.dockIconSize ?? 56
                    onMoved: (v) => { win.c.dockIconSize = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Ampliar al pasar"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.dockMagnify ?? true
                    onToggled: (v) => { win.c.dockMagnify = v; Config.save(); }
                }
            }

            // ── ISLAND ──────────────────────────────────────────
            Controls.Section_ { text: "ISLA" }

            Controls.Row_ {
                label: "Mostrar la isla"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.islandEnabled ?? true
                    onToggled: (v) => { win.c.islandEnabled = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Formato de hora"
                Controls.Choice_ {
                    options: [{value: "24", label: "24 h"}, {value: "12", label: "12 h"}]
                    value: (win.c.clock24 ?? true) ? "24" : "12"
                    onPicked: (v) => { win.c.clock24 = (v === "24"); Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Radio de las esquinas"
                Controls.Slider_ {
                    from: 0; to: 34; step: 1; suffix: " px"
                    value: win.c.islandRadius ?? 22
                    onMoved: (v) => { win.c.islandRadius = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Ancho en reposo"
                Controls.Slider_ {
                    from: 220; to: 620; step: 5; suffix: " px"
                    value: win.c.islandCollapsedWidth ?? 410
                    onMoved: (v) => { win.c.islandCollapsedWidth = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Ancho desplegada"
                Controls.Slider_ {
                    from: 320; to: 720; step: 5; suffix: " px"
                    value: win.c.islandExpandedWidth ?? 425
                    onMoved: (v) => { win.c.islandExpandedWidth = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Alto en reposo"
                Controls.Slider_ {
                    from: 26; to: 60; step: 1; suffix: " px"
                    value: win.c.islandCollapsedHeight ?? 38
                    onMoved: (v) => { win.c.islandCollapsedHeight = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Separada del borde"
                hint: "Deja un hueco arriba en vez de nacer del borde"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.islandFloating ?? false
                    onToggled: (v) => { win.c.islandFloating = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Hueco superior"
                visible: win.c.islandFloating ?? false
                Controls.Slider_ {
                    from: 0; to: 40; step: 1; suffix: " px"
                    value: win.c.islandMargin ?? 8
                    onMoved: (v) => { win.c.islandMargin = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Ocultar automáticamente"
                hint: "Se asoma al acercar el ratón al borde de arriba"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.islandAutoHide ?? false
                    onToggled: (v) => { win.c.islandAutoHide = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Tarda en esconderse"
                visible: win.c.islandAutoHide ?? false
                Controls.Slider_ {
                    from: 200; to: 2000; step: 50; suffix: " ms"
                    value: win.c.islandHideDelay ?? 700
                    onMoved: (v) => { win.c.islandHideDelay = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Transparencia"
                Controls.Slider_ {
                    from: 0.2; to: 1; step: 0.01
                    value: win.c.islandOpacity ?? 1.0
                    onMoved: (v) => { win.c.islandOpacity = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Desenfoque de fondo"
                hint: "Sólo se nota si bajas la transparencia"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.islandBlur ?? false
                    onToggled: (v) => { win.c.islandBlur = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Tono de la isla"
                Controls.Swatches_ {
                    anchors.right: parent.right
                    colors: ["#000000", "#12121a", "#1a1410", "#101a14", "#181818"]
                    value: win.c.islandTint ?? "#000000"
                    onPicked: (v) => { win.c.islandTint = v; Config.save(); }
                }
            }

            // ── FOCUS ───────────────────────────────────────────
            Controls.Section_ { text: "ENFOQUE" }

            Controls.Row_ {
                label: "Duración"
                hint: "Cuánto dura una sesión de enfoque"
                Controls.Slider_ {
                    from: 1; to: 120; step: 1; suffix: " min"
                    value: win.c.focusMinutes ?? 25
                    onMoved: (v) => { win.c.focusMinutes = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Encadenar descanso"
                hint: "Al acabar arranca el descanso por su cuenta"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.focusChain ?? true
                    onToggled: (v) => { win.c.focusChain = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Descanso"
                visible: win.c.focusChain ?? true
                Controls.Slider_ {
                    from: 1; to: 30; step: 1; suffix: " min"
                    value: win.c.breakMinutes ?? 5
                    onMoved: (v) => { win.c.breakMinutes = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Descanso largo"
                visible: win.c.focusChain ?? true
                Controls.Slider_ {
                    from: 5; to: 60; step: 5; suffix: " min"
                    value: win.c.longBreakMinutes ?? 15
                    onMoved: (v) => { win.c.longBreakMinutes = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Rondas hasta el largo"
                visible: win.c.focusChain ?? true
                Controls.Slider_ {
                    from: 2; to: 8; step: 1
                    value: win.c.focusRounds ?? 4
                    onMoved: (v) => { win.c.focusRounds = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Avisar al terminar"
                hint: "Notificación del sistema al acabar cada fase"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.focusNotify ?? true
                    onToggled: (v) => { win.c.focusNotify = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Silenciar mientras dura"
                hint: "Inhibe los avisos sin tocar tu No molestar"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.focusInhibit ?? true
                    onToggled: (v) => { win.c.focusInhibit = v; Config.save(); }
                }
            }

            // ── WEATHER ─────────────────────────────────────────
            Controls.Section_ { text: "CLIMA" }

            Controls.Row_ {
                label: "Mostrar el clima"
                hint: "Junto a la hora, en la isla en reposo"
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.weatherEnabled ?? true
                    onToggled: (v) => { win.c.weatherEnabled = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Qué se ve"
                visible: win.c.weatherEnabled ?? true
                Controls.Choice_ {
                    options: [{value: "both", label: "Ambos"},
                              {value: "icon", label: "Icono"},
                              {value: "temp", label: "Grados"}]
                    value: {
                        const i = win.c.weatherShowIcon ?? true;
                        const t = win.c.weatherShowTemp ?? true;
                        return (i && t) ? "both" : (i ? "icon" : "temp");
                    }
                    onPicked: (v) => {
                        win.c.weatherShowIcon = (v !== "temp");
                        win.c.weatherShowTemp = (v !== "icon");
                        Config.save();
                    }
                }
            }

            Controls.Row_ {
                label: "Fuente"
                hint: "El Met Office es lo que usa el widget de KDE"
                visible: win.c.weatherEnabled ?? true
                Controls.Choice_ {
                    options: [{value: "ukmo_seamless", label: "Met Office"},
                              {value: "ecmwf_ifs025",  label: "ECMWF"},
                              {value: "best_match",    label: "Auto"}]
                    value: win.c.weatherModel ?? "ukmo_seamless"
                    onPicked: (v) => { win.c.weatherModel = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Unidades"
                visible: win.c.weatherEnabled ?? true
                Controls.Choice_ {
                    options: [{value: "c", label: "°C"}, {value: "f", label: "°F"}]
                    value: (win.c.weatherFahrenheit ?? false) ? "f" : "c"
                    onPicked: (v) => { win.c.weatherFahrenheit = (v === "f"); Config.save(); }
                }
            }

            Controls.Section_ {
                text: "UBICACIÓN"
                visible: win.c.weatherEnabled ?? true
            }

            PlacePicker {
                width: parent.width
                visible: win.c.weatherEnabled ?? true
                topPadding: 4
            }

            Controls.Row_ {
                label: "Heredar de Plasma"
                hint: "Sólo si tienes el widget meteorológico de KDE"
                visible: win.c.weatherEnabled ?? true
                Controls.Button_ {
                    anchors.right: parent.right
                    label: "Importar"
                    onTriggered: { win.c.weatherLat = 0; Weather.importFromPlasma(); }
                }
            }

            Item { width: 1; height: 6 }

            // ── COLOUR ──────────────────────────────────────────
            Controls.Section_ { text: "COLOR" }

            Controls.Row_ {
                label: "Acento"
                hint: "Punto de app activa y controles"
                Controls.Swatches_ {
                    anchors.right: parent.right
                    colors: ["#a78bfa", "#60a5fa", "#34d399", "#fbbf24", "#f87171", "#ffffff"]
                    value: win.c.accent ?? "#a78bfa"
                    onPicked: (v) => { win.c.accent = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: "Tono del dock"
                Controls.Swatches_ {
                    anchors.right: parent.right
                    colors: ["#000000", "#12121a", "#1a1410", "#101a14", "#181818"]
                    value: win.c.dockTint ?? "#000000"
                    onPicked: (v) => { win.c.dockTint = v; Config.save(); }
                }
            }

            Item { width: 1; height: 18 }

            Text {
                text: "Ajustes en " + Config.path
                color: Theme.textTertiary
                font.pixelSize: 10
            }
        }
    }
}
