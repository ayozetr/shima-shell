# The settings sidebar icons

Seven icons, one per page of the settings window, kept here instead of
asked from whatever icon theme the machine happens to have.

They used to be theme names — `configure`, `computer`, `view-grid` and
so on — and that made the sidebar look like a different window on every
machine. Breeze draws four of them as dark line glyphs meant for a
light window, so on this dark sidebar they came out nearly invisible;
Papirus, which inherits `breeze-dark`, drew the same names light and
looked right. Three others had no line version at all and arrived in
full colour, so the sidebar mixed an orange bell and a yellow sun with
four grey shadows. Naming files instead of themes is the only way the
window looks the same everywhere.

Each was picked by eye from the two themes, one page at a time:

| File | From | Upstream name |
|---|---|---|
| `general.svg` | Papirus | `16x16/actions/configure.svg` |
| `dock.svg` | Breeze | `devices/16/computer.svg` |
| `launcher.svg` | Papirus | `16x16/actions/view-grid.svg` |
| `island.svg` | Papirus | `16x16/actions/window.svg` |
| `notifications.svg` | Papirus | `16x16/panel/notifications.svg` |
| `weather.svg` | Breeze | `status/16/temperature-normal.svg` |
| `about.svg` | Papirus | `16x16/actions/help-about.svg` |

[Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
is GPL-3.0 and [Breeze](https://invent.kde.org/frameworks/breeze-icons)
is LGPL-3.0, both compatible with this project's own GPL-3.0. They stay
under their own licences, which the links above carry.

The only change is the fill: they ship `fill="currentColor"` against a
`.ColorScheme-Text` class, and Qt's SVG renderer resolves neither, so
the colour is written into the file as white. The sidebar then paints
over it anyway — white on the dark rows, dark on the accented one — so
what matters here is that the shape has a fill at all.
