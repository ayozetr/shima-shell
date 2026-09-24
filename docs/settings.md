# The settings file

Everything the settings window writes lives in one file:

```
~/.config/shima/config.json
```

It is meant to be opened. Editing it while Shima runs applies the
change straight away — the file is watched — and every value here can
be set by hand.

Two things happen to what you write. A number outside what it can
usefully be is pulled back to the nearest edge rather than used: the
bounds below are not taste, they are the point past which the shell
stops working, and an island nought pixels wide cannot be pointed at.
A colour that is not a colour falls back to its default. Anything that
is not valid JSON at all is left alone and a copy is kept beside it as
`config.json.bak`, so a half-finished edit does not cost you the rest.

Times are in milliseconds unless the name says otherwise.

## The dock

| Key | Default | What it is |
|---|---|---|
| `dockPosition` | `"bottom"` | `"bottom"` or `"top"` |
| `dockIconSize` | `56` | Icon size in pixels, 16 to 128. Everything else in the dock is a ratio of this |
| `dockOpacity` | `0.8` | 0 to 1 |
| `dockBlur` | `true` | Blur what is behind it |
| `dockFloating` | `false` | Lift it off the edge |
| `dockMargin` | `10` | How far off, when floating. 0 to 400 |
| `dockCornerRadius` | `28` | 0 to 80 |
| `dockMagnify` | `true` | Icons grow under the pointer |
| `dockAutoHide` | `false` | Hide it until the pointer reaches the edge |
| `dockHideDelay` | `700` | How long it waits before hiding, 100 to 60000 |
| `dockScreens` | `""` | Comma-separated screen names, or empty for all. A name that is not there any more is ignored rather than leaving you with no dock |
| `iconShape` | `"squircle"` | `"squircle"`, `"circle"` or `"square"` |
| `iconRadiusPct` | `33` | Corner radius as a percentage of the icon, 0 to 50. Only for `"squircle"` |
| `showRunning` | `true` | Show open applications that are not pinned |
| `showAppNames` | `true` | Names on hover |
| `showTray` | `true` | The system tray |
| `trayCollapsible` | `true` | Fold the tray behind a chevron |
| `showLauncher` | `true` | The launcher button |
| `launcherLift` | `0` | Raise the launcher panel above the dock, 0 to 1000 |

## The island

| Key | Default | What it is |
|---|---|---|
| `islandEnabled` | `true` | |
| `islandCollapsedWidth` | `410` | 120 to 2000 |
| `islandCollapsedHeight` | `38` | 16 to 400 |
| `islandExpandedWidth` | `425` | 160 to 2000 |
| `islandRadius` | `22` | 0 to 80 |
| `islandOpacity` | `1.0` | 0 to 1 |
| `islandBlur` | `false` | Pointless while it is opaque, which it is by default |
| `islandFloating` | `false` | Lift it off the edge |
| `islandMargin` | `8` | How far off, when floating. 0 to 400 |
| `islandAutoHide` | `false` | |
| `islandHideDelay` | `700` | 100 to 60000 |
| `islandScreens` | `""` | As `dockScreens` |
| `clock24` | `true` | 24-hour clock |

## The clipboard

| Key | Default | What it is |
|---|---|---|
| `clipboardHistory` | `true` | Keep what you copy. Needs `wl-clipboard` |
| `clipboardImages` | `true` | Pictures as well as text |
| `clipboardShortcutEnabled` | `true` | |
| `clipboardKey` | `268435542` | A Qt key code with its modifiers. `Meta+V` |
| `clipboardLabel` | `"Meta+V"` | What the settings window shows for that code |

Nothing here is written to disk: text is held in the shell and
pictures in the session's runtime directory, which the system empties
when you log out.

## Notifications

| Key | Default | What it is |
|---|---|---|
| `notificationsEnabled` | `true` | |
| `notificationPeekSeconds` | `5` | How long one sits in the island, 1 to 120. A sender asking for its own timeout is honoured within reason |
| `notificationCards` | `true` | Show the ones that ask for an answer as cards instead |
| `notificationCardSeconds` | `12` | 1 to 600 |
| `notificationHistory` | `50` | How many are kept, 1 to 500 |
| `doNotDisturb` | `false` | Everything goes to the history and nothing appears |

## The pomodoro

| Key | Default | What it is |
|---|---|---|
| `focusMinutes` | `25` | 1 to 600 |
| `breakMinutes` | `5` | 1 to 600 |
| `longBreakMinutes` | `15` | 1 to 600 |
| `focusRounds` | `4` | Sessions before a long break, 1 to 100 |
| `focusChain` | `true` | Start the next phase by itself |
| `focusNotify` | `true` | Say when a phase ends |
| `focusInhibit` | `true` | Hold notifications back while focusing |

## The weather

| Key | Default | What it is |
|---|---|---|
| `weatherEnabled` | `true` | |
| `weatherProvider` | `"bbc"` | `"bbc"` for what a nearby station measured, `"openmeteo"` for the model's figure at your exact spot |
| `weatherModel` | `"ukmo_seamless"` | Which Open-Meteo model: also `"ecmwf_ifs025"` or `"best_match"` |
| `weatherLat` | `0` | −90 to 90. Zero means no town chosen yet |
| `weatherLon` | `0` | −180 to 180 |
| `weatherPlace` | `""` | What the island shows it as |
| `weatherBbcId` | `""` | The BBC's own location id, digits only |
| `weatherFahrenheit` | `false` | |
| `weatherShowIcon` | `true` | |
| `weatherShowTemp` | `true` | |

## Colour

| Key | Default | What it is |
|---|---|---|
| `accent` | `"#a78bfa"` | |
| `islandTint` | `"#000000"` | The island's background, before its opacity |
| `dockTint` | `"#000000"` | |
| `launcherTint` | `"#000000"` | |

Anything Qt understands as a colour works. Anything it does not falls
back to the default rather than turning black, which is what used to
happen.

## The rest

| Key | Default | What it is |
|---|---|---|
| `language` | `"auto"` | `"auto"` follows the session. Otherwise `en`, `es`, `ca`, `de`, `fr`, `it`, `pt` or `ja` |
| `shortcutEnabled` | `true` | The key that opens the launcher |
| `shortcutKey` | `16777250` | A Qt key code. `Meta` |
| `shortcutLabel` | `"Meta"` | |
| `keepAwakeRemember` | `false` | Bring "keep awake" back switched on after a restart. Off on purpose: a machine that will not sleep because of something switched on days ago is hard to work out |
| `keepAwakeOn` | `false` | What it was last set to, when the above is on |

## What is not here

Shima remembers two more things, and not in this file, because they are
lists rather than settings:

- `~/.local/state/shima/pinned.json` — the dock, in order
- `~/.local/state/shima/favorites.json` — the launcher's favourites

Both are plain lists of `.desktop` ids and can be edited the same way.
