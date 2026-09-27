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
    const cfg = load("services/Config.qml",
                     ["screenList", "nowhere", "onScreen"],
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

    // "none" is the only value that is not a screen name, and the only
    // way to say nowhere: empty already means everywhere.
    is("nowhere means nowhere", cfg.onScreen("none", "DP-1"), false);
    is("and on the other one either", cfg.onScreen("none", "HDMI-A-1"), false);
    is("however it was typed", cfg.onScreen("  None ", "DP-1"), false);
}

// ── Checking and unchecking a screen ─────────────────────────────
{
    const screens = [{ name: "DP-1" }, { name: "HDMI-A-1" }];
    const store = {};
    const cfg = load("services/Config.qml",
                     ["screenList", "nowhere", "onScreen", "toggleScreen"],
                     { Quickshell: { screens: screens }, cfg: store });
    cfg.save = () => {};
    const all = ["DP-1", "HDMI-A-1"];

    // The one he found: pinned to one screen, unchecked there, and it
    // came back on both — the list was left empty and empty reads as
    // every screen.
    store.islandScreens = "DP-1";
    cfg.toggleScreen("islandScreens", "DP-1", false, all);
    is("unchecking the only screen on the list says nowhere",
       store.islandScreens, "none");
    is("and the island is on neither",
       cfg.onScreen(store.islandScreens, "DP-1")
       || cfg.onScreen(store.islandScreens, "HDMI-A-1"), false);

    // With a single monitor there was no way to switch either off.
    store.dockScreens = "";
    cfg.toggleScreen("dockScreens", "DP-1", false, ["DP-1"]);
    is("one monitor, unchecked, means nowhere", store.dockScreens, "none");

    // And back again.
    cfg.toggleScreen("dockScreens", "DP-1", true, ["DP-1"]);
    is("checking it again names it", store.dockScreens, "DP-1");
    is("which puts the dock back", cfg.onScreen(store.dockScreens, "DP-1"), true);

    // Unchecking one of two leaves the other, which is the ordinary
    // case and the one that already worked.
    store.islandScreens = "";
    cfg.toggleScreen("islandScreens", "HDMI-A-1", false, all);
    is("unchecking one of two leaves the other", store.islandScreens, "DP-1");
}

// ── A window that calls itself by a longer name ──────────────────
{
    const w = load("services/Windows.qml", ["idForClass"], {});
    w.procIndex = {
        "samrewritten": "sam-rewritten",
        "dolphin": "org.kde.dolphin",
        "org.kde.dolphin": "org.kde.dolphin",
        "terraria": "terraria"
    };

    // The one he found: the desktop file says StartupWMClass=samrewritten
    // and the window announces org.samrewritten.SamRewritten, so nothing
    // matched and it never reached the dock.
    is("a reversed-domain class is known by its last segment",
       w.idForClass("org.samrewritten.samrewritten"), "sam-rewritten");

    // What already worked keeps working: the whole class is tried first.
    is("and the whole name still wins when it is known",
       w.idForClass("org.kde.dolphin"), "org.kde.dolphin");

    // A binary is known by its first segment, which is the other half
    // of this function and must not have changed.
    is("a binary is still known by its first segment",
       w.idForClass("terraria.bin.x86_64"), "terraria");

    // And nothing is invented for a name nobody knows.
    is("an unknown class stays unknown",
       w.idForClass("com.example.whatever"), undefined);

    // The list of prefixes that mark a reverse domain cannot be
    // complete: one is free to start with de, page, garden or fyi, and
    // Flathub is full of those. An unlisted prefix used to be a dead
    // end; now it misses at the front and is read off the back.
    w.procIndex["haruna"] = "org.kde.haruna";
    for (const cls of ["de.haeckerfelix.haruna", "page.codeberg.haruna",
                       "garden.jamie.haruna", "fyi.zoey.haruna",
                       "sh.cider.haruna"])
        is("a reversed domain starting with " + cls.split(".")[0]
           + " is read the same way", w.idForClass(cls), "org.kde.haruna");

    // A name with one dot and nothing known at the front falls back to
    // the back, so a two-part class is not a dead end either.
    is("a single dot is tried at both ends",
       w.idForClass("flatpak.dolphin"), "org.kde.dolphin");

    // Two letters at either end are too little to go on: "io" and "me"
    // are prefixes, not applications.
    is("a segment of two letters is not matched",
       w.idForClass("io.unknown.zz"), undefined);
}

