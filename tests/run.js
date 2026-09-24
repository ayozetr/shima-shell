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
