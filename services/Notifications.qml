pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The desktop's notification server.
//
// Only one process can own org.freedesktop.Notifications, and on a
// stock Plasma session that is plasmashell. Registering while it holds
// the name simply fails, and Quickshell keeps watching and takes over
// the moment it is released — so this can sit here harmlessly until
// the Plasma applet is removed, and needs no coordination.
Singleton {
    id: root

    readonly property bool enabled: Config.data.notificationsEnabled ?? true

    // Nothing on screen, everything in the history. Silencing that
    // dropped them would make the island's list a worse version of
    // itself — the point of not disturbing you is reading them later.
    property bool quiet: Config.data.doNotDisturb ?? false

    // Do not disturb, plus a focus session that asked for quiet. The
    // switch for that used to ask the notification server to inhibit
    // itself over D-Bus, which on a session where Shima is the server
    // means asking nobody: it is read here instead.
    readonly property bool holding: root.quiet || Focus.hushing

    function toggleQuiet() {
        Config.data.doNotDisturb = !root.quiet;
        Config.save();
    }

    // ── History ──────────────────────────────────────────────────
    //
    // Entries are plain objects, not the Notification objects. Those
    // die when the sending application closes them, and a history that
    // empties itself behind your back is not a history. The live
    // object is looked up by id when it is needed, and its absence is
    // exactly what says the notification is gone.
    property var items: []
    property int serial: 0

    // ── The history across a restart ─────────────────────────────
    //
    // It used to go with the shell, which is a poor answer to "what
    // was that, I clicked it away": a hot reload while you work throws
    // it away, and so does a crash.
    //
    // It is kept in the runtime directory and not next to the
    // settings, which is a decision and not an accident. A
    // notification is the subject of your mail, the message somebody
    // sent you and the code your bank texted, and a file of those on
    // the disk outlives everything you would expect it to. The runtime
    // directory is memory with a path — the system empties it when the
    // session ends — so this survives the shell restarting and does
    // not survive you logging out.
    readonly property string historyPath: Paths.runtimeDir + "/notifications.json"

    FileView {
        id: historyFile
        path: root.historyPath
        // The runtime directory is empty at the start of every
        // session, so the first read of this always fails and used to
        // put a warning in the log for it. Nothing is wrong: there is
        // no history yet because there has been no session yet. The
        // reading is done below, where a missing file is an answer and
        // anything else is worth saying out loud.
        printErrors: false
        onLoaded: {
            if (root.restored) return;
            root.restored = true;
            try {
                const saved = JSON.parse(text());
                if (!Array.isArray(saved)) return;
                const out = [];
                for (const e of saved) {
                    if (!e || typeof e !== "object") continue;
                    // Nothing that came back can be acted on: the
                    // application that sent it is not waiting any
                    // more. Read, so the island does not announce a
                    // pile of unread from before.
                    e.read = true;
                    e.actions = [];
                    e.actionCount = 0;
                    e.buttons = 0;
                    // A picture the application sent along is held by
                    // the shell as "image://qsimage/23/1", a number
                    // handed out in order as the images arrive. The
                    // count starts again with the shell, so that
                    // address does not merely stop resolving: it comes
                    // back pointing at somebody else's picture, and an
                    // old message from one person would be wearing the
                    // face of whoever wrote next. The application's
                    // own icon is underneath it and is what shows.
                    e.image = "";
                    out.push(e);
                    if (out.length >= root.historyLimit) break;
                }
                root.items = out;
                for (const e of out) if (e.key > root.serial) root.serial = e.key;
            } catch (e) { /* half-written by a shell that was killed */ }
        }
        onLoadFailed: (error) => {
            root.restored = true;
            if (error !== FileViewError.FileNotFound)
                console.warn("[shima] the notification history at "
                           + root.historyPath + " could not be read");
        }
    }

    property bool restored: false

    // Written after things have stopped moving rather than on every
    // notification: a burst of five would otherwise be five writes.
    Timer {
        id: saveHistory
        interval: 1200
        onTriggered: {
            if (!root.restored) return;
            historyFile.setText(JSON.stringify(root.items));
        }
    }

    onItemsChanged: if (root.restored) saveHistory.restart()

    readonly property int historyLimit:
        Config.number(Config.data.notificationHistory, 50, 1, 500)
    readonly property int unread: {
        let n = 0;
        for (const it of root.items) if (!it.read) n++;
        return n;
    }

    // What the island should show right now, or null.
    property var peek: null

    signal arrived(var entry)

    NotificationServer {
        id: server

        // Reloading the shell should not wipe what is on screen.
        keepOnReload: true

        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true

        onNotification: (n) => root.receive(n)
    }

    function receive(n) {
        if (!root.enabled) return;

        // Without this the object is destroyed as soon as it has been
        // handed over, taking its actions with it.
        n.tracked = true;

        // Actions are copied rather than kept by reference: the card
        // has to keep drawing its buttons after the sender has closed
        // the notification, and invoking goes through the live object
        // looked up by id, which is what says whether it still works.
        const actions = [];
        if (n.actions) {
            for (let i = 0; i < n.actions.length; i++) {
                actions.push({
                    index: i,
                    text: n.actions[i].text || "",
                    // By convention this one is what a click on the
                    // notification body runs, not a button of its own.
                    isDefault: n.actions[i].identifier === "default"
                });
            }
        }

        const app = Apps.matchApp(n.desktopEntry || "", n.appName || "");

        const entry = {
            key: ++root.serial,
            id: n.id,
            appName: n.appName || "",
            summary: n.summary || "",
            body: n.body || "",
            // Cleaned once here rather than in the bindings that draw
            // it: the list re-evaluates on every change, and running
            // two regular expressions per visible notification each
            // time adds up for a value that never changes.
            //   bodyText  — no markup at all, for the island and the peek
            //   bodyRich  — markup kept, images dropped, for the card
            bodyText: (n.body || "").replace(/<[^>]*>/g, "")
                                    .replace(/\s+/g, " ").trim(),
            bodyRich: (n.body || "").replace(/<img[^>]*>/g, ""),
            // The application's own icon beats the one it sent, which
            // is often a generic "information" glyph.
            icon: (app && app.icon) ? app.icon : (n.appIcon || ""),
            image: n.image || "",
            desktopEntry: n.desktopEntry || "",
            urgency: n.urgency,
            transient: n.transient === true,
            actions: actions,
            actionCount: actions.length,
            // Only the ones that become buttons; the default action is
            // what a plain click runs.
            buttons: actions.filter(a => !a.isDefault).length,
            time: Date.now(),
            read: false
        };

        // Transient ones are progress bars and volume popups: worth a
        // glance, not worth keeping.
        if (!entry.transient) {
            const next = [entry].concat(root.items);
            // Whatever falls off the end is gone from the history, so
            // it has to be let go of as well.
            const dropped = next.slice(root.historyLimit);
            if (next.length > root.historyLimit) next.length = root.historyLimit;
            root.items = next;
            for (const d of dropped) root.releaseIfGone(d);
        }

        // Some notifications are not a passing remark. One that came
        // in shouting, or that offers a choice, is shown as a card
        // that waits instead of a glance that expires.
        // The alarm that says the session is over is the session's
        // own, and the one thing a focus session must not silence.
        const mine = entry.appName === "Shima";
        if (root.quiet || (Focus.hushing && !mine)) {
            // Straight to the history, and the unread mark on the
            // island is the only sign.
        } else if (root.cardsEnabled && root.deservesCard(entry)) {
            root.cards = root.cards.concat([entry]);
        } else {
            root.peek = entry;
        }

        root.arrived(entry);
    }

    // ── Cards ────────────────────────────────────────────────────
    readonly property bool cardsEnabled: Config.data.notificationCards ?? true
    property var cards: []

    function deservesCard(entry) {
        if (entry.urgency === 2) return true;     // critical
        return entry.buttons > 0;
    }

    function closeCard(key) {
        const next = [];
        let gone = null;
        for (const c of root.cards) {
            if (c.key === key) gone = c; else next.push(c);
        }
        root.cards = next;
        root.releaseIfGone(gone);
    }

    function buttonsOf(entry) {
        const out = [];
        for (const a of entry.actions) if (!a.isDefault) out.push(a);
        return out;
    }

    // ── Reaching the live notification ───────────────────────────
    function live(id) {
        const all = server.trackedNotifications;
        if (!all) return null;
        for (const n of all.values) if (n.id === id) return n;
        return null;
    }

    function actionsFor(id) {
        const n = root.live(id);
        return (n && n.actions) ? n.actions : [];
    }

    function invoke(id, index) {
        const acts = root.actionsFor(id);
        if (index >= 0 && index < acts.length) acts[index].invoke();
    }

    // ── History housekeeping ─────────────────────────────────────
    function markRead(key) {
        const next = [];
        for (const it of root.items)
            next.push(it.key === key ? Object.assign({}, it, { read: true }) : it);
        root.items = next;
    }

    function markAllRead() {
        const next = [];
        for (const it of root.items) next.push(Object.assign({}, it, { read: true }));
        root.items = next;
    }

    function remove(key) {
        const next = [];
        for (const it of root.items) {
            if (it.key === key) {
                const n = root.live(it.id);
                if (n) n.dismiss();
            } else {
                next.push(it);
            }
        }
        root.items = next;
        if (root.peek && root.peek.key === key) root.peek = null;
    }

    function clear() {
        for (const it of root.items) {
            const n = root.live(it.id);
            if (n) n.dismiss();
        }
        root.items = [];
        root.peek = null;
    }

    // Nothing lets go of a notification on its own: `tracked` is what
    // keeps Quickshell from destroying it, and it was set on every one
    // that arrived and cleared only by dismissing or clearing the
    // history. Two kinds never went through either — the transient
    // ones, which never enter the history, and the ones pushed off the
    // end of it — so on a desktop left running they piled up without
    // limit. This lets go once an entry is gone from everywhere it
    // could still be drawn.
    function releaseIfGone(entry) {
        if (!entry) return;
        for (const it of root.items) if (it.key === entry.key) return;
        for (const c of root.cards) if (c.key === entry.key) return;
        if (root.peek && root.peek.key === entry.key) return;
        const n = root.live(entry.id);
        if (n) n.dismiss();
    }

    function dismissPeek() {
        const gone = root.peek;
        root.peek = null;
        root.releaseIfGone(gone);
    }

    // How long the island holds a notification up. The sender's own
    // timeout is honoured when it asked for one, within reason: some
    // ask for half a second and others for forever.
    function peekSeconds(entry) {
        const n = root.live(entry.id);
        const asked = n ? n.expireTimeout : -1;
        if (asked > 0) return Math.max(2.5, Math.min(10, asked / 1000));
        return Config.number(Config.data.notificationPeekSeconds, 5, 1, 120);
    }

    // ── Relative time ────────────────────────────────────────────
    //
    // Nothing tells a text binding that a minute has passed, so a tick
    // does: reading it here is what makes "now" become "5 min ago"
    // without anything else changing.
    property int tick: 0

    // How many lists of notifications are on screen — there can be one
    // per island. The tick woke the process every thirty seconds
    // whatever was happening, and put every entry in the history
    // through the sum again, for labels that are only drawn in one
    // place and are almost never on screen.
    property int watchers: 0

    function watch(on) {
        root.watchers = Math.max(0, root.watchers + (on ? 1 : -1));
        // Coming back to a list the tick has not been running for: the
        // times on it are as old as whenever it stopped.
        if (on) root.tick++;
    }

    Timer {
        interval: 30000
        running: root.watchers > 0
        repeat: true
        onTriggered: root.tick++
    }

    function ago(time) {
        root.tick;
        const secs = Math.max(0, (Date.now() - time) / 1000);
        if (secs < 60) return I18n.t.justNow;
        const mins = Math.floor(secs / 60);
        if (mins < 60) return I18n.t.minutesAgo.replace("%1", mins);
        const hours = Math.floor(mins / 60);
        if (hours < 24) return I18n.t.hoursAgo.replace("%1", hours);
        return I18n.t.daysAgo.replace("%1", Math.floor(hours / 24));
    }
}
