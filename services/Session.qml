pragma Singleton
import Quickshell
import org.kde.plasma.private.sessions

// Power and session actions, through the very object Plasma's own menu
// uses.
//
// This used to call org.kde.Shutdown over gdbus. That name is D-Bus
// activated, so the call started plasma-shutdown and left it resident
// when the shutdown did not go through. From then on
// ksmserver-logout-greeter — the confirmation dialog — could not claim
// the name and quit on sight, so pressing shut down did nothing at all,
// in Shima *and* in Plasma's own menu, until that stray process was
// killed. It happened here: twelve hours of a machine that would not
// turn off.
//
// SessionManagement does not make that impossible, and it is worth
// being precise about why: it lives in libkworkspace, which talks to
// org.kde.Shutdown as well. What it does is take the same road as the
// panel, with confirmation left at whatever KDE is set to — and the
// default goes through org.kde.LogoutPrompt, which claims the name and
// gives it back when the dialog closes. So Shima can no longer break
// the session's shutdown on its own; at worst it fails exactly where
// Plasma's own menu fails.
//
// It also says what the machine can do, which shelling out never told
// us: hibernation is unavailable on plenty of setups, and the entry
// for it was there anyway.
Singleton {
    id: root

    SessionManagement { id: session }

    // These arrive asynchronously — logind is asked once the object is
    // built — so they read false for the first second or so. Bind to
    // them rather than reading them once.
    readonly property bool canShutdown:   session.canShutdown
    readonly property bool canReboot:     session.canReboot
    readonly property bool canLogout:     session.canLogout
    readonly property bool canSuspend:    session.canSuspend
    readonly property bool canHibernate:  session.canHibernate
    readonly property bool canSwitchUser: session.canSwitchUser
    readonly property bool canLock:       session.canLock

    // ── Power ──────────────────────────────────────────────────
    //
    // No confirmation is asked for here: these follow whatever KDE is
    // set to do, which is what somebody who has already picked "shut
    // down" in a menu expects.
    function shutdown()  { session.requestShutdown(); }
    function reboot()    { session.requestReboot(); }
    function suspend()   { session.suspend(); }
    function hibernate() { session.hibernate(); }

    // ── Session ────────────────────────────────────────────────
    function lock()       { session.lock(); }
    function logout()     { session.requestLogout(); }
    function switchUser() { session.switchUser(); }
}
