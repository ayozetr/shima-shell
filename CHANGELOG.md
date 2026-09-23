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

## [0.3.0] — 2026-09-23

### Added

- The settings window now appears in the dock while it is open, with
  Shima's own icon, and clicking it brings it to the front.
- It also wears that icon in its own titlebar, and wherever else the
  system lists windows, instead of Quickshell's.
- A clipboard history, in the launcher under its own category and on
  Meta+V. It keeps the last fifty things you copied — text, files and
  pictures, with a thumbnail for each picture — and puts each back as
  what it was, so a file pastes as a file. Nothing outlives the
  session and nothing reaches the disk, and anything the program that
  copied it marked as a password is not kept at all. Needs
  wl-clipboard, and says so if it is missing.
- The launcher can be used without the mouse: up and down walk what is
  on screen and return opens it.
- The notification history survives the shell restarting or crashing.
  It is kept in memory for the session, not on the disk, so it goes
  when you log out.
- Games installed through Heroic and Lutris are recognised in the dock,
  by reading the launchers' own catalogues.
- Keeping the machine awake can be remembered across restarts. Off by
  default, because a machine that will not sleep because of something
  switched on days ago is hard to work out.

### Fixed

- Closing the settings window with its own button left Shima believing
  it was still open, and it could not be opened again until the shell
  was restarted
- Right-clicking the dock with the settings window already open closed
  it instead of bringing it to the front, which was no use at all when
  the reason for clicking was that it had ended up behind something
- Silencing notifications during a focus session has never worked. It
  asked the notification server to inhibit itself, which is not
  something Shima's own server does, so notifications kept arriving
- Letting go of the brightness slider could leave the screen at the
  value before last, and moving the volume while changing output could
  write one device's level into the other
- The visualiser could be left running at sixty frames a second with
  nothing playing
- A notification arriving in the island blocked the controls, and
  moving the pointer there to get at them held it open. The wheel now
  puts it away, and a right click dismisses it without opening whatever
  sent it
- A battery at 1 % could be shown as 100 %
- Middle-clicking an icon with no windows to list opened an empty
  popup that went on swallowing clicks meant for the desktop
- An application could light up in the dock without being open, when
  its name happened to match the start of another window's class
- With the dock hidden, the strip that brings it back was measured
  against something that is not always the size of the window
- The session submenus faded in and vanished instantly on the way out
- The faintest text did not meet the contrast the accessibility
  guidelines ask for, at sizes where it matters most
- A switch with nothing behind it — Bluetooth with no adapter — looked
  disabled but still took clicks
- The island cut off the control centre instead of making room when its
  list of outputs or screens grew past a fixed height
- Quickshell sometimes dies in the first seconds of starting and does
  not try again, which on a desktop with no panels left is logging in
  to nothing. It is started again now, twice, for an early death only

### Changed

- The parts with no screen in them have tests now, run with
  `node tests/run.js` and nothing installed.

### Known issues

- Games from Heroic and Lutris are recognised by reading the launchers'
  catalogues, which has not been tried against a real installed game.
  If the format is not what was expected, nothing is recognised rather
  than anything breaking.
- The launcher's category names follow the language of your session,
  not the one set in Shima: they come from KDE's menu.

## [0.2.0] — 2026-09-23

### Added

- Japanese, built on KDE's own Japanese terminology. A native speaker
  going over it would be welcome.
- A tint for the launcher, alongside the island's and the dock's.

### Fixed

- Shutting down from the island could leave the session unable to power
  off afterwards, in Plasma's own menu as well
- Keeping the machine awake outlived the shell if it was killed, and
  the machine would not suspend again until reboot
- The session menu offered what the machine cannot do — hibernation on
  most setups — and the entry silently did nothing
- The pomodoro labels and the calendar's month name ignored the chosen
  language
- Every setting under Notifications was forgotten on restart
- The cross that dismisses a notification never lit up, and moved away
  from under the pointer as you reached for it
- Links in a notification body opened whatever scheme they carried
- Notifications were never let go of, growing without limit on a
  desktop left running
- Pinning the island and dock to a screen that is then unplugged left
  nothing on screen at all, and no way back to the settings
- With the dock at the top, an icon's menu was drawn off the edge and
  the window went on swallowing clicks
- The room the dock reserves ignored its position and icon size, so
  moving it to the top made it unclickable while the launcher was open
- With two screens, both launcher windows asked for the keyboard and
  one was left deaf
- Changing a monitor's scale did not show up in the settings until
  restarting
- A settings file that was no longer valid JSON was silently replaced
  by the defaults, losing everything in it. A copy is kept at
  `config.json.bak` instead
- One odd bookmark emptied the whole Places list
- An invalid colour in the settings turned the accent black, taking the
  text drawn on it with it; an icon size of zero gave a dock that could
  not be laid out
- Setting the language to a name like `toString` left the interface
  blank, with no way back from inside it
- Typing on while the launcher searched dropped the search for what you
  had just typed, and left the results of the older one under it
- Commands ran in Konsole whatever terminal the session had chosen, and
  in any other terminal the window closed before the output could be
  read
- Searching for a town kept the list of the one typed before it, so the
  wrong place could be saved with a click
- Deleting a town's name back down to two letters sent out one more
  search for the text just erased
- With a session menu open, clicking the button beside it only folded
  the first one away: opening the other took a second click
- Menu height was listed twice in the settings
- A desktop nobody was touching kept Shima starting two and a half
  processes a second. Idle now costs about a seventh of what it did
- The dock's tray slid and faded itself back in whenever any of its
  icons asked for attention
- The launcher's grid threw away every tile and built it again several
  times a second, and once more for every letter typed into the box
  that adds an app to the dock
- The network figure added up every interface on the machine —
  loopback, container bridges, virtual machines, the VPN — so copying a
  file to yourself showed up as traffic, twice
- A game installed while Shima was running was not recognised until it
  was restarted
- Dragging any slider in the settings re-registered the launcher
  shortcut with KDE, over and over

### Known issues

- Quickshell sometimes crashes within seconds of starting, roughly once
  in four. Starting it again works.
- The launcher's category names follow the language of your session,
  not the one set in Shima: they come from KDE's menu.

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

[Unreleased]: https://github.com/ayozetr/shima-shell/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.3.0
[0.2.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.2.0
[0.1.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.1.0