// ── An application that was open before it was pinned ────────────
{
    const entries = {
        "org.kde.konsole": {
            id: "org.kde.konsole", execString: "konsole",
            startupClass: "konsole", name: "Konsole",
            icon: "utilities-terminal"
        }
    };
    const w = load("services/Windows.qml",
                   ["sweepDone", "idForClass", "candidatesFor",
                    "matchesProcess", "sameState"],
                   { Apps: { settingsClass: "shima", settingsId: "shima:settings",
                             steamGames: {}, rescanSteam: () => {},
                             entryFor: (id) => entries[id] || null },
                     Pinned: { list: ["org.kde.konsole"] },
                     Config: { data: { showRunning: true } },
                     Games: { byClass: {} } });
    w.neverShow = ["plasmashell", "quickshell"];
    w.launchers = [];
    w.procIndex = { "org.kde.konsole": "org.kde.konsole",
                    "konsole": "org.kde.konsole" };
    w.runningIds = {};
    w.misses = {};
    w.steamAsked = {};
    // What a first sweep leaves behind: the dock inherits Plasma's pins
    // after it has already seen what was open, so whatever was running
    // went in as an application that is merely open.
    w.runningExtra = ["org.kde.konsole"];

    w.sweepDone("org.kde.konsole\nplasmashell\n");

    is("an application pinned since the last sweep is not listed twice",
       w.runningExtra.indexOf("org.kde.konsole"), -1);
    is("and it still counts as running",
       w.runningIds["org.kde.konsole"], true);

    // The ordinary case is untouched: something open that nobody
    // pinned keeps its place in the dock.
    entries["org.kde.kate"] = { id: "org.kde.kate", execString: "kate",
                                name: "Kate", icon: "kate" };
    w.procIndex["org.kde.kate"] = "org.kde.kate";
    w.runningExtra = ["org.kde.kate"];
    w.runningIds = {};
    w.misses = {};
    w.sweepDone("org.kde.konsole\norg.kde.kate\n");
    is("and one that is only open stays",
       w.runningExtra.indexOf("org.kde.kate") !== -1, true);
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

// ── The KDE menu ─────────────────────────────────────────────────
//
// What the launcher's sidebar is made of. The reading is a tab
// separated line per entry, straight out of kbuildsycoca's view of the
// menu, and everything below is a case that came out of a real one.
{
    // The revision counter lives with the catalogue, so it is handed
    // in the way the shell hands it: an object the menu writes to.
    const menu = (text) => {
        const apps = { revision: 0 };
        const a = load("services/Menu.qml", ["parse", "same"],
                       { I18n: { language: "en" }, Apps: apps });
        a.menuApps = {};
        a.menuCats = [];
        a.hasMenu = false;
        a.catalogue = apps;
        a.parse(text);
        return a;
    };

    const a = menu([
        "Internet/\tfirefox.desktop",
        "Internet/\tfirefox.desktop",           // listed twice
        "Wine/Programs/Vital/\tvital.desktop",  // a submenu two deep
        "Development/\torg.kde.kate.desktop",
        "Internet/\tnotes.txt",                 // not an application
        "a line with no tab in it"
    ].join("\n"));

    is("the menu falls into its categories", a.menuApps,
       { Internet: ["firefox"], Wine: ["vital"], Development: ["org.kde.kate"] });
    is("and the categories come out sorted", a.menuCats,
       ["Development", "Internet", "Wine"]);
    is("a menu that was read counts as one", a.hasMenu, true);

    // Nothing to read is not an empty menu: it means this machine has
    // no menu to read, and the launcher sorts by the .desktop files
    // instead.
    is("nothing to read is not a menu", menu("").hasMenu, false);

    // The launcher rereads this every time it opens, and saying that
    // something changed when nothing did reloads every icon in the
    // dock, which blink out and back in.
    const b = menu("Internet/\tfirefox.desktop");
    b.catalogue.revision = 0;
    b.parse("Internet/\tfirefox.desktop");
    is("reading the same menu again changes nothing", b.catalogue.revision, 0);
    b.parse("Internet/\tfirefox.desktop\nInternet/\tthunderbird.desktop");
    is("and reading a different one does", b.catalogue.revision, 1);
}

// ── Which application a window belongs to ────────────────────────
//
// The part with the most ways to be subtly wrong, and the one that
// shows when it is: an icon that lights up for something that is not
// running, or a game that is open and dark.
{
    const { literal } = require("./extract.js");

    const dolphin = {
        id: "org.kde.dolphin", startupClass: "org.kde.dolphin",
        execString: "/usr/bin/dolphin %u", name: "Dolphin"
    };
    // A Steam game: what it runs is Steam itself, and the number in
    // the URL is the only thing that says which game.
    const terraria = {
        id: "terraria", execString: "steam steam://rungameid/105600",
        name: "Terraria"
    };
    // Named after something longer than a process name can be.
    const long = {
        id: "supercalifragilistic", execString: "/usr/bin/supercalifragilistic",
        name: "Supercalifragilistic"
    };
    const hidden = { id: "org.kde.hidden", execString: "hidden", noDisplay: true };

    const apps = (values) => {
        const a = load("services/Windows.qml",
            ["candidatesFor", "idForClass", "buildIndex", "matchesProcess"],
            { DesktopEntries: { applications: { values: values || [] } } });
        a.launchers = literal("services/Windows.qml", "launchers");
        a.procIndex = {};
        return a;
    };

    const a = apps();

    is("an ordinary application answers to its class and its binary",
       a.candidatesFor(dolphin),
       ["org.kde.dolphin", "org.kde.dolphin", "dolphin", "dolphin", "dolphin"]);
    // Steam is a middleman: letting it count would have every game
    // claiming the Steam process, and Steam itself claiming none.
    is("a Steam game answers to its number and not to steam",
       a.candidatesFor(terraria),
       ["terraria", "terraria", "steam_app_105600", "terraria"]);
    // The name is only read for games, and only a one-word name: it
    // is how a game built for Linux is recognised, since its window is
    // called after its own binary and that is nowhere in the .desktop.
    is("an application that is not a game is not matched on its name",
       a.candidatesFor({ id: "x.foo", execString: "/usr/bin/foo", name: "Bar" }),
       ["x.foo", "foo", "foo"]);

    const idx = apps([dolphin, terraria, long, hidden]);
    idx.buildIndex();

    is("a window class finds its application",
       idx.idForClass("org.kde.dolphin"), "org.kde.dolphin");
    is("and so does the last part of it", idx.idForClass("dolphin"), "org.kde.dolphin");
    is("a Steam game is found by its number",
       idx.idForClass("steam_app_105600"), "terraria");
    // "terraria.bin.x86_64" is the binary of a game built for Linux.
    is("a binary with its architecture stuck on the end still finds it",
       idx.idForClass("terraria.bin.x86_64"), "terraria");
    // The kernel cuts a process name at fifteen characters.
    is("a name cut short by the kernel still finds it",
       idx.idForClass("supercalifragil"), "supercalifragilistic");
    is("something hidden from the menu is not in the index",
       idx.idForClass("hidden"), undefined);

    // A class is looked up as the window manager spells it, in lower
    // case, which is how the sweep hands it over.
    //
    // And the piece before the first dot is only worth trying when the
    // name is not a reversed domain: the "com" of "com.spotify.client"
    // says nothing about what it is. So even with something in the
    // index that does answer to "com", it must not be reached that
    // way — otherwise every application published under a domain
    // would have resolved to whatever happened to be called after it.
    const odd = apps([{ id: "com", execString: "/usr/bin/com", name: "Com" }]);
    odd.buildIndex();
    is("something in the index called com is found by that name",
       odd.idForClass("com"), "com");
    is("but a reversed domain is not cut at its first dot",
       odd.idForClass("com.spotify.client"), undefined);

    is("a process with the same name as the binary counts",
       a.matchesProcess(dolphin, ["kwin_wayland", "dolphin"]), true);
    is("and one cut short by the kernel counts too",
       a.matchesProcess(long, ["supercalifragil"]), true);
    is("a name with spaces in it is matched without them",
       a.matchesProcess({ name: "Visual Studio Code" }, ["visualstudiocode"]), true);
    // Six characters before a partial match is allowed, or "ab" would
    // light up for anything beginning with it.
    is("a short name does not catch a longer process",
       a.matchesProcess({ id: "x.ab" }, ["abcdefgh"]), false);
    is("and nothing running means nothing matches",
       a.matchesProcess(dolphin, []), false);
}

// ── What is running, sweep after sweep ───────────────────────────
//
// The answer to "which icons light up", worked out from the list of
// window classes KWin hands back. Nearly everything here is a rule
// that exists because the dock did something silly without it.
{
    const { literal } = require("./extract.js");

    const catalogue = {
        "org.kde.dolphin": { id: "org.kde.dolphin", icon: "system-file-manager",
            startupClass: "org.kde.dolphin", execString: "/usr/bin/dolphin",
            name: "Dolphin" },
        "org.kde.kate": { id: "org.kde.kate", icon: "kate",
            startupClass: "org.kde.kate", execString: "/usr/bin/kate",
            name: "Kate" },
        // The same application twice over: the package and the
        // flatpak, sharing one binary and one window.
        "com.discordapp.Discord": { id: "com.discordapp.Discord", icon: "discord",
            execString: "/usr/bin/discord", name: "Discord" },
        discord: { id: "discord", icon: "discord",
            execString: "/usr/bin/discord", name: "Discord" },
        // Something with no icon of its own, which would be a blank
        // square in the dock.
        faceless: { id: "faceless", execString: "/usr/bin/faceless", name: "Faceless" },
        plasmashell: { id: "plasmashell", icon: "plasma",
            execString: "/usr/bin/plasmashell", name: "Plasma" }
    };

    const sweeper = (pinned) => {
        const values = Object.keys(catalogue).map(k => catalogue[k]);
        const a = load("services/Windows.qml",
            ["sweepDone", "buildIndex", "candidatesFor", "idForClass",
             "matchesProcess", "sameState"],
            {
                Games: { byClass: {} },
                Config: { data: { showRunning: true } },
                DesktopEntries: { applications: { values: values } },
                // The two it asks: what is pinned, and the catalogue.
                Pinned: { list: pinned || [] },
                Apps: {
                    settingsClass: "shima",
                    settingsId: "shima-settings",
                    steamGames: {},
                    rescanSteam: () => {},
                    // Our own settings window has no .desktop file on
                    // disk: the real one makes an entry up for it, so
                    // the stub does too.
                    entryFor: (id) => id === "shima-settings"
                        ? { id: "shima-settings", icon: "shima", name: "Shima" }
                        : (catalogue[id] || null)
                }
            });
        a.launchers = literal("services/Windows.qml", "launchers");
        a.neverShow = literal("services/Windows.qml", "neverShow");
        a.runningIds = {};
        a.runningExtra = [];
        a.misses = {};
        a.steamAsked = {};
        a.procIndex = {};
        a.buildIndex();
        return a;
    };

    const lit = (a) => Object.keys(a.runningIds).filter(k => a.runningIds[k]).sort();

    const a = sweeper(["org.kde.dolphin", "org.kde.kate"]);
    a.sweepDone("dolphin\nkwin_wayland\n");
    is("a pinned application whose window is there lights up",
       lit(a), ["org.kde.dolphin"]);
    is("and one whose window is not, does not", a.runningIds["org.kde.kate"], false);

    // An answer with nothing in it is a question that failed — KWin
    // busy under a fullscreen game — and not an empty desktop.
    a.sweepDone("");
    is("an empty answer changes nothing", lit(a), ["org.kde.dolphin"]);

    // Asking KWin goes through its scripting API, which turns slow and
    // uneven while a game is up. One sweep that misses used to take
    // the icon out and the next one put it back, with everything
    // beside it sliding over twice.
    a.sweepDone("kwin_wayland\n");
    is("one sweep that misses it is forgiven", lit(a), ["org.kde.dolphin"]);
    a.sweepDone("kwin_wayland\n");
    is("two in a row are not", lit(a), []);

    // What is open but not pinned goes in behind, and only once: two
    // .desktop files of the same application share a binary and would
    // otherwise be two icons for one window.
    const b = sweeper([]);
    b.sweepDone("discord\ndolphin\n");
    is("what is open and not pinned goes in behind", b.runningExtra.length, 2);
    // Which of the two .desktop files wins is whichever owns the name
    // and comes last in the catalogue, and that is the system's order
    // to decide, not ours. What matters is that it is one icon.
    is("and two .desktop files of one application are one icon",
       b.runningExtra.filter(id => id.toLowerCase().indexOf("discord") !== -1).length, 1);
    is("with the rest in alphabetical order",
       b.runningExtra.slice().sort(), b.runningExtra);

    // And when the window manager reports both classes at once —
    // which is what two windows of the same application, opened from
    // each of its two .desktop files, looks like — they are still one
    // icon. Both resolve to an entry of their own, so nothing above
    // catches it: it is caught by what they have in common.
    const b2 = sweeper([]);
    b2.sweepDone("discord\ncom.discordapp.discord\n");
    is("two windows of one application under different classes are one icon",
       b2.runningExtra.length, 1);

    // The same, but with one of the two pinned: the pinned one covers
    // it and nothing is added behind.
    const c = sweeper(["discord"]);
    c.sweepDone("discord\n");
    is("what a pinned icon already covers is not added again",
       c.runningExtra, []);
    is("and the pinned one is the one that lights up", lit(c), ["discord"]);

    // Ourselves and the desktop are not applications in the dock, and
    // something with no icon would be an empty square.
    const d = sweeper([]);
    d.sweepDone("plasmashell\nfaceless\nshima\n");
    is("the desktop and the shell stay out of the dock",
       d.runningExtra.indexOf("plasmashell"), -1);
    is("and so does something with no icon to draw",
       d.runningExtra.indexOf("faceless"), -1);
    // Ours is not the shell: it is a window like any other while it
    // is open, and it is known by its class because it has no
    // .desktop file of its own.
    is("but our own settings window shows while it is open",
       d.runningExtra, ["shima-settings"]);
}

// ── The application a notification came from ─────────────────────
{
    const values = [
        { id: "org.kde.discover", name: "Discover" },
        { id: "firefox", name: "Firefox" }
    ];
    const a = load("services/Apps.qml", ["matchApp"], {
        DesktopEntries: {
            applications: { values: values },
            byId: (id) => values.find(e => e.id === id) || null
        }
    });

    is("the id it gives is used first",
       a.matchApp("firefox.desktop", "Something Else").id, "firefox");
    is("failing that, the name it goes by",
       a.matchApp("", "Firefox").id, "firefox");
    // Only when nothing matched outright, so an application actually
    // called "Discover" would win over this one.
    is("and failing that, the last part of an id",
       a.matchApp("", "discover").id, "org.kde.discover");
    is("an application nobody has is nobody's", a.matchApp("", "nothing"), null);
}

// ── What was opened recently ─────────────────────────────────────
{
    const { literal } = require("./extract.js");
    const catalogue = {
        firefox: { id: "firefox", name: "Firefox" },
        discord: { id: "discord", name: "Discord" },
        // The same application installed twice over, which is what
        // having both the package and the flatpak looks like.
        "com.discordapp.Discord": { id: "com.discordapp.Discord", name: "Discord" },
        gone: { id: "gone", name: "Gone", noDisplay: true }
    };

    // Two files, wired the way the shell wires them: the catalogue
    // knows how to draw a file, the recent list only knows what was
    // opened.
    const recent = (lines) => {
        const catalogueSide = load("services/Apps.qml",
            ["fileEntry", "iconForExtension"], {});
        catalogueSide.extensionIcons =
            literal("services/Apps.qml", "extensionIcons");

        const a = load("services/Recent.qml", ["parse", "sameList"], {
            Apps: {
                revision: 0,
                entryFor: (id) => catalogue[id] || null,
                fileEntry: catalogueSide.fileEntry
            }
        });
        a.all = [];
        a.parse(lines.join("\n"));
        return a;
    };

    const a = recent([
        "app\t1\tapplications:firefox.desktop",
        "app\t2\tdiscord.desktop",
        "app\t3\tcom.discordapp.Discord.desktop",  // the same one again
        "app\t4\tapplications:gone.desktop",       // hidden from the menu
        "app\t5\tapplications:uninstalled.desktop",
        "file\t6\t/home/someone/A report.pdf",
        "file\t7\t/home/someone/A report.pdf",     // the same file again
        "file\t8\t/home/someone/Pictures"
    ]);

    is("what was opened is read in order",
       a.apps.map(e => e.id), ["firefox", "discord"]);
    is("and the files with it",
       a.files.map(e => e.name), ["A report.pdf", "Pictures"]);
    is("a document gets the icon of its kind",
       a.files[0].icon, "application-pdf");
    is("and something with no extension is taken for a folder",
       a.files[1].icon, "folder");
    is("a path with a space in it survives being made into a URL",
       a.files[0].url, "file:///home/someone/A%20report.pdf");

    // Two rows of four, and a dozen files: more than that is not a
    // list of what you were just doing.
    const many = [];
    for (let i = 0; i < 20; i++) many.push("app\t" + i + "\tfirefox.desktop");
    for (let i = 0; i < 20; i++) many.push("file\t" + i + "\t/tmp/f" + i);
    const b = recent(many);
    is("no more applications than fit", b.apps.length <= 8, true);
    is("and no more files than fit", b.files.length, 12);
}

// ── What Heroic and Lutris have installed ────────────────────────
//
// A program of its own, so it is run as one, against catalogues made
// up for the occasion. Steam names a game's window after the game;
// these two do not, and the only thing that says which executable
// belongs to which game is the launcher's own catalogue — which is
// somebody else's file, on somebody else's machine, in a format that
// can move on without telling us.
{
    const fs = require("fs");
    const os = require("os");
    const path = require("path");
    const { execFileSync } = require("child_process");
    const { root } = require("./extract.js");

    const python = (() => {
        try { execFileSync("python3", ["-c", ""]); return "python3"; }
        catch (e) { return null; }
    })();

    if (!python) {
        console.log("  (no python3 here, so shima-games is not exercised)");
    } else {
        const home = fs.mkdtempSync(path.join(os.tmpdir(), "shima-test-"));

        const write = (where, what) => {
            const full = path.join(home, where);
            fs.mkdirSync(path.dirname(full), { recursive: true });
            fs.writeFileSync(full, what);
            return full;
        };

        const games = (args) => {
            try {
                return execFileSync(python,
                    [path.join(root, "helper/shima-games")].concat(args || []),
                    { env: { HOME: home, PATH: process.env.PATH }, encoding: "utf8" });
            } catch (e) { return "the helper failed: " + e.message; }
        };

        is("with no launcher installed it says nothing", games(), "");

        write(".config/heroic/store_cache/gog_library.json", JSON.stringify({
            games: [
                { title: "Cuphead", is_installed: true,
                  install: { executable: "C:\\Games\\Cuphead\\Cuphead.exe" } },
                // Not installed: nothing of it is on this machine.
                { title: "Hollow Knight", is_installed: false,
                  install: { executable: "hollow_knight.exe" } },
                // What every GOG install brings along, with no
                // executable of its own to recognise.
                { title: "Redistributables", is_installed: true, install: {} }
            ]
        }));

        is("a Windows path comes back as the name of the window",
           games(), "cuphead.exe\tCuphead\theroic\theroic\n");

        // Lutris keeps its games in SQLite, and the icon it installs
        // is named after the slug.
        const db = path.join(home, ".local/share/lutris/pga.db");
        fs.mkdirSync(path.dirname(db), { recursive: true });
        execFileSync(python, ["-c",
            "import sqlite3,sys\n"
            + "c=sqlite3.connect(sys.argv[1])\n"
            + "c.execute('create table games (name text, slug text, "
            + "executable text, installed int)')\n"
            + "c.executemany('insert into games values (?,?,?,?)', ["
            + "('Celeste','celeste','/games/Celeste/Celeste.bin.x86_64',1),"
            + "('Braid','braid','/games/braid/braid',0),"
            + "('Cuphead','cuphead-lutris','C:/Games/Cuphead.exe',1)])\n"
            + "c.commit()", db]);

        const both = games().split("\n").filter(l => l);
        is("an installed game is listed with the icon of its slug",
           both.filter(l => l.startsWith("celeste")),
           ["celeste.bin.x86_64\tCeleste\tlutris_celeste\tlutris"]);
        is("one that is not installed is not listed",
           both.filter(l => l.indexOf("braid") !== -1), []);
        // The same game in both launchers is one icon in the dock, not
        // two fighting over the same window.
        is("the same executable twice is listed once",
           both.filter(l => l.startsWith("cuphead.exe")).length, 1);

        // Somebody else's file, in a format that may have moved on.
        write(".config/heroic/store_cache/gog_library.json", "{ this is not json");
        is("a catalogue that cannot be read is skipped, not fatal",
           games().split("\n").filter(l => l).map(l => l.split("\t")[3]),
           ["lutris", "lutris"]);

        fs.rmSync(home, { recursive: true, force: true });
    }
}

// ── Games dragged into Steam rather than installed by it ─────────
//
// Steam keeps these in a binary file and keeps the id in it with the
// wrong sign, so the number in the file and the number on the window
// are not the same number. That is the one thing here that cannot be
// seen by looking: a reader that ignored the sign would have produced
// a perfectly sensible table that matched nothing at all, and the dock
// would have stayed empty with nothing to show for it.
{
    const { execFileSync } = require("child_process");
    const a = load("services/Apps.qml",
        ["parseShortcuts", "shortcutsFromScan", "gridArt", "thumbnailsFor",
         "exePath", "firstArt", "iconFilesToCheck", "withIconFiles"],
        { Qt: { md5: (s) => require("crypto").createHash("md5")
                                 .update(s).digest("hex") } });

    // A shortcuts.vdf, written by hand: 0 opens an object, 1 is a
    // string, 2 is a four byte number, 8 closes.
    const bytes = [];
    const put = (...xs) => bytes.push(...xs);
    const key = (t, k) => { put(t); for (const c of Buffer.from(k, "utf8")) put(c); put(0); };
    const text = (k, v) => { key(1, k); for (const c of Buffer.from(v, "utf8")) put(c); put(0); };
    const int = (k, n) => {
        key(2, k);
        put(n & 255, (n >> 8) & 255, (n >> 16) & 255, (n >>> 24) & 255);
    };

    key(0, "shortcuts");
      key(0, "0");
        int("appid", -971936047);
        text("AppName", "Touge Attack");
        // Quoted, which is how Steam writes it: it is a command line
        // and not a path, and the games with a space in the folder are
        // exactly the ones this has to survive.
        text("Exe", '"/home/ayoze/Games/Touge Attack/TougeAttackTest.exe"');
        text("icon", "/home/ayoze/Imágenes/touge.png");
        key(0, "tags"); text("0", "racing"); put(8);
      put(8);
      key(0, "1");
        int("appid", -1911369838);
        text("AppName", "Bloodborne\u2122 The Old Hunters");
        text("icon", "C:\\Program Files (x86)\\Steam\\256x256.png");
      put(8);
      key(0, "2");
        int("appid", 1234567);
        text("AppName", "Small Positive Id");
      put(8);
    put(8, 8);

    // Through od if there is one, because that is what the shell side
    // actually runs and its spacing is the contract between them.
    const dump = (() => {
        try {
            const fs = require("fs"), os = require("os"), path = require("path");
            const f = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "shima-vdf-")),
                                "shortcuts.vdf");
            fs.writeFileSync(f, Buffer.from(bytes));
            const out = execFileSync("od", ["-An", "-v", "-tu1", f], { encoding: "utf8" });
            fs.unlinkSync(f);
            return out;
        } catch (e) {
            // No od here, so the same thing written out by hand.
            let s = "";
            for (let i = 0; i < bytes.length; i += 16)
                s += bytes.slice(i, i + 16).map(b => String(b).padStart(4)).join("") + "\n";
            return s;
        }
    })();

    const games = a.parseShortcuts(dump);

    // The one that started this: the file says -971936047 and the
    // window says steam_app_3323031249.
    is("a negative id is read as the number the window uses",
       games["3323031249"] && games["3323031249"].name, "Touge Attack");
    is("and so is the next one along",
       games["2383597458"] && games["2383597458"].name,
       "Bloodborne\u2122 The Old Hunters");
    is("a positive id is left alone",
       games["1234567"] && games["1234567"].name, "Small Positive Id");
    is("and nothing else came out of it", Object.keys(games).sort(),
       ["1234567", "2383597458", "3323031249"]);

    // The name is UTF-8 and is decoded as such. Read one byte at a
    // time it comes out as Bloodborne\u00c2\u2122, which is what a
    // person would have seen in the dock.
    is("a name outside ASCII survives",
       games["2383597458"].name.indexOf("\u2122") > 0, true);

    // A file that stops in the middle of a value gives back what it
    // had and does not go looking past the end.
    is("a truncated file gives up quietly",
       Object.keys(a.parseShortcuts(dump.split(/\s+/).slice(0, 12).join(" "))).length, 0);
    is("and so does an empty one", a.parseShortcuts(""), {});

    // Now the whole scan, artwork and all. Steam's pictures are named
    // after the id, and which one to draw is an order of preference:
    // the icon slot, then one chosen by hand, then the wordmark, the
    // header and the poster, and last of all whatever a file manager
    // already made of the executable.
    const home = "/home/ayoze/.steam/steam/userdata/883306741/config";
    const thumbs = "/home/ayoze/.cache/thumbnails";
    const scan = "@" + home + "\n"
        + "+3323031249_logo.png\n"
        + "+3323031249p.jpg\n"
        + "+3323031249_icon.png\n"
        + "+3323031249.json\n"
        + "+2383597458_logo.png\n"
        + "+2383597458.jpg\n"
        + dump;
    const found = a.shortcutsFromScan(scan, thumbs);

    is("the icon slot wins over everything else", found["3323031249"].art,
       home + "/grid/3323031249_icon.png");
    is("and the wordmark when there is no icon", found["2383597458"].art,
       home + "/grid/2383597458_logo.png");
    is("a game with nothing at all gets nothing made up",
       found["1234567"].art, "");
    is("the name comes through the whole way",
       found["3323031249"].name, "Touge Attack");

    // The .json that sits beside each picture is not a picture.
    const onlyJson = a.shortcutsFromScan("@/tmp/config\n+1234567.json\n" + dump,
                                         thumbs);
    is("a .json is not artwork", onlyJson["1234567"].art, "");

    // Two Steam accounts on one machine are two sections, and a
    // section with no folder on its first line is not a section.
    const two = a.shortcutsFromScan(scan + "\n@/tmp/other/config\n"
        + "+1234567_icon.png\n" + dump, thumbs);
    is("a second account is read too", two["1234567"].art,
       "/tmp/other/config/grid/1234567_icon.png");
    is("and nothing is invented from an empty scan",
       a.shortcutsFromScan("", thumbs), {});

    // The picture nobody has confirmed yet: the path Steam keeps in
    // its own Properties box, and the one a file manager may have left
    // in the shared thumbnail cache. Both are asked about at once.
    const exe = "/home/ayoze/Games/Touge Attack/TougeAttackTest.exe";
    const hash = require("crypto").createHash("md5")
        .update(encodeURI("file://" + exe)).digest("hex");

    is("a Windows path is never a candidate",
       a.iconFilesToCheck(a.shortcutsFromScan("@" + home + "\n" + dump, thumbs))
        .indexOf("C:\\Program Files (x86)\\Steam\\256x256.png"), -1);

    const bare = a.shortcutsFromScan("@" + home + "\n" + dump, thumbs);
    is("the ones worth asking about, in order", a.iconFilesToCheck(bare),
       ["/home/ayoze/Im\u00e1genes/touge.png",
        thumbs + "/x-large/" + hash + ".png",
        thumbs + "/large/" + hash + ".png",
        thumbs + "/normal/" + hash + ".png"]);

    // Nothing is asked about a game whose icon slot is already filled.
    is("a filled icon slot asks nothing",
       a.iconFilesToCheck(a.shortcutsFromScan(
           "@" + home + "\n+3323031249_icon.png\n" + dump, thumbs))
        .indexOf("/home/ayoze/Im\u00e1genes/touge.png"), -1);

    // There, so it wins over the wordmark.
    const withLogo = a.shortcutsFromScan(
        "@/tmp/config\n+3323031249_logo.png\n" + dump, thumbs);
    is("an icon chosen by hand beats the wordmark",
       a.withIconFiles(withLogo, { "/home/ayoze/Im\u00e1genes/touge.png": true })
        ["3323031249"].art, "/home/ayoze/Im\u00e1genes/touge.png");

    // Not there, so the wordmark stands and nothing else is reached.
    is("and a path to nothing changes nothing",
       a.withIconFiles(withLogo, {})["3323031249"].art,
       "/tmp/config/grid/3323031249_logo.png");

    // With no artwork at all, the executable's own picture. This is
    // the case that started it: a game added an hour ago, no artwork
    // anywhere, and its logo sitting inside a .exe where Dolphin had
    // already been and left a copy.
    is("the thumbnail of the executable is the last resort",
       a.withIconFiles(bare, { [thumbs + "/x-large/" + hash + ".png"]: true })
        ["3323031249"].art, thumbs + "/x-large/" + hash + ".png");
    is("and a smaller one will do if that is all there is",
       a.withIconFiles(bare, { [thumbs + "/normal/" + hash + ".png"]: true })
        ["3323031249"].art, thumbs + "/normal/" + hash + ".png");
    is("but the wordmark still comes first",
       a.withIconFiles(a.shortcutsFromScan(
           "@" + home + "\n+3323031249_logo.png\n" + dump, thumbs),
           { [thumbs + "/x-large/" + hash + ".png"]: true })["3323031249"].art,
       home + "/grid/3323031249_logo.png");

    // An Exe line is a command, not a path: quoted, and with the
    // game's own arguments after it. One of the four on this machine
    // runs an emulator with the game as an argument.
    is("a quoted path with spaces comes out whole", a.exePath('"' + exe + '"'), exe);
    is("and the arguments are left behind",
       a.exePath('"/opt/shadPS4/shadPS4.exe" -g "/roms/eboot.bin"'),
       "/opt/shadPS4/shadPS4.exe");
    is("an unquoted one works too", a.exePath("/usr/bin/thing --flag"), "/usr/bin/thing");
    is("a Windows path is not a path we can reach",
       a.exePath('"E:\\Program Files\\shadPS4\\shadPS4.exe"'), "");
    is("and neither is nothing at all", a.exePath(""), "");

    // And the entry the dock is handed. A picture on disk is not a
    // name in the icon theme, so it goes in as a url; with no picture
    // it falls back to a name, because a tile that draws nothing at
    // all looks like a fault.
    const e = load("services/Apps.qml", ["steamEntry"], {});
    e.steamGames = { "105600": "Terraria" };
    e.steamShortcuts = {
        "3323031249": { name: "Touge Attack", art: "/tmp/grid/3323031249_icon.png" },
        "1234567": { name: "No Art", art: "" }
    };

    is("an installed game still comes from its manifest",
       e.steamEntry("steam_app_105600").icon, "steam_icon_105600");
    const shortcut = e.steamEntry("steam_app_3323031249");
    is("a hand-added game carries its picture as a file",
       shortcut.iconUrl, "file:///tmp/grid/3323031249_icon.png");
    is("and no name in the theme, which has none for it",
       shortcut.icon, "");
    is("its name is its own", shortcut.name, "Touge Attack");
    is("it is launched like any other Steam game", shortcut.appId, "3323031249");
    is("with no picture it wears a generic one",
       e.steamEntry("steam_app_1234567").icon, "applications-games");
    is("and a game nobody has heard of is still nobody",
       e.steamEntry("steam_app_999"), null);
}

