# When something does not work

Everything here has actually happened, on a real machine, and most of
it is not a fault: it is Shima meeting a desktop that does things
differently. Each answer says what to do and, where it matters, why
nothing can be done.

## Where is the log?

Shima writes to the session journal under the name of its launcher:

```bash
journalctl --user -f | grep shima
```

The first run says three or four things about files that do not exist.
Those are gone as of 0.5.0 — a first run has no settings file because
nothing has written one yet, and saying so read like a fault.

## Nothing is blurred behind the dock

Your Plasma is older than 6.7. The blur goes through a Wayland
protocol that arrived in that version, and below it the panels are
drawn solid instead. Shima says so once in the log:

```
Cannot enable background effect as ext-background-effect-v1 is not
supported by the current compositor.
```

Nothing is lost by having it off — the default look has it off anyway,
because translucency without blur is a different effect and not a
dimmer version of the same one. And this is about the version of
Plasma, not about your distribution: Fedora went from one to the other
on its own, just by updating.

## My notifications still come from Plasma

Whoever asks for the notification service first keeps it, and Plasma
asks too. Which of you wins varies from machine to machine — on some
Shima serves them and its centre fills up, on others they keep going
to Plasma and Shima's stays empty.

Removing Plasma's panels does not settle it: `plasmashell` holds the
service whether it is showing a panel or not. Stopping it hands the
service over at once:

```bash
systemctl --user stop plasma-plasmashell
```

That is a real answer only if you were going to stop using Plasma's
own shell anyway. Otherwise it is worth knowing rather than worth
doing.

## Right clicking a tray icon does nothing

If it is a Windows program under Wine — Ubisoft Connect, the EA app,
Battle.net — its menu now opens, as of the version after 0.5.0. Two
things to expect, and neither is fixable from here: the menu appears
where Wine decides to put it, which is not necessarily beside the
dock, and the first click sometimes shows the program's name instead
of the menu. Clicking again brings the menu up.

If it is an ordinary program and nothing happens at all, that is worth
reporting.

## Meta stopped opening the launcher

Two things take the key away, and both give it back.

The settings window takes it while it waits for you to press a new
combination — otherwise pressing Meta would open the launcher instead
of being typed into the box. If the shell dies right then the key used
to stay gone for the rest of the session; as of the version after
0.5.0 it comes back on its own within a minute.

The other is another program holding the same combination. Shima
borrows it and hands it back when you change or uninstall it, and the
settings page says whose it was.

If it is neither, the helper that owns the shortcut may not be
running:

```bash
pgrep -af shima-shortcuts
```

It starts with the shell, so restarting Shima starts it again.

## The settings window closes the whole shell

You are on Debian 13, or on something else carrying Qt 6.8. The window
is built out of Qt and that version crashes while building it; the
same window opens on Qt 6.10 and 6.11 with the very same Quickshell,
so it is Qt and not the shell. Debian freezes Qt until Debian 14.

Everything is settable by hand meanwhile, and every option is written
down in [settings.md](settings.md).

## An application is open but not in the dock

The dock knows what is open by asking KWin for the window and matching
it against the desktop files installed. Two shapes are known to go
wrong, and both are handled as of 0.5.0:

- A window that announces itself in reverse domain form while its
  desktop file gives the short name.
- A game you dragged into Steam yourself, which has no desktop file
  and no manifest of its own.

If yours is neither, what the window calls itself is the place to
start:

```bash
kdotool search --class '.*' | while read w; do kdotool getwindowclassname "$w"; done
```

## It does not start at all

Run the launcher from a terminal and read what it says:

```bash
shima
```

It tells a crash from a stop: a shell that crashes is started again, a
shell you stopped stays stopped. If it keeps crashing, the line before
the last is usually the one that matters.

## How do I get rid of it?

```bash
shima --cleanup     # hands the Meta key back to Plasma first
```

Then remove it the way it went in — `paru -R shima-shell`, or the
installer with `--uninstall`. Add `--purge` to that last one to take
your settings with it.
