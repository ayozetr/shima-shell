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

## [0.6.0] — 2026-09-30

What came back from 0.5.0: an audit of everything that release turned
up, three more distributions, and the installer fixed in the places
where nobody had ever watched it fail.

### Added

- Right clicking a tray icon that belongs to a Windows program running
  under Wine — Ubisoft Connect, the EA app, Battle.net — opens its
  menu. Those icons come through a bridge that publishes no menu, and
  the shell gave up there instead of asking the icon to draw its own.
  The menu appears where Wine decides to put it, and the first click
  sometimes shows the program's name rather than the menu; both are
  below anything Shima can reach.
- `docs/distributions.md`: how it goes on each distribution and what
  versions it needs, every number of it met on a real machine.
- `docs/troubleshooting.md`: nine questions that have actually been
  asked, and a plain answer where the answer is that nothing can be
  done.

### Changed

- A click anywhere along the row of mode dots takes the nearest one. A
  dot is four pixels wide with four more to the next, and widening
  either the target or the spacing changes the other, since they are
  the same measurement. Nothing was widened: the drawing is untouched
  and the aiming is what changed.
- A settings box writes when you stop typing rather than on every
  keystroke — one shortcut name wrote the file twenty-nine times, and
  the shortcut helper rereads it each time. It still writes the moment
  you leave the box.
- Escape in a search field leaves the field and keeps the setting,
  instead of closing the settings window.
- The key names shown are the ones KDE writes down: Del, Return, Ins,
  Esc, PgUp, PgDown.
- The sections of the configuration file describe what is under them
  again; several settings had drifted into the wrong one.
- The screenshots in the README show the shell as it is now, and the
  wallpaper they were taken against ships in `assets/vendor/`.

### Fixed

- A window name holding `$(...)` was executed. The dock built a shell
  script with those names written into it, quoted for JSON rather than
  for a shell, and the names come from desktop files and from the
  titles Steam keeps. They are passed as arguments now, which a shell
  never parses.
- A shell that died while the settings window was waiting for a key
  left Meta and Meta+V unregistered for the rest of the session, with
  nothing on screen to say why.
- `qs ipc call launcher show` printed the list of targets and opened
  nothing: `show` is one of five words the tool keeps for itself.
- A first run printed four warnings about files that do not exist,
  which is what a first run is.
- A track whose artist arrives with a newline in it, which is what KDE
  Connect sends from a phone, took two lines in a panel with room for
  one and pushed the transport out of it.
- `Ctrl+Alt+Delete` never noticed the `Ctrl+Alt+Del` already taken,
  because the names being compared were not the ones KDE uses.
- Deleting the last pinned application hit the one focus pattern Qt
  refuses, and the arrow keys did not move through the lists at all.
- The installer died at the first question it asked with no terminal
  behind it: exit 1, nothing printed, everything already copied into
  place. A redirection error on a POSIX special built-in ends a
  non-interactive shell, so the `|| return 1` meant to answer "no"
  never ran. Every distribution was affected — ssh without a terminal,
  cron, a container, CI.
- The installer stopped for want of curl while holding a package
  manager that could have installed it: the step that installs it ran
  after the step that needs it.
- kdotool was downloaded again on a second run while sitting in
  `~/.local/bin`, because only the PATH was looked at.
- An X11 session was not mentioned at all. The panels are layer-shell
  surfaces, which X11 has no equivalent of, so nothing appears while
  the installer finishes happily. It asks first now, and only when the
  session says x11 outright.
- Told that it could not reach Launchpad, the installer suggested
  adding a repository that may have nothing for that release. It says
  which of the two it is now.
- Gentoo was told to run a command that cannot work on a fresh
  install: `eselect repository` is its own package and nothing pulls
  it in. The keyword note said one line where it takes three.

### Known issues

- Debian 13 runs the shell but cannot open the settings window: its Qt
  is 6.8, and the same window opens on Qt 6.11 with the very same
  Quickshell.
- KDE Neon has no Quickshell to install; built by hand, everything
  works there.
