# Shima Shell

Dynamic island and dock for KDE Plasma on Wayland.

An island anchored to the top edge showing media, time and volume, and a
dock growing from the bottom edge. Written in QML on top of
[Quickshell](https://quickshell.org), using `wlr-layer-shell` and the
system's native services.

## What it does

**Island.** Collapsed it shows an audio visualiser, the clock and the
album art. Hovering expands it into one of four modes, switched with the
scroll wheel or by clicking the dots:

- **Media** — album art, track, transport controls and volume
- **Control centre** — Wi-Fi, Bluetooth, mute and volume
- **Status** — CPU, memory and network throughput
- **Calendar** — month view with a pomodoro timer

**Dock.** Pinned apps inherited from your Plasma task manager, plus the
apps you currently have open, separated by a divider. Drag to reorder,
right click to pin or unpin, and an optional launcher button opening a
categorised application grid with search.

**Settings.** Right click the dock. Position, auto-hide, opacity,
background blur, corner radius, icon shape and size, accent colour, and
per-monitor placement of the island and the dock. Everything applies
live.

## How it works

| Feature | Source |
|---|---|
| Media, album art, controls | MPRIS2 over D-Bus |
| Audio visualiser | `cava` reading the PipeWire monitor |
| Volume | PipeWire |
| Placement and layering | `zwlr_layer_shell_v1` |
| Background blur | `ext_background_effect_manager_v1` |
| Applications and icons | `.desktop` files and the XDG icon theme |
| Open windows | KWin scripting, through `kdotool` |

## Requirements

```bash
sudo pacman -S quickshell cava
paru -S kdotool-bin
```

Plasma 6 on a Wayland session.

`kdotool` is optional but strongly recommended. Without it, open windows
are guessed from the process list, which lights up false positives (a
`dolphin --daemon` with no window, for instance) and clicking a running
app launches another instance instead of raising its window.

## Running

```bash
./shima
```

The launcher keeps the icon theme pragma in sync with your Plasma theme
and refuses to start a second instance.

## A Wayland limitation

KWin exposes neither `zwlr_foreign_toplevel_manager_v1` nor
`org_kde_plasma_window_management`, so **no external application can
enumerate open windows**. `kdotool` works around this by going through
KWin's scripting API, which is why it matters so much here.

## Status

- [x] Island with four modes
- [x] Dock with reordering, running apps and context menu
- [x] Application launcher with categories and search
- [x] Live settings, including per-monitor placement
- [ ] Autostart on login
- [ ] Notifications

## Origin

Shima Shell is an independent project, unaffiliated with the Bloom
project or its authors, but it started out inspired by
[Bloom](https://github.com/SehajveerSingh2005/bloom), which does
something similar on Windows. The code is its own: Bloom is a Tauri
application with a Rust backend written against the Windows APIs, which
have no direct equivalent on Wayland.

## License

Copyright (C) 2026 ayozetr

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License, version 3, as
published by the Free Software Foundation.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
[GNU General Public License](LICENSE) for more details.