// ── A tray icon that has no menu to give ─────────────────────────
//
// Two kinds of icon and one of them hands us nothing. Most programs
// publish a menu over DBusMenu and Quickshell gives it to us ready to
// show; a Windows program under Wine arrives through a bridge that has
// no menu on the bus at all and expects to be asked instead. Shima used
// to give up on the second kind without a word.
//
// What matters here is that the first kind did not change: it is every
// tray icon anybody has, and it goes through the same call it always
// did.
{
    const calls = [];
    const t = load("components/TrayItem.qml", ["showMenu"], {
        Quickshell: { execDetached: (argv) => calls.push(argv) }
    });
    t.width = 30;
    t.dockWindow = { name: "dock" };
    t.helper = "/opt/shima/helper/shima-tray-menu";
    t.mapToItem = () => ({ x: 100, y: 200 });
    t.mapToGlobal = () => ({ x: 640.4, y: 1399.6 });

    // The ordinary kind: shown by Quickshell, and nothing is run.
    let shown = null;
    t.item = { hasMenu: true, id: "discord_status_icon_1",
               display: (w, x, y) => { shown = [w.name, x, y]; } };
    t.showMenu();
    is("an icon with a menu is still shown the way it always was",
       shown, ["dock", 100, 200]);
    is("and nothing is run for it", calls.length, 0);

    // The bridged kind: asked through the helper, with the icon's
    // place on screen rounded to whole pixels because it goes on a
    // command line.
    t.item = { hasMenu: false, id: "71303180", display: () => {} };
    t.showMenu();
    is("an icon with no menu is asked through the helper", calls,
       [["/opt/shima/helper/shima-tray-menu", "71303180", "640", "1400"]]);

    // And every way of having nothing to ask is a quiet no.
    calls.length = 0;
    t.item = null;
    t.showMenu();
    t.item = { hasMenu: false, id: "", display: () => {} };
    t.showMenu();
    t.item = { hasMenu: false, id: "71303180", display: () => {} };
    t.helper = "";
    t.showMenu();
    is("no item, no id or no helper runs nothing at all", calls.length, 0);

    // A window that is not there yet is not a reason to run the helper
    // for an icon that has a menu of its own.
    t.helper = "/opt/shima/helper/shima-tray-menu";
    t.dockWindow = null;
    t.item = { hasMenu: true, id: "discord_status_icon_1", display: () => {} };
    t.showMenu();
    is("and an icon with a menu waits for the dock rather than falling through",
       calls.length, 0);
}

