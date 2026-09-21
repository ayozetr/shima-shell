.pragma library

// Shima Shell interface strings.

var strings = {

    // ── Dock ──
    open: "Öffnen",
    newWindow: "Neues Fenster",
    closeWindow: "Schließen",
    pinToDock: "Ans Dock anheften",
    unpinFromDock: "Vom Dock entfernen",
    applications: "Anwendungen",
    searchingWindows: "Fenster werden gesucht…",
    untitledWindow: "(ohne Titel)",

    // ── Launcher ──
    searchApps: "Anwendungen suchen…",
    noMatches: "Keine Treffer",
    addApp: "Anwendung hinzufügen…",
    searchPlace: "Ort suchen…",

    // ── Categories ──
    catAll: "Alle",
    catNet: "Internet",
    catMedia: "Multimedia",
    catGames: "Spiele",
    catGfx: "Grafik",
    catOffice: "Büro",
    catDev: "Entwicklung",
    catSystem: "System",
    catUtils: "Dienstprogramme",
    catOther: "Sonstige",

    // ── Session ──
    suspend: "Standby",
    reboot: "Neu starten",
    shutdown: "Herunterfahren",
    lockSession: "Sitzung sperren",
    switchUser: "Benutzer wechseln",
    logout: "Abmelden",

    // ── Island: control centre ──
    wifi: "WLAN",
    bluetooth: "Bluetooth",
    output: "Ausgabe",
    noOutputs: "Keine Audioausgänge",
    nightLight: "Nachtlicht",
    screens: "Bildschirme",


    // ── Island: status ──
    cpu: "CPU",
    memory: "SPEICHER",
    download: "EMPFANG",
    upload: "SENDEN",
    battery: "AKKU",

    // ── Island: media and focus ──
    nothingPlaying: "Keine Wiedergabe",
    focus: "FOKUS",
    breakLabel: "PAUSE",
    longBreak: "LANGE PAUSE",
    start: "Starten",
    pause: "Anhalten",
    reset: "Zurücksetzen",
    skip: "Überspringen",

    // ── Settings: sections ──
    secScreens: "BILDSCHIRME",
    secDock: "DOCK",
    secDockApps: "ANWENDUNGEN IM DOCK",
    secIcons: "SYMBOLE",
    secIsland: "INSEL",
    secFocus: "FOKUS",
    secWeather: "WETTER",
    secLocation: "ORT",
    secColour: "FARBE",
    secLanguage: "SPRACHE",

    // ── Tray ──
    showTray: "Systemabschnitt",
    showTrayHint: "Die Symbole, die Anwendungen bereitstellen, etwa Discord oder Steam",
    trayCollapsible: "Einklappbar",
    trayCollapsibleHint: "Klappt hinter einen Pfeil, statt immer sichtbar zu sein",

    // ── Settings: entries ──
    settingsTitle: "Shima Shell",
    settingsWindowTitle: "Shima-Einstellungen",
    settingsSubtitle: "Änderungen wirken sofort.",
    settingsPath: "Einstellungen in ",

    position: "Position",
    bottom: "Unten",
    top: "Oben",
    floating: "Schwebend",
    floatingHint: "Vom Bildschirmrand gelöst",
    edgeGap: "Abstand zum Rand",
    autoHide: "Automatisch ausblenden",
    autoHideDockHint: "Erscheint, wenn der Zeiger dem Rand nahe kommt",
    autoHideIslandHint: "Erscheint, wenn der Zeiger dem oberen Rand nahe kommt",
    hideDelay: "Verzögerung vor dem Ausblenden",
    opacity: "Deckkraft",
    blur: "Hintergrundunschärfe",
    blurHint: "Nutzt ext_background_effect von KWin",
    blurIslandHint: "Nur sichtbar, wenn die Deckkraft sinkt",
    cornerRadius: "Eckenradius",

    launcherButton: "Anwendungsschaltfläche",
    launcherButtonHint: "Öffnet das Startmenü vom Dock aus",
    showNames: "Namen anzeigen",
    showNamesHint: "Der Name, der beim Überfahren über dem Symbol schwebt",
    showRunning: "Offene Anwendungen anzeigen",
    showRunningHint: "Zeigt Geöffnetes auch ohne Anheftung",
    inheritTaskbar: "Von der Fensterleiste übernehmen",
    inheritTaskbarHint: "Ersetzt die Liste durch das in Plasma Angeheftete",
    import: "Importieren",

    shape: "Form",
    rounded: "Abgerundet",
    circle: "Kreis",
    square: "Quadrat",
    curvature: "Rundung",
    curvatureHint: "Nur bei der abgerundeten Form",
    size: "Größe",
    sizeHint: "Abstand und Polsterung passen sich selbst an",
    magnify: "Beim Überfahren vergrößern",

    showIsland: "Insel anzeigen",
    clockFormat: "Zeitformat",
    hours24: "24 h",
    hours12: "12 h",
    collapsedWidth: "Breite in Ruhe",
    expandedWidth: "Breite ausgeklappt",
    collapsedHeight: "Höhe in Ruhe",
    detached: "Vom Rand gelöst",
    detachedHint: "Lässt oben Platz, statt aus dem Rand zu wachsen",
    topGap: "Abstand nach oben",
    islandTint: "Farbton der Insel",

    duration: "Dauer",
    durationHint: "Wie lange eine Fokussitzung dauert",
    chainBreak: "Pause anschließen",
    chainBreakHint: "Startet die Pause am Ende von selbst",
    breakSetting: "Pause",
    longBreakSetting: "Lange Pause",
    roundsBeforeLong: "Runden bis zur langen",
    notifyOnEnd: "Am Ende benachrichtigen",
    notifyOnEndHint: "Eine Systemmeldung am Ende jeder Phase",
    silenceWhile: "Währenddessen stummschalten",
    silenceWhileHint: "Unterdrückt Meldungen, ohne „Nicht stören“ zu ändern",

    showWeather: "Wetter anzeigen",
    showWeatherHint: "Neben der Uhr, auf der Insel in Ruhe",
    whatShows: "Was gezeigt wird",
    both: "Beides",
    iconOnly: "Symbol",
    degreesOnly: "Grad",
    source: "Quelle",
    autoSource: "Auto",
    sourceHint: "Das KDE-Miniprogramm nutzt ebenfalls das Met Office",
    units: "Einheiten",
    inheritPlasma: "Von Plasma übernehmen",
    inheritPlasmaHint: "Nur mit dem Wetter-Miniprogramm von KDE",
    pickPlace: "Wähle einen Ort, um das Wetter zu sehen.",

    accent: "Akzent",
    accentHint: "Punkt aktiver Anwendungen und Bedienelemente",
    dockTint: "Farbton des Docks",
    automatic: "Automatisch",
    language: "Sprache",
    languageHint: "Automatisch folgt der Systemsprache",

    island: "Insel",
    dock: "Dock",

    // Monday first, as the week runs here.
    weekdays: ["M", "D", "M", "D", "F", "S", "S"]
};
