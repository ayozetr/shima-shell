# Brand files

Everything drawn for Shima, including what is not in use. Kept because
the work is done and redrawing it later costs more than the 200 KB it
takes up here.

Only SVG. The PNGs are derived and regenerate in a second:

```bash
rsvg-convert -w 1024 icon/96-ring10-medium.svg -o out.png
```

## What is actually used

| File | Where it ends up |
|---|---|
| `../../packaging/shima.svg` | `/usr/share/icons/hicolor/scalable/apps/` |
| `../../packaging/shima-16.svg` | `.../16x16/apps/` |
| `../../packaging/shima-22.svg` | `.../22x22/apps/` |
| `../../packaging/shima-symbolic.svg` | `.../symbolic/apps/` |
| `../logo.svg` | the README header |
| `../logo-horizontal.svg` | anywhere narrow |

The application icon is `icon/96-ring10-medium.svg`; the header is
`logo/121-symbol-kanji.svg`.

## icon/

A mountain above water: what the character 島 depicted before the water
was replaced by 鳥 (bird) for its sound. It reads as an island without
knowing any Japanese, which the kanji does not.

- `81`–`86` — different compositions of the same idea
- `91`–`96` — the one that won, by ring thickness and how much the sea
  moves. `96` has the largest wave that still survives being shrunk
- `84`, `85` — no disc. `85` is the tray icon; `84` is not usable as an
  application icon (see below)

## logo/

- `101`–`106` — the kanji on its own, black on transparent
- `121`–`126` — the kanji **and** the island, both inside the same black
  disc as the application icon, so the two are family. `123`/`124` add
  the name below, `125`/`126` set it beside

## Three things worth knowing before editing these

**The white ring is not decoration.** An application icon is a single
fixed file — unlike symbolic icons, the system does not recolour it for
light and dark themes. A black disc vanishes against a dark panel. The
white ring outside it is invisible on a light background and draws the
outline on a dark one, so one file works everywhere. `84-ring` has no
disc to put a ring on, which is why it cannot be the application icon.

**No `clipPath`, no masks, no filters.** Qt SVG ignores them, and Qt is
what draws icons in Plasma and thumbnails in Dolphin. An earlier version
clipped the sea against the circle: it looked right in a browser and
spilled outside the disc on the desktop. The sea's lower edge is the
circle's arc, worked out as geometry instead.

**Text is converted to paths.** Nothing here needs Open Sans or Noto
Sans CJK installed. Edit the text and it has to be converted again:

```bash
inkscape in.svg --actions="select-all;object-to-path;export-filename:out.svg;export-plain-svg;export-do"
```

## Licence

Drawn from scratch: no path comes from a generator or from anyone
else's file.

Not covered by the GPL. All rights reserved by the author. Usable in
forks made to contribute back to this project — see
[CONTRIBUTING](../../CONTRIBUTING.md) — but not in an independent one.