// ── The clock under what is playing ──────────────────────────────
//
// Read against Spotify, which reports 251.217 seconds for a track its
// own window calls 4:11.
{
    const { clock } = load("components/MediaMode.qml", ["clock"], {});
    const cases = [
        [251.217, "4:11"],   // what Spotify said, to the millisecond
        [0, "0:00"], [4.2, "0:04"], [59.9, "0:59"], [60, "1:00"],
        [599, "9:59"], [3599, "59:59"],
        // Past the hour it grows a field, and the minutes take a
        // leading zero so the columns do not jump about.
        [3600, "1:00:00"], [3661, "1:01:01"], [7322, "2:02:02"],
        // Nothing sensible in, nothing silly out.
        [-5, "0:00"], [NaN, "0:00"]
    ];
    for (const [seconds, want] of cases)
        is("clock(" + seconds + ")", clock(seconds), want);
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

// ── A window name is never part of a shell script ────────────────
//
// The names come out of desktop files and out of the titles Steam
// keeps, so they come from outside. They used to be written into a
// script with JSON.stringify around them, which quotes for JSON and
// not for a shell: inside double quotes a shell still reads $, a
// backtick and a backslash, so a name holding $(...) ran it.
//
// The lookup hands back patterns now and the caller passes them as
// arguments. This runs a real shell to say so, because the whole point
// is what a shell does with them and no amount of reading proves that.
{
    const fs = require("fs");
    const os = require("os");
    const path = require("path");
    const { execFileSync } = require("child_process");

    // All lowercase on purpose: the candidates are lowercased on the
    // way through, and a path with a capital in it would end up
    // pointing somewhere else and prove nothing.
    const dir = path.join(os.tmpdir(), "shima-shell-" + process.pid);
    fs.mkdirSync(dir, { recursive: true });
    const proof = path.join(dir, "pwned");
    const nasty = "game$(touch " + proof + ")odd";

    const w = load("services/Windows.qml",
                   ["windowLookup", "candidatesFor"],
                   { Apps: { settingsId: "shima:settings",
                             settingsClass: "shima",
                             entryFor: () => ({ id: "x", name: nasty,
                                                startupClass: nasty }) } });
    w.launchers = [];
    const pats = w.windowLookup("x");

    is("the lookup hands back patterns rather than a script",
       Array.isArray(pats) && pats.length > 0, true);
    is("and the name is in them untouched, with nothing escaped",
       pats.some(p => p.indexOf(nasty.toLowerCase()) !== -1), true);

    // The way the shell is actually called: the script is fixed and
    // every pattern arrives as an argument.
    execFileSync("sh", ["-c",
        'wins=""; for p in "$@"; do [ -n "$wins" ] && break; ' +
        'wins=$(printf "%s" "$p"); done',
        "shima"].concat(pats), { stdio: "ignore" });
    is("a name that would run a command does not run it", fs.existsSync(proof), false);

    // And the other way round, to be sure the proof means anything:
    // the same name written into the script the old way does run.
    try {
        execFileSync("sh", ["-c", 'wins=$(printf "%s" "' + pats[0] + '")'],
                     { stdio: "ignore" });
    } catch (e) { /* the shell may complain; the file is the answer */ }
    is("while writing it into the script would have", fs.existsSync(proof), true);

    fs.rmSync(dir, { recursive: true, force: true });
}

// ── No IPC function named after the tool's own words ─────────────
//
// `qs ipc` keeps five words for its own subcommands, and a handler
// function named after one of them cannot be reached: asking for
// `launcher show` printed the list of targets and opened nothing. It
// went unnoticed because nothing here called it — the shortcut helper
// asks for `toggle` — so the first person to find it would have been
// somebody typing it by hand and concluding the shell was broken.
{
    const fs = require("fs");
    const path = require("path");
    const { root } = require("./extract.js");

    // show, call, wait, listen, prop — read off `qs ipc --help`.
    const taken = ["show", "call", "wait", "listen", "prop"];

    const found = [];
    const walk = (dir) => {
        for (const name of fs.readdirSync(dir)) {
            const full = path.join(dir, name);
            if (fs.statSync(full).isDirectory()) {
                if (name !== "node_modules" && name !== ".git") walk(full);
                continue;
            }
            if (!name.endsWith(".qml")) continue;
            const text = fs.readFileSync(full, "utf8");
            let at = text.indexOf("IpcHandler");
            while (at >= 0) {
                // From the handler's opening brace to the one that
                // closes it, counting the way the extractor does.
                let depth = 0, seen = false, end = at;
                for (let i = at; i < text.length; i++) {
                    const c = text[i];
                    if (c === "{") { depth++; seen = true; }
                    else if (c === "}") {
                        depth--;
                        if (seen && depth === 0) { end = i; break; }
                    }
                }
                const body = text.slice(at, end);
                for (const m of body.matchAll(/function\s+([A-Za-z_$][\w$]*)\s*\(/g))
                    found.push([path.relative(root, full), m[1]]);
                at = text.indexOf("IpcHandler", end);
            }
        }
    };
    walk(root);

    is("the shell exposes IPC functions at all", found.length > 0, true);
    is("and none of them is named after a subcommand of the tool",
       found.filter(([, name]) => taken.indexOf(name) !== -1), []);
}

// ── Keys spelled the way KDE spells them ─────────────────────────
//
// Whether a combination is already taken is decided by looking its
// text up among the ones KDE has written in kglobalshortcutsrc. So the
// spelling is not cosmetic: `Ctrl+Alt+Delete` never found the
// `Ctrl+Alt+Del` sitting in that file, and the warning that the key
// belongs to somebody else never came. The names below were read out
// of a real one.
{
    const Qt = {
        Key_Escape: 0x01000000, Key_Tab: 0x01000001,
        Key_Backspace: 0x01000003, Key_Return: 0x01000004,
        Key_Enter: 0x01000005, Key_Insert: 0x01000006,
        Key_Delete: 0x01000007, Key_Home: 0x01000010,
        Key_End: 0x01000011, Key_Left: 0x01000012, Key_Up: 0x01000013,
        Key_Right: 0x01000014, Key_Down: 0x01000015,
        Key_PageUp: 0x01000016, Key_PageDown: 0x01000017,
        Key_Space: 0x20, Key_F1: 0x01000030, Key_F35: 0x01000052
    };
    const c = load("components/Controls.qml", ["nameOf"], { Qt: Qt });

    const asKde = [
        [Qt.Key_Delete, "Del"], [Qt.Key_Escape, "Esc"],
        [Qt.Key_PageUp, "PgUp"], [Qt.Key_PageDown, "PgDown"],
        [Qt.Key_Return, "Return"], [Qt.Key_Enter, "Return"],
        [Qt.Key_Insert, "Ins"]
    ];
    for (const [key, want] of asKde)
        is("the key KDE calls " + want + " is called that here",
           c.nameOf(key, ""), want);

    // The ones that were already right, so that fixing the others did
    // not quietly change them.
    const unchanged = [
        [Qt.Key_Space, "Space"], [Qt.Key_Tab, "Tab"],
        [Qt.Key_Backspace, "Backspace"], [Qt.Key_Home, "Home"],
        [Qt.Key_End, "End"], [Qt.Key_Up, "Up"], [Qt.Key_Down, "Down"],
        [Qt.Key_Left, "Left"], [Qt.Key_Right, "Right"]
    ];
    for (const [key, want] of unchanged)
        is(want + " is still " + want, c.nameOf(key, ""), want);

    is("the function keys count from one", c.nameOf(Qt.Key_F1, ""), "F1");
    is("and keep counting", c.nameOf(Qt.Key_F1 + 11, ""), "F12");
    is("a letter is a capital letter", c.nameOf(0x61, "a"), "A");
    is("and anything else falls back to what was typed",
       c.nameOf(0x01ffffff, "ñ"), "\u00d1");
}

// ── Text from somebody else's machine ────────────────────────────
//
// A Text honours a newline even with elide on, so one inside a track
// title takes two lines in a panel that has room for one and pushes
// the transport out of it. Real data from an Android phone over KDE
// Connect, which is where this was found.
{
    const m = load("components/MediaMode.qml", ["oneLine"], {});

    is("a newline in the middle is flattened",
       m.oneLine("BEJO\n Sume Beats"), "BEJO Sume Beats");
    is("and so are tabs and runs of spaces",
       m.oneLine("Aphex\t\tTwin   \u2014   Xtal"), "Aphex Twin \u2014 Xtal");
    is("the edges are trimmed", m.oneLine("  Boards of Canada \n"),
       "Boards of Canada");
    is("nothing stays nothing", m.oneLine(""), "");
    is("and neither undefined nor null becomes the word for it",
       [m.oneLine(undefined), m.oneLine(null)], ["", ""]);
}

// ── A capture marker nobody cleaned up ───────────────────────────
//
// While the settings window waits for a key the shell writes a marker
// and the helper takes both shortcuts out of KDE's hands, so they can
// be typed into the box instead of firing. Only the shell removed it,
// so a shell that died with the box open left Meta and Meta+V
// unregistered for the rest of the session, with nothing on screen to
// explain it.
//
// The shell touches the marker every twenty seconds now and the helper
// stops believing one that has not been touched for a minute. Run
// against the helper itself, because the rule lives there.
{
    const fs = require("fs");
    const os = require("os");
    const path = require("path");
    const { execFileSync, spawnSync } = require("child_process");
    const { root } = require("./extract.js");

    const python = spawnSync("python3", ["-c", ""]);
    if (python.error) {
        console.log("  (no python3 here, so the capture marker is not exercised)");
    } else {
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), "shima-cap-"));
        const probe = path.join(dir, "probe.py");
        fs.writeFileSync(probe, [
            "import importlib.machinery, importlib.util, os, sys, time",
            "os.environ['SHIMA_RUNTIME_DIR'] = sys.argv[1]",
            "sys.argv = ['shima-shortcuts']",
            "loader = importlib.machinery.SourceFileLoader('h', sys.argv[0])",
            "spec = importlib.util.spec_from_loader('h', importlib.machinery",
            "       .SourceFileLoader('h', " + JSON.stringify(
                path.join(root, "helper/shima-shortcuts")) + "))",
            "h = importlib.util.module_from_spec(spec)",
            "spec.loader.exec_module(h)",
            "open(h.CAPTURING, 'w').close()",
            "print('fresh', h.capturing())",
            "os.utime(h.CAPTURING, (time.time() - 30,) * 2)",
            "print('recent', h.capturing())",
            "os.utime(h.CAPTURING, (time.time() - 90,) * 2)",
            "print('stale', h.capturing())",
            "print('swept', not os.path.exists(h.CAPTURING))",
            "print('gone', h.capturing())",
        ].join("\n"));

        let out = "";
        try {
            out = execFileSync("python3", [probe, dir], { encoding: "utf8" });
        } catch (e) {
            out = "failed: " + (e.stderr || e.message);
        }
        const said = {};
        for (const line of out.trim().split("\n")) {
            const [k, v] = line.split(" ");
            said[k] = v;
        }

        is("a marker just written is believed", said.fresh, "True");
        is("and one touched half a minute ago still is", said.recent, "True");
        is("one nobody has touched for a minute is not", said.stale, "False");
        is("and it is taken away rather than left to puzzle the next reader",
           said.swept, "True");
        is("no marker at all is not capturing", said.gone, "False");

        fs.rmSync(dir, { recursive: true, force: true });
    }
}

