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
    failures.push("  " + what + "\n      expected " + b + "\n      got      " + a);
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

    is("decode of a valid percent",
       p.decode("/home/ayoze/Un%20informe.pdf"), "/home/ayoze/Un informe.pdf");
    // One malformed percent used to throw from inside the parsing
    // loop, which took every other bookmark with it.
    is("decode of a broken percent", p.decode("/home/%ZZ/x"), "/home/%ZZ/x");

    is("between, the ordinary case",
       p.between("<title>Casa</title>", "<title>", "</title>"), "Casa");
    is("between with nothing closing it",
       p.between("<title>Casa", "<title>", "</title>"), "");
    is("attr", p.attr('<bookmark href="file:///tmp">', 'href="'), "file:///tmp");
}

// ── The clipboard ────────────────────────────────────────────────
{
    const c = load("services/Clipboard.qml",
                   ["isFiles", "preview", "matches"]);

    is("a file address is recognised",
       c.isFiles("file:///home/ayoze/x.pdf"), true);
    is("an ordinary line of text is not",
       c.isFiles("file: no es esto"), false);

    is("the preview collapses the whitespace",
       c.preview({ kind: "text", text: "three   words\nand a newline" }),
       "three words and a newline");
    is("and shows a file as its path",
       c.preview({ kind: "text", text: "file:///home/ayoze/Un%20informe.pdf" }),
       "/home/ayoze/Un informe.pdf");
    is("a picture has no preview",
       c.preview({ kind: "image", path: "/x.png" }), "");

    is("searching matches inside the text",
       c.matches({ kind: "text", text: "Hello World" }, "lo w"), true);
    is("and does not match what is not there",
       c.matches({ kind: "text", text: "Hello World" }, "goodbye"), false);
    // A picture has nothing to search, so it is not an answer to
    // everything.
    is("a picture is not an answer to every search",
       c.matches({ kind: "image", path: "/x.png" }, "x"), false);
    is("with nothing typed, everything counts",
       c.matches({ kind: "image", path: "/x.png" }, ""), true);
}

// ── Which screens something is pinned to ─────────────────────────
{
    const screens = [{ name: "DP-1" }, { name: "HDMI-A-1" }];
    const cfg = load("services/Config.qml", ["screenList", "onScreen"],
                     { Quickshell: { screens: screens } });

    is("an empty list means every screen", cfg.onScreen("", "DP-1"), true);
    is("the one that was chosen", cfg.onScreen("DP-1", "DP-1"), true);
    is("and not the other one", cfg.onScreen("DP-1", "HDMI-A-1"), false);
    // Pinned to a screen that is not there any more: better on every
    // screen than on none, which is a shell with no way back to the
    // settings.
    is("a screen that is gone leaves nobody without an island",
       cfg.onScreen("DP-99", "DP-1"), true);
    is("several, separated by commas",
       cfg.onScreen("DP-1, HDMI-A-1", "HDMI-A-1"), true);
}

// ── Numbers out of the settings file ─────────────────────────────
{
    const { number } = load("services/Config.qml", ["number"]);

    is("an ordinary number", number(42, 10, 0, 100), 42);
    is("a number written as text", number("42", 10, 0, 100), 42);
    is("below the minimum", number(-5, 10, 0, 100), 0);
    is("above the maximum", number(9999, 10, 0, 100), 100);

    // What `?? default` let through, on its way into a geometry or a
    // timer.
    is("the key is not there", number(undefined, 10, 0, 100), 10);
    is("null", number(null, 10, 0, 100), 10);
    is("an empty string", number("", 10, 0, 100), 10);
    is("not a number at all", number("banana", 10, 0, 100), 10);
    // Infinity counts as "not a number I can use" rather than as the
    // maximum: in JSON it can only have been written by hand.
    is("infinity", number(Infinity, 10, 0, 100), 10);
    is("infinity, written out", number("Infinity", 10, 0, 100), 10);
    is("NaN itself", number(NaN, 10, 0, 100), 10);

    // Zero is a real value where the minimum allows it — it is what
    // says "no town chosen yet" — and is not where it does not.
    is("zero, where zero is allowed", number(0, 10, 0, 100), 0);
    is("zero, where it is not", number(0, 25, 1, 600), 1);
}

// ── The language ─────────────────────────────────────────────────
{
    const strings = { en: {}, es: {} };
    const i18n = load("services/I18n.qml", ["has"], { root: { strings: strings } });

    is("a language that exists", i18n.has("es"), true);
    is("one that does not", i18n.has("zz"), false);
    // Every object in JavaScript has these, and answering yes to them
    // filled the interface with blanks and took the language picker
    // with it.
    is("toString is not a language", i18n.has("toString"), false);
    is("nor is constructor", i18n.has("constructor"), false);
    is("nor valueOf", i18n.has("valueOf"), false);
}

// ── Reading a function out of a .qml ─────────────────────────────
//
// The thing every test above rests on. It counts braces to find where
// a function ends, and it used to count the ones inside strings,
// comments and regular expressions too — so a brace written in a
// comment would have failed a test on the other side of the file,
// with an error pointing nowhere near what was changed.
{
    const { body } = require("./extract.js");

    const cases = [
        ["a brace inside a string",  'function f() { const s = "}"; return 1; }'],
        ["a brace inside a regex",   "function f() { const r = /[{]/; return 2; }"],
        ["a brace in a line comment", "function f() { // }\n    return 3; }"],
        ["a brace in a block comment", "function f() { /* } */ return 4; }"],
        ["a brace in a template hole", 'function f() { const t = `x${ "}" }y`; return 5; }'],
        ["a slash that divides",     "function f() { return g() / 2; }"],
        ["a regex right after return", 'function f() { return /}/.test("x"); }'],
        ["a quote inside a regex",   "function f() { return /['\"]/.source; }"]
    ];
    for (const [what, src] of cases) {
        let got;
        try { got = body(src, "f"); } catch (e) { got = "threw: " + e.message; }
        is("the whole function comes back with " + what, got, src);
    }
}

// ── Every setting has a line in the documentation ────────────────
//
// Not logic, but the one thing about the reference that can be checked
// by a machine: a settings file people are told to edit by hand is
// only useful while it is all written down, and a key added without a
// line is a key nobody outside this repository can find out about.
{
    const fs = require("fs");
    const path = require("path");
    const { root, source } = require("./extract.js");

    const cfg = source("services/Config.qml");
    const adapter = cfg.slice(cfg.indexOf("JsonAdapter"));
    const keys = [...adapter.matchAll(/^\s+property\s+\w+\s+(\w+):/gm)]
        .map(m => m[1]);
    const doc = fs.readFileSync(path.join(root, "docs/settings.md"), "utf8");

    const missing = keys.filter(k => !doc.includes("`" + k + "`"));
    is("every setting is in docs/settings.md", missing, []);
    // And the other way: a line for something that no longer exists.
    const documented = [...doc.matchAll(/^\| `(\w+)` \|/gm)].map(m => m[1]);
    const stale = documented.filter(k => !keys.includes(k));
    is("and nothing is documented that is gone", stale, []);
}

// ── ──────────────────────────────────────────────────────────────
if (failed > 0) {
    console.log("\n" + failures.join("\n\n") + "\n");
    console.log(passed + " passed, " + failed + " failed");
    process.exit(1);
}
console.log(passed + " checks, all passing");