- Gentoo needs the GURU overlay enabled and three keyword lines before
  Quickshell will install. The installer prints the commands and
  leaves them to you.
- Notifications go to whoever asked for the service first, and Plasma
  asks too.
- Blur needs Plasma 6.7 or newer.
- The launcher's category names follow the language of your session,
  not the one set in Shima: they come from KDE's menu.
- The island, the dock and the session bar are mouse only.

## [0.5.0] — 2026-09-27

The release where Shima stops assuming it is on the machine it was
written on. All of it comes from installing it on seven other
distributions and writing down what broke.

### Added

- The installer installs Quickshell too, instead of printing the line
  you had to run yourself: the PPA on Ubuntu and its derivatives, the
  COPR on Fedora, backports on Debian, nixpkgs on NixOS, and on
  openSUSE the two lines for your version, printed and left for you to
  run because that repository is a stranger's.
- Whether Shima starts with the session is a switch in Settings ·
  General. It used to be a flag on a command line most people never
  type.
- Games you dragged into Steam yourself now reach the dock, with the
  name Steam knows them by and whatever artwork it has for them. They
  have no desktop file and no manifest, so they were invisible while
  you were playing them.
- [docs/distributions.md](docs/distributions.md) — which distributions
  it has been run on, what happens on each, and the three questions
  people ask: why there is no blur, why the settings window will not
  open on Debian, and why notifications sometimes keep going to Plasma.

### Changed

- It looks the same everywhere now. The panels are solid and untinted
  by default rather than translucent, because translucency without
  blur is not the same effect — and blur needs Plasma 6.7, which most
  distributions do not have yet.
- The seven icons down the side of the settings window ship with
  Shima. Asked of the icon theme, they came out as dark glyphs on a
  dark sidebar on a stock Breeze, and three of them arrived in full
  colour.
- The settings window is built when you open it and not before. It
  used to be created with the shell and kept hidden, on every machine,
  whether or not anyone opened it.
- The launcher tells a crash from a stop. A shell that crashes comes
  back instead of leaving you with a bare desktop.

### Fixed

- Shima did not start at all on Qt 6.10: `long` is a word JavaScript
  keeps for itself, and a file that parsed here refused to parse
  there.
- Debian 13 could not run it at all — it crashed while building the
  settings window, inside Qt's own machinery.
- An application whose window announces a name in reverse domain form
  while its desktop file gives the short one was missing from the
  dock, and clicking it started a second copy rather than raising the
  first.
- An application pinned after the first sweep sat in the dock twice.
- The screens section of the settings was missing on a machine with
  one monitor, which is the machine most likely to have one.
- A long category name pushed the launcher's list out of shape.
- The island drew the album art before it had finished opening.
- The "do not disturb" tooltip was cut off.
- Shima's own icon was missing from the dock, the settings window and
  the about page on a machine where it was not yet in the icon theme.
- Uninstalling left `~/.cache/shima` behind whenever the shell had
  been stopped first — which is what anyone does, and what a crash
  does for you.
- `--purge` on its own installed instead of saying it needs
  `--uninstall`.
- The installer died in silence on KDE Neon, where the one branch that
  had an explanation to give was the one that ended the script.
- On NixOS it asked for the wrong attribute, could not find the
  running shell because the process is named after a wrapper, and left
  it running out of deleted files with the Meta key still taken.
- Five more things the installer took for granted: no git, no curl, a
  DVD left in `sources.list`, a `/dev/tty` that opens but answers
  nothing, and a `~/.local/bin` that a login session had already
  decided about.

### Known issues

- **Debian 13** runs the shell but cannot open the settings window:
  its Qt is 6.8, and the same window opens on Qt 6.11 with the very
  same Quickshell. Debian freezes Qt until Debian 14. Everything is
  settable by hand in the meantime — see
  [docs/settings.md](docs/settings.md).
- **KDE Neon** has no Quickshell to install: nobody builds it for
  Ubuntu 24.04, which is its base. Built by hand, everything works.
