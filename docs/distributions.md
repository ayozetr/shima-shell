# Where Shima has been tried

Shima needs KDE Plasma 6 on Wayland, and nothing else. This page is a
record of the distributions it has actually been installed and used on,
not a list of requirements — if yours is missing it will very probably
work all the same.

| Distribution | How it goes |
|---|---|
| **Arch · CachyOS** and derivatives | Everything works, blur included. In the AUR as `shima-shell`. |
| **Fedora KDE 44** | Everything works, blur included. The installer offers you the COPR that carries Quickshell. |
| **openSUSE Tumbleweed** | Everything works, blur included. The installer prints the two lines that add the repository and stops there, for you to run them. |
| **Kubuntu · Ubuntu 26.04** | Everything works except blur, which its Plasma is too old for. The installer offers you the PPA that carries Quickshell. |
| **NixOS 26.05** | Everything works except blur, same reason. See the note below on declaring it. |
| **Debian 13 (trixie)** | Everything works except the settings window, which takes the shell down when it opens. Set things by hand meanwhile — every option is in [settings.md](settings.md). |
| **KDE Neon** | Nobody builds Quickshell for its base (Ubuntu 24.04), so you have to build it yourself first. With that done, everything works, blur included. |

## What it needs

| | Version |
|---|---|
| **KDE Plasma** | 6, on Wayland |
| **Qt** | 6.10 |
| **Quickshell** | 0.3.0 |
| **kdotool** | 0.2.3 |
| **Plasma, for the blur** | 6.7 |

And these, which your distribution almost certainly has:

| | For |
|---|---|
| **python3** with **PyGObject** | the global shortcut, which is a program of its own: Quickshell cannot own a name on D-Bus and KDE hands shortcuts out over one |
| **wl-clipboard** | the clipboard history, and the launcher's copy button. Wayland offers no other way in |
| **sqlite3** | reading what KDE has open and had open recently |
| **xdg-utils** | opening a file or a folder with whatever handles it |
| **curl** | the weather, and fetching kdotool on the way in |

Optional, and each one turns off exactly one thing: **cava** for the
audio visualiser, **fd** for faster file search in the launcher,
**libnotify** for sending yourself a test notification.

The installer works all of this out, asks before installing anything,
and tells you what it skipped.

## Blur needs Plasma 6.7

The background behind the dock, the island and the launcher is blurred
through a Wayland protocol that arrived in Plasma 6.7. On anything
older the panels are drawn solid instead and Shima says so once in its
log. Nothing else changes, and nothing is lost by having it off — the
default look has blur turned off anyway.

This is about the version of Plasma and not about the distribution.
Fedora went from no blur to blur on its own, just by updating.

## Debian, and why

The settings window is built out of Qt, and Debian 13 carries Qt 6.8,
where building it crashes. The same window opens fine on Qt 6.11 with
the very same version of Quickshell, so it is Qt and not us — and
Debian freezes Qt until Debian 14. Until then, the shell itself runs
perfectly there; it is only that one window you cannot open.

## Notifications, if Plasma got there first

Whoever asks for the notification service first keeps it, and Plasma
asks too. Which of the two wins varies from machine to machine: on some
Shima serves your notifications, on others they keep going to Plasma
and Shima's notification centre stays empty.

Removing Plasma's panels does not settle it — `plasmashell` holds the
service whether it is showing a panel or not. Stopping `plasmashell`
hands it to Shima straight away.

## Tray icons from Windows programs

A program running under Wine or Proton — Ubisoft Connect, the EA app,
Battle.net — does not put its icon in the tray itself. Wine's own
`explorer.exe` does, the old X11 way, and KDE bridges that across. There
is no menu published anywhere in that chain, so a right click has to be
passed back down it for the program to draw its own.

Shima does that, and it mostly works. Two things to expect: the menu
appears where Wine decides to put it, which is not necessarily beside
the dock, and the first click sometimes shows the program's name
instead of its menu. Clicking again brings the menu up. Both happen
inside Wine, below anything Shima can reach.

## NixOS

Declare Quickshell and kdotool in your configuration rather than
letting the installer fetch them, so they survive the next rebuild:

```nix
environment.systemPackages = with pkgs; [ quickshell kdotool ];
```

Shima itself installs into `~/.local` like everywhere else.
