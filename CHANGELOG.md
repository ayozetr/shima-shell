# Changelog

Notable changes to Shima Shell, written for the people who use it
rather than for the people who write it.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the numbering follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Since there is no public API here, that means:

- **Major** — you have to do something: settings that no longer apply,
  files that moved, a new dependency you must install.
- **Minor** — new features, nothing for you to do.
- **Patch** — fixes.

## [Unreleased]

## [0.1.0] — 2026-09-23

First release. Installable and packaged; expect rough edges.

### Added

- Island with four modes — media, control centre, status and calendar —
  switched with the scroll wheel or by clicking the dots
- Dock with pinned and running applications, reordering by dragging,
  and a right-click menu
- Launcher taking its favourites, categories and places from KDE's own
  menu and keeping them in step with it, plus recent applications and
  files, and KRunner-style search across applications, files and a
  calculator
- Notifications, with history, do not disturb, and silencing during a
  focus session
- Per-monitor brightness, night light, power profiles and an inhibitor
  to keep the machine awake
- Global shortcut, on the Meta key by default, and returned to Plasma
  on uninstall
- English, Spanish, Catalan, French, German, Italian and Portuguese
- An AUR package, and an installer for every other distribution with
  KDE that fetches what it needs

### Known issues

- Quickshell sometimes crashes within seconds of starting, roughly once
  in four. Starting it again works.
- Shutting down from the island can leave the session unable to power
  off afterwards. Use Plasma's own menu until this is fixed.
- The launcher's category names follow the language of your session,
  not the one set in Shima: they come from KDE's menu.

[Unreleased]: https://github.com/ayozetr/shima-shell/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.1.0