// ── Every .qml file still parses ─────────────────────────────────
//
// Everything else here pulls one function out of a file and runs it,
// which says nothing about whether the file as a whole is still valid
// QML. That gap bit on 27 September: an edit left a string unclosed,
// the suite passed 209 green, and the only thing that noticed was the
// running shell refusing to reload — with the old configuration still
// up, so nothing looked wrong until somebody read the log.
//
// qmllint answers 255 for a file it cannot parse and 0 for one it can,
// warnings and all, and it warns plenty about Quickshell's own types
// because they are not on its import path. So the exit code is the
// question and the output is not.
{
    const fs = require("fs");
    const path = require("path");
    const { execFileSync, spawnSync } = require("child_process");
    const { root } = require("./extract.js");

    const have = spawnSync("qmllint", ["--help"], { stdio: "ignore" });
    if (have.error) {
        console.log("  (no qmllint here, so the .qml files are not parsed)");
    } else {
        const files = [];
        const walk = (dir) => {
            for (const name of fs.readdirSync(dir)) {
                if (name === "node_modules" || name === ".git") continue;
                const full = path.join(dir, name);
                if (fs.statSync(full).isDirectory()) walk(full);
                else if (name.endsWith(".qml")) files.push(full);
            }
        };
        walk(root);

        const broken = files.filter(f =>
            spawnSync("qmllint", [f], { stdio: "ignore" }).status !== 0)
            .map(f => path.relative(root, f));

        is("there are .qml files to check", files.length > 0, true);
        is("and every one of them parses", broken, []);
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
