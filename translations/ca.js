.pragma library

// Shima Shell interface strings.

var strings = {

    // ── Dock ──
    open: "Obre",
    newWindow: "Finestra nova",
    closeWindow: "Tanca",
    pinToDock: "Fixa al dock",
    unpinFromDock: "Treu del dock",
    applications: "Aplicacions",
    searchingWindows: "S'estan cercant finestres…",
    untitledWindow: "(sense títol)",

    // ── Launcher ──
    searchApps: "Cerca aplicacions…",
    noMatches: "Cap resultat",
    addApp: "Afegeix una aplicació…",
    searchPlace: "Cerca una localitat…",

    // ── Categories ──
    catAll: "Totes",
    catNet: "Internet",
    catMedia: "Multimèdia",
    catGames: "Jocs",
    catGfx: "Gràfics",
    catOffice: "Ofimàtica",
    catDev: "Desenvolupament",
    catSystem: "Sistema",
    catUtils: "Utilitats",
    catOther: "Altres",

    // ── Session ──
    suspend: "Suspèn",
    reboot: "Reinicia",
    shutdown: "Atura",
    lockSession: "Bloqueja la sessió",
    switchUser: "Canvia d'usuari",
    logout: "Tanca la sessió",

    // ── Island: control centre ──
    wifi: "Wi-Fi",
    bluetooth: "Bluetooth",
    output: "Sortida",
    noOutputs: "No hi ha sortides d'àudio",

    // ── Island: status ──
    cpu: "CPU",
    memory: "MEMÒRIA",
    download: "BAIXADA",
    upload: "PUJADA",
    battery: "BATERIA",

    // ── Island: media and focus ──
    nothingPlaying: "Cap reproducció",
    focus: "CONCENTRACIÓ",
    breakLabel: "DESCANS",
    longBreak: "DESCANS LLARG",
    start: "Inicia",
    pause: "Pausa",
    reset: "Reinicia",
    skip: "Salta",

    // ── Settings: sections ──
    secScreens: "PANTALLES",
    secDock: "DOCK",
    secDockApps: "APLICACIONS DEL DOCK",
    secIcons: "ICONES",
    secIsland: "ILLA",
    secFocus: "CONCENTRACIÓ",
    secWeather: "TEMPS",
    secLocation: "UBICACIÓ",
    secColour: "COLOR",
    secLanguage: "IDIOMA",

    // ── Tray ──
    showTray: "Safata del sistema",
    showTrayHint: "Les icones que publiquen les apps, com el Discord o l'Steam",
    trayCollapsible: "Safata plegable",
    trayCollapsibleHint: "S'amaga darrere una fletxa en lloc d'estar sempre visible",

    // ── Settings: entries ──
    settingsTitle: "Shima Shell",
    settingsWindowTitle: "Configuració de Shima",
    settingsSubtitle: "Els canvis s'apliquen a l'instant.",
    settingsPath: "Configuració a ",

    position: "Posició",
    bottom: "A baix",
    top: "A dalt",
    floating: "Flotant",
    floatingHint: "Separat de la vora de la pantalla",
    edgeGap: "Separació de la vora",
    autoHide: "Amaga automàticament",
    autoHideDockHint: "Apareix en acostar el punter a la vora",
    autoHideIslandHint: "Apareix en acostar el punter a la vora de dalt",
    hideDelay: "Temps abans d'amagar-se",
    opacity: "Opacitat",
    blur: "Difuminat del fons",
    blurHint: "Usa ext_background_effect del KWin",
    blurIslandHint: "Només es nota si baixes l'opacitat",
    cornerRadius: "Radi de les cantonades",

    launcherButton: "Botó d'aplicacions",
    launcherButtonHint: "Obre el menú d'inici des del dock",
    showNames: "Mostra els noms",
    showNamesHint: "El nom que apareix sobre la icona en passar-hi el ratolí",
    showRunning: "Mostra les apps obertes",
    showRunningHint: "Afegeix el que tinguis obert encara que no estigui fixat",
    inheritTaskbar: "Hereta de la barra de tasques",
    inheritTaskbarHint: "Substitueix la llista pel que tinguis fixat al Plasma",
    import: "Importa",

    shape: "Forma",
    rounded: "Arrodonida",
    circle: "Cercle",
    square: "Quadrat",
    curvature: "Curvatura",
    curvatureHint: "Només amb la forma arrodonida",
    size: "Mida",
    sizeHint: "La separació i l'espaiat es recalculen sols",
    magnify: "Amplia en passar-hi",

    showIsland: "Mostra l'illa",
    clockFormat: "Format de l'hora",
    hours24: "24 h",
    hours12: "12 h",
    collapsedWidth: "Amplada en repòs",
    expandedWidth: "Amplada desplegada",
    collapsedHeight: "Alçada en repòs",
    detached: "Separada de la vora",
    detachedHint: "Deixa un espai a dalt en lloc de néixer de la vora",
    topGap: "Espai superior",
    islandTint: "To de l'illa",

    duration: "Durada",
    durationHint: "Quant dura una sessió de concentració",
    chainBreak: "Encadena el descans",
    chainBreakHint: "En acabar, engega el descans tot sol",
    breakSetting: "Descans",
    longBreakSetting: "Descans llarg",
    roundsBeforeLong: "Rondes fins al llarg",
    notifyOnEnd: "Avisa en acabar",
    notifyOnEndHint: "Una notificació del sistema en acabar cada fase",
    silenceWhile: "Silencia mentre dura",
    silenceWhileHint: "Inhibeix els avisos sense tocar el No molestis",

    showWeather: "Mostra el temps",
    showWeatherHint: "Al costat de l'hora, a l'illa en repòs",
    whatShows: "Què es veu",
    both: "Tots dos",
    iconOnly: "Icona",
    degreesOnly: "Graus",
    source: "Font",
    autoSource: "Auto",
    sourceHint: "El Met Office és el que usa el widget del KDE",
    units: "Unitats",
    inheritPlasma: "Hereta del Plasma",
    inheritPlasmaHint: "Només si tens el widget del temps del KDE",
    pickPlace: "Tria una localitat per veure el temps.",

    accent: "Accent",
    accentHint: "Punt d'aplicació activa i controls",
    dockTint: "To del dock",
    automatic: "Automàtic",
    language: "Idioma",
    languageHint: "Automàtic segueix l'idioma del sistema",

    island: "Illa",
    dock: "Dock",

    // Monday first, as the week runs here.
    weekdays: ["Dl", "Dt", "Dc", "Dj", "Dv", "Ds", "Dg"]
};
