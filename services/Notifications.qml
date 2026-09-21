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

    readonly property int historyLimit: Config.data.notificationHistory ?? 50
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
            if (next.length > root.historyLimit) next.length = root.historyLimit;
            root.items = next;
        }

        // Some notifications are not a passing remark. One that came
        // in shouting, or that offers a choice, is shown as a card
        // that waits instead of a glance that expires.
        if (root.quiet) {
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
        for (const c of root.cards) if (c.key !== key) next.push(c);
        root.cards = next;
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

    function dismissPeek() {
        root.peek = null;
    }

    // How long the island holds a notification up. The sender's own
    // timeout is honoured when it asked for one, within reason: some
    // ask for half a second and others for forever.
    function peekSeconds(entry) {
        const n = root.live(entry.id);
        const asked = n ? n.expireTimeout : -1;
        if (asked > 0) return Math.max(2.5, Math.min(10, asked / 1000));
        return Config.data.notificationPeekSeconds ?? 5;
    }

    // ── Relative time ────────────────────────────────────────────
    //
    // Nothing tells a text binding that a minute has passed, so a tick
    // does: reading it here is what makes "now" become "5 min ago"
    // without anything else changing.
    property int tick: 0

    Timer {
        interval: 30000
        running: true
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
