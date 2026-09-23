# Contributing

Bug reports, fixes and translations are all welcome. This file is short
on purpose; if something here is unclear, open an issue and ask.

## Trying your changes

```bash
git clone https://github.com/ayozetr/shima-shell
cd shima-shell
./shima
```

Nothing is installed and nothing is written next to the program.
**Editing a file reloads the shell**, so there is no build step and no
restart: save, and look at the screen.

`qs -p shell.qml` also works, but the launcher script is what resolves
paths and keeps the icon theme in step, so prefer `./shima`.

## Tests

```bash
node tests/run.js
```

Nothing to install. It covers the parts with no screen in them — the
calculator, the bookmarks parser, the clipboard entries, which screens
something is pinned to, whether a language exists — by reading the
functions straight out of the `.qml` files that ship, so a test cannot
quietly drift from the code it is testing.

Everything else is an interface and is checked by looking at it. If
you change one of the parts above, add the case that would have caught
what you fixed: every case in there is something that actually went
wrong once.

## The assets

Everything under `assets/` is reserved (see the README) but that does
**not** get in the way of contributing: fork the repository, leave the
logo where it is, and open a pull request. A fork made to send changes
back is not a separate project.

What is not allowed is publishing a modified Shima as a project of its
own under this name and these assets.

## Code

Written in QML on top of Quickshell, with a Python helper for the
global shortcut. A few things the codebase is consistent about:

- **English everywhere** — code, comments, commit messages.
- **Comments explain why, not what.** `// Assigning node.audio.volume
  works for ALSA devices and silently does nothing on Bluetooth ones`
  is the kind of comment this project keeps: it says something you
  cannot find out by reading the line below it. A comment restating
  that line is not.
- **Write down what you ruled out.** Most of the comments here exist
  because something obvious did not work. That is worth more than the
  description of what does.
- **Commits that mean something** — one change per commit, no
  generated boilerplate.

## Using AI

Use whatever helps you work. An assistant, a generator, whatever gets
you there: what is being reviewed is the change, not how you arrived at
it.

What must not reach the repository is the trace of it. **No
`Co-Authored-By` lines for a tool, no "generated with" footers, no
mention of any assistant** in commit messages, pull requests or code
comments.

Read what you submit before you submit it, and be able to explain why
it is written the way it is. You are the author of the contribution,
whatever helped you write it.

## Reporting a bug

Most problems here depend on the session rather than on the code, so
the version numbers matter more than usual. The issue form asks for
them; the ones that decide almost everything are **Plasma**,
**Quickshell** and whether **kdotool** is installed.

The log is the other half:

```bash
./shima 2>&1 | tee shima.log
```

If Quickshell crashed rather than misbehaved, there is a report under
`~/.cache/quickshell/crashes/`.

## Translations

One file per language in `translations/`, a plain object of strings.
To add one:

1. Copy `translations/en.js` to your language code, say `nl.js`, and
   translate the values.
2. In `services/I18n.qml`, import it, add it to `strings`, and add an
   entry to `available` — **named in its own language**, the way
   language pickers do it: `{ code: "nl", label: "Nederlands" }`.

That is all: switching language is a property change, so the interface
updates without a restart. Keep the key order of `en.js` so that the
files stay comparable.

**Native speakers are what this needs most.** The existing translations
were not written by natives, and a wrong register or an odd word is the
kind of thing only somebody who speaks the language every day will
catch. Corrections to any of them are as welcome as new languages, and
you do not have to justify them: if it reads wrong to you, it reads
wrong.

**Japanese especially.** The project is named after 島, so it ought to
be there, and it is — but the strings were put together from KDE's own
Japanese catalogues rather than written by someone who speaks it. The
terminology should be right; the tone may well not be.

## Licence

Contributions are made under the GPL-3.0, like the rest of the code.
