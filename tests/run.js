#!/usr/bin/env node
//
// The tests. Run them with `node tests/run.js`, which needs nothing
// installed.
//
// Only the logic that has no screen in it: a sum, a bookmarks file, a
// window class against an application, a clipboard entry. The rest of
// Shima is an interface and is checked by looking at it. These are the
// parts where looking at it would not have told anyone anything — a
// regular expression that quietly stops matching, a parser that gives
// up on one odd character — and every one of the cases below is
// something that actually went wrong at some point.

const { load } = require("./extract.js");

let passed = 0, failed = 0;
const failures = [];

function is(what, got, want) {
    const a = JSON.stringify(got), b = JSON.stringify(want);
    if (a === b) { passed++; return; }
    failed++;
    failures.push("  " + what + "\n      esperado " + b + "\n      obtenido " + a);
}

// ── The calculator ───────────────────────────────────────────────
{
    const { calculate } = load("services/Search.qml", ["calculate", "evaluate"]);
    const sums = [
        ["2+2", "4"], ["10/4", "2.5"], ["7%3", "1"], ["(2+3)*4", "20"],
        ["2^10", "1024"], ["2**10", "1024"], ["2 ^ 3 ^ 2", "512"],
        ["2^-1", "0.5"], ["-2^2", "-4"], ["0.1+0.2", "0.3"],
        ["3,5+1,5", "5"], ["1 + 2 * 3 - 4 / 2", "5"], [".5+.5", "1"],
        ["  7 * 6  ", "42"], ["-(3+4)", "-7"],
        // A number on its own is not a sum, and neither is a word.
        ["5", ""], ["firefox", ""], ["ls -la", ""], ["", ""],
        // Nothing that is not arithmetic gets through. The middle one
        // used to come back 4: the expression was wrapped in brackets
        // and // opens a comment in JavaScript.
        ["2+2;alert(1)", ""], ["2+2)//", ""], ["constructor+1", ""],
        ["1e3+1", ""], ["(1+2", ""], ["1+2)", ""], ["(2+3)(4+5)", ""],
        // Nothing infinite, and nothing reported as infinite either.
        ["1/0", ""], ["5%0", ""],
        ["2^1000", "1.0715086071862673e+301"],
    ];
    for (const [input, want] of sums)
        is("calculate(" + JSON.stringify(input) + ")", calculate(input), want);
}

// ── Places ───────────────────────────────────────────────────────
{
    const p = load("services/Places.qml", ["decode", "between", "attr"]);

    is("decode de un porcentaje válido",
       p.decode("/home/ayoze/Un%20informe.pdf"), "/home/ayoze/Un informe.pdf");
    // One malformed percent used to throw from inside the parsing
    // loop, which took every other bookmark with it.
    is("decode de un porcentaje roto", p.decode("/home/%ZZ/x"), "/home/%ZZ/x");

    is("between corriente",
       p.between("<title>Casa</title>", "<title>", "</title>"), "Casa");
    is("between sin cierre",
       p.between("<title>Casa", "<title>", "</title>"), "");
    is("attr", p.attr('<bookmark href="file:///tmp">', 'href="'), "file:///tmp");
}

// ── The clipboard ────────────────────────────────────────────────
{
    const c = load("services/Clipboard.qml",
                   ["isFiles", "preview", "matches"]);

    is("una dirección de fichero se reconoce",
       c.isFiles("file:///home/ayoze/x.pdf"), true);
    is("un texto cualquiera no",
       c.isFiles("file: no es esto"), false);

    is("la vista previa junta los espacios",
       c.preview({ kind: "text", text: "tres   palabras\ny un salto" }),
       "tres palabras y un salto");
    is("y muestra el fichero como ruta",
       c.preview({ kind: "text", text: "file:///home/ayoze/Un%20informe.pdf" }),
       "/home/ayoze/Un informe.pdf");
    is("una imagen no tiene vista previa",
       c.preview({ kind: "image", path: "/x.png" }), "");

    is("buscar encuentra por dentro",
       c.matches({ kind: "text", text: "Hola Mundo" }, "mun"), true);
    is("y no confunde",
       c.matches({ kind: "text", text: "Hola Mundo" }, "adiós"), false);
    // A picture has nothing to search, so it is not an answer to
    // everything.
    is("una imagen no responde a una búsqueda",
       c.matches({ kind: "image", path: "/x.png" }, "x"), false);
    is("sin búsqueda, todo vale",
       c.matches({ kind: "image", path: "/x.png" }, ""), true);
}

// ── Which screens something is pinned to ─────────────────────────
{
    const screens = [{ name: "DP-1" }, { name: "HDMI-A-1" }];
    const cfg = load("services/Config.qml", ["screenList", "onScreen"],
                     { Quickshell: { screens: screens } });

    is("una lista vacía es todas", cfg.onScreen("", "DP-1"), true);
    is("la elegida", cfg.onScreen("DP-1", "DP-1"), true);
    is("y no la otra", cfg.onScreen("DP-1", "HDMI-A-1"), false);
    // Pinned to a screen that is not there any more: better on every
    // screen than on none, which is a shell with no way back to the
    // settings.
    is("una pantalla que ya no está no deja a nadie sin isla",
       cfg.onScreen("DP-99", "DP-1"), true);
    is("varias, separadas por comas",
       cfg.onScreen("DP-1, HDMI-A-1", "HDMI-A-1"), true);
}

// ── The language ─────────────────────────────────────────────────
{
    const strings = { en: {}, es: {} };
    const i18n = load("services/I18n.qml", ["has"], { root: { strings: strings } });

    is("un idioma que existe", i18n.has("es"), true);
    is("uno que no", i18n.has("zz"), false);
    // Every object in JavaScript has these, and answering yes to them
    // filled the interface with blanks and took the language picker
    // with it.
    is("toString no es un idioma", i18n.has("toString"), false);
    is("constructor tampoco", i18n.has("constructor"), false);
    is("ni valueOf", i18n.has("valueOf"), false);
}

// ── ──────────────────────────────────────────────────────────────
if (failed > 0) {
    console.log("\n" + failures.join("\n\n") + "\n");
    console.log(passed + " bien, " + failed + " mal");
    process.exit(1);
}
console.log(passed + " comprobaciones, todas bien");
