# Security policy

## Reporting a vulnerability

**Please do not open a public issue for a security problem.** Shima
runs on people's desktops, and an issue with a working exploit in it is
public before there is anything to update to.

Two ways to reach me privately:

- **GitHub** — the *Report a vulnerability* button under the Security
  tab of this repository.
- **Email** — ayozetr@proton.me

You will get an answer. If a week goes by without one, assume it got
lost and send it again.

## What is worth reporting

Shima builds shell commands from data it did not write and cannot
vouch for, which is where its interesting problems live:

- Anything that ends up **running a command** built from a file another
  process can write — Plasma's applet settings, the XBEL places file,
  KDE's menu, or Shima's own configuration.
- Anything that lets **another user on the same machine** read or
  tamper with what Shima writes.
- The **shortcut helper**, which talks to KGlobalAccel over D-Bus and
  can take a key away from another application.

Reports that need an attacker who already has your session open are
less interesting: at that point they have the shell anyway.

## Supported versions

The latest release, and only that one. This is a one-person project
and there is no back-porting: fixes go out in a new version.

| Version | Supported |
|---|---|
| 0.3.x | yes |
| older | no — the fix goes out in a new version |

## What happens next

The fix goes out as a new release, the changelog says what it was, and
you get the credit unless you would rather not. If it turns out to be
in Quickshell or in kdotool rather than here, I will say so and point
you at the right place.
