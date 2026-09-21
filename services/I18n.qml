pragma Singleton
import Quickshell
import "../translations/es.js" as Es
import "../translations/en.js" as En

// Interface strings, one file per language under translations/.
//
// Kept as plain objects rather than Qt's .ts/.qm machinery, which needs
// a compilation step and a deployment path: a lot of rope for a shell
// whose strings all live in one place. Switching language is a property
// change, so the interface updates without a restart.
Singleton {
    id: root

    readonly property var strings: ({
        es: Es.strings,
        en: En.strings
    })

    // Each language is named in itself, the way language pickers do it:
    // someone who lands on the wrong one still recognises their own.
    readonly property var available: [
        { code: "auto", label: root.t.automatic },
        { code: "es",   label: "Español" },
        { code: "en",   label: "English" },
    ]

    // "auto" follows the session. LANGUAGE wins over LANG when both are
    // set, which is what gettext does and what people expect after
    // changing the language in Plasma.
    readonly property string systemLanguage: {
        const raw = Quickshell.env("LANGUAGE")
                    || Quickshell.env("LC_ALL")
                    || Quickshell.env("LC_MESSAGES")
                    || Quickshell.env("LANG")
                    || "";
        const code = raw.split(":")[0].split(".")[0].split("_")[0].toLowerCase();
        return root.strings[code] !== undefined ? code : "en";
    }

    readonly property string language: {
        const chosen = Config.data.language ?? "auto";
        if (chosen !== "auto" && root.strings[chosen] !== undefined) return chosen;
        return root.systemLanguage;
    }

    readonly property var t: root.strings[root.language] ?? root.strings.en

    // Qt wants a full locale to format month names; the shell only
    // tracks the language, so each one gets a sensible region.
    readonly property string qtLocale: ({
        es: "es_ES", en: "en_GB"
    })[root.language] ?? "en_GB"
}