- **Notifications** go to whoever asked for the service first, and
  Plasma asks too. Which one wins varies by machine, and removing
  Plasma's panels does not settle it.
- Blur needs **Plasma 6.7** or newer. Below that the panels are drawn
  solid, which is what they are by default anyway.

## [0.4.0] — 2026-09-25

### Added

- The settings window is six pages down a side — general, dock,
  launcher, island, notifications, weather and about — instead of one
  column with sixty-two rows and five screens of scrolling to reach
  the language.
- Shima's settings appear in the application menu, so they can be
  found by name. Turning the dock off used to leave nowhere to change
  anything: the only way in was a right click on the dock itself.
  Opening them starts the shell if it is not already up.
- An about page, with the version, a link to the source and one to
  Ko-fi.
- What a right click on the dock opens is now yours to choose: the
  settings, a system monitor you have installed, any other application
  by its id, or nothing.
- A tone that sets the dock, the island and the launcher at once, in
  general. It marks nothing when the three differ, rather than naming
  one of them and being wrong about the other two.
- The settings window can be used without the mouse. Tab walks every
  control, the arrows work sliders, choices and lists, delete removes
  a pinned application, and escape closes the window. Every control
  also says what it is to a screen reader, with the name of the row it
  sits in.
- The media panel shows how far into the track you are, where the
  volume of the whole machine used to be — that is one turn of the
  wheel away in the control centre. It can be dragged where the player
  says it can seek, and a live stream says so beside whoever is
  streaming instead of pretending to have an end.
- Searching in the launcher marks the first answer, so return opens it.

### Changed

- The dock no longer starts with a written list of applications, which
  was the author's own. With nothing to inherit from a Plasma panel it
  asks the system what it opens a web address, a folder and a terminal
  with.
- The launcher forgets what you last searched for.
- The island speaks for whatever is playing and, failing that,
  whatever is paused. It used to take the first player on the bus,
  which is a browser that registered itself hours ago: pausing Spotify
  handed the island an empty panel with no way to press play again.
- A shortcut can be set to a combination. A modifier used to be taken
  the moment it went down, so Meta+V could not be typed at all; it now
  waits to see what follows. Ours are taken out of KDE's hands while
  the box is listening, since a registered combination never reaches
  the window, and what a key was taken from is said — in red when it
  was one of ours, which is left without one.
- A key borrowed from Plasma is given back as soon as we stop using
  it, rather than only when Shima is uninstalled.
- The weather starts on the forecast model Open-Meteo picks for your
  location. The Met Office was the default because it feeds BBC and
  therefore Plasma's widget, but with BBC as the provider the model's
  temperature is never read — all it decides is the icon.

### Fixed

- Dropping a reordered dock icon brought the whole row in from the
  left edge.
- The clipboard settings were filed under "dock applications", which
  they had nothing to do with.
- Ticking a setting that shows or hides the row under it threw you
  back to the top of the page.
- The last colour in a row came out with a slice missing, and the
  chevron of a list was cut by the corner of its row.
- A notification's own picture came back wearing somebody else's face
  after a restart: the address is a number handed out in order, and
  the count starts again with the shell.
- A player that is stopped no longer shows what it left behind. A
  browser clears the title when the video ends but keeps pointing at
  its own logo.
- The calendar stayed on whatever month you walked to.
- The dock's menu sat underneath the launcher instead of closing, and
  the launcher's own menu for an application came back on its own the
  next time it opened.
- An application pinned to the dock and no longer installed left a
  blank square that still took up room and swallowed clicks.
- With BBC as the weather provider and the unit set to Fahrenheit, the
  degrees shown were Celsius.
- The notification history no longer says it could not be read on the
  first start of every session, when there is nothing to read yet.

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

[Unreleased]: https://github.com/ayozetr/shima-shell/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.6.0
[0.5.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.5.0
[0.4.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.4.0
[0.3.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.3.0
[0.2.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.2.0
[0.1.0]: https://github.com/ayozetr/shima-shell/releases/tag/v0.1.0
