.pragma library

// Shima Shell interface strings.

var strings = {

    // ── Dock ──
    open: "Abrir",
    newWindow: "Nueva ventana",
    closeWindow: "Cerrar",
    pinToDock: "Anclar al dock",
    unpinFromDock: "Quitar del dock",
    applications: "Aplicaciones",
    searchingWindows: "Buscando ventanas…",
    untitledWindow: "(sin título)",

    // ── Launcher ──
    searchApps: "Buscar aplicaciones…",
    noMatches: "Nada que se parezca a eso",
    addApp: "Añadir una aplicación…",
    searchPlace: "Buscar una localidad…",

    // ── Categories ──
    catAll: "Todas",
    catNet: "Internet",
    catMedia: "Multimedia",
    catGames: "Juegos",
    catGfx: "Gráficos",
    catOffice: "Oficina",
    catDev: "Desarrollo",
    catSystem: "Sistema",
    catUtils: "Utilidades",
    catOther: "Otras",

    // ── Session ──
    suspend: "Suspender",
    reboot: "Reiniciar",
    shutdown: "Apagar",
    lockSession: "Bloquear la sesión",
    switchUser: "Cambiar de usuario",
    logout: "Cerrar la sesión",

    // ── Island: control centre ──
    wifi: "Wi-Fi",
    bluetooth: "Bluetooth",
    output: "Salida",
    noOutputs: "No hay salidas de audio",

    // ── Island: status ──
    cpu: "CPU",
    memory: "MEMORIA",
    download: "BAJADA",
    upload: "SUBIDA",
    battery: "BATERÍA",

    // ── Island: media and focus ──
    nothingPlaying: "Sin reproducción",
    focus: "ENFOQUE",
    breakLabel: "DESCANSO",
    longBreak: "DESCANSO LARGO",
    start: "Iniciar",
    pause: "Pausar",
    reset: "Reiniciar",
    skip: "Saltar",

    // ── Settings: sections ──
    secScreens: "PANTALLAS",
    secDock: "DOCK",
    secDockApps: "APLICACIONES DEL DOCK",
    secIcons: "ICONOS",
    secIsland: "ISLA",
    secFocus: "ENFOQUE",
    secWeather: "CLIMA",
    secLocation: "UBICACIÓN",
    secColour: "COLOR",
    secLanguage: "IDIOMA",

    // ── Settings: entries ──
    settingsTitle: "Shima Shell",
    settingsWindowTitle: "Ajustes de Shima",
    settingsSubtitle: "Los cambios se aplican al momento.",
    settingsPath: "Ajustes en ",

    position: "Posición",
    bottom: "Abajo",
    top: "Arriba",
    floating: "Flotante",
    floatingHint: "Despegado del borde de la pantalla",
    edgeGap: "Separación del borde",
    autoHide: "Ocultar automáticamente",
    autoHideDockHint: "Se asoma al acercar el ratón al borde",
    autoHideIslandHint: "Se asoma al acercar el ratón al borde de arriba",
    hideDelay: "Tarda en esconderse",
    opacity: "Opacidad",
    blur: "Desenfoque de fondo",
    blurHint: "Usa ext_background_effect de KWin",
    blurIslandHint: "Sólo se nota si bajas la opacidad",
    cornerRadius: "Radio de las esquinas",

    launcherButton: "Botón de aplicaciones",
    launcherButtonHint: "Abre el menú de inicio desde el dock",
    showNames: "Mostrar nombres",
    showNamesHint: "El nombre que flota sobre el icono al pasar el ratón",
    showRunning: "Mostrar apps abiertas",
    showRunningHint: "Añade al dock lo que tengas abierto aunque no esté anclado",
    inheritTaskbar: "Heredar de la barra de tareas",
    inheritTaskbarHint: "Sustituye la lista por lo que tengas anclado en Plasma",
    import: "Importar",

    shape: "Forma",
    rounded: "Redondeado",
    circle: "Círculo",
    square: "Cuadrado",
    curvature: "Curvatura",
    curvatureHint: "Sólo con la forma redondeada",
    size: "Tamaño",
    sizeHint: "El hueco y el relleno se recalculan solos",
    magnify: "Ampliar al pasar",

    showIsland: "Mostrar la isla",
    clockFormat: "Formato de hora",
    hours24: "24 h",
    hours12: "12 h",
    collapsedWidth: "Ancho en reposo",
    expandedWidth: "Ancho desplegada",
    collapsedHeight: "Alto en reposo",
    detached: "Separada del borde",
    detachedHint: "Deja un hueco arriba en vez de nacer del borde",
    topGap: "Hueco superior",
    islandTint: "Tono de la isla",

    duration: "Duración",
    durationHint: "Cuánto dura una sesión de enfoque",
    chainBreak: "Encadenar descanso",
    chainBreakHint: "Al acabar arranca el descanso por su cuenta",
    breakSetting: "Descanso",
    longBreakSetting: "Descanso largo",
    roundsBeforeLong: "Rondas hasta el largo",
    notifyOnEnd: "Avisar al terminar",
    notifyOnEndHint: "Notificación del sistema al acabar cada fase",
    silenceWhile: "Silenciar mientras dura",
    silenceWhileHint: "Inhibe los avisos sin tocar tu No molestar",

    showWeather: "Mostrar el clima",
    showWeatherHint: "Junto a la hora, en la isla en reposo",
    whatShows: "Qué se ve",
    both: "Ambos",
    iconOnly: "Icono",
    degreesOnly: "Grados",
    source: "Fuente",
    autoSource: "Auto",
    sourceHint: "El Met Office es lo que usa el widget de KDE",
    units: "Unidades",
    inheritPlasma: "Heredar de Plasma",
    inheritPlasmaHint: "Sólo si tienes el widget meteorológico de KDE",
    pickPlace: "Elige una localidad para ver el clima.",

    accent: "Acento",
    accentHint: "Punto de app activa y controles",
    dockTint: "Tono del dock",
    automatic: "Automático",
    language: "Idioma",
    languageHint: "Automático sigue al idioma del sistema",

    island: "Isla",
    dock: "Dock",

    // Monday first, as the week runs here.
    weekdays: ["L", "M", "X", "J", "V", "S", "D"]
};
