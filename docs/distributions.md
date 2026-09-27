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

## NixOS

Declare Quickshell and kdotool in your configuration rather than
letting the installer fetch them, so they survive the next rebuild:

```nix
environment.systemPackages = with pkgs; [ quickshell kdotool ];
```

Shima itself installs into `~/.local` like everywhere else.
