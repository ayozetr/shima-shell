#!/bin/sh
#
# Shima Shell installer
# Written by ayozetr — https://github.com/ayozetr/shima-shell
# Copyright © 2026 ayozetr. GPL-3.0-or-later.
#
# Works two ways:
#
#   curl -fsSL https://raw.githubusercontent.com/ayozetr/shima-shell/main/install.sh | sh
#   ./install.sh                     (from a clone)
#
# Piped through a shell there are no sources next to the script, so it
# fetches them itself. Everything lands under ~/.local: no root is
# needed for Shima itself, only for the packages it depends on, and
# those are never installed without asking.
#
# On Arch the AUR package is still the better route: it updates and
# removes with everything else. This is for every other distribution.

set -e

REPO=${SHIMA_REPO:-https://github.com/ayozetr/shima-shell}
BRANCH=${SHIMA_BRANCH:-main}

PREFIX=${PREFIX:-$HOME/.local}
SHARE="$PREFIX/share/shima"
BIN="$PREFIX/bin/shima"
DESKTOP="$PREFIX/share/applications/shima.desktop"
ICONS="$PREFIX/share/icons/hicolor"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/shima.desktop"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/shima"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/shima"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/shima"

ACTION=install
AUTOSTART_WANTED=
PURGE=
ASSUME_YES=
SKIP_DEPS=
TMPDIR_OWNED=

have() { command -v "$1" >/dev/null 2>&1; }
say()  { printf '%s\n' "$*"; }
err()  { printf '%s\n' "$*" >&2; }

usage() {
    cat <<USAGE
Shima Shell installer

  --autostart     start Shima with the session
  --yes           do not ask before installing packages
  --skip-deps     install Shima only, touch no packages
  --uninstall     remove it again (settings are kept)
  --purge         with --uninstall, remove the settings too
  --prefix DIR    install under DIR instead of ~/.local
  --help          this

Needs KDE Plasma 6 on a Wayland session.
USAGE
}

# ── Asking, even when piped through a shell ──────────────────────
#
# stdin is the script itself here, so a plain `read` would swallow the
# rest of it. /dev/tty is the actual terminal. Without one there is
# nobody to ask, and nothing gets installed.
ask() {
    [ -n "$ASSUME_YES" ] && return 0
    [ -r /dev/tty ] || return 1
    printf '%s [y/N] ' "$1" > /dev/tty
    read -r reply < /dev/tty || return 1
    case $reply in [yY]|[yY][eE][sS]|[sS]|[sS][iI]) return 0 ;; *) return 1 ;; esac
}

# ── Which distribution ───────────────────────────────────────────
detect_os() {
    ID=""; ID_LIKE=""
    [ -r /etc/os-release ] && . /etc/os-release 2>/dev/null || true
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"

    if   have pacman;  then PM=pacman
    elif have apt-get; then PM=apt
    elif have dnf;     then PM=dnf
    elif have zypper;  then PM=zypper
    elif have xbps-install; then PM=xbps
    elif have emerge;  then PM=emerge
    elif have nix-env; then PM=nix
    else PM=""
    fi
}

sudo_run() {
    if [ "$(id -u)" = 0 ]; then "$@"; else
        have sudo || { err "sudo is not available; run this as root or install by hand"; return 1; }
        sudo "$@"
    fi
}

# ── Package names, which differ everywhere ───────────────────────
pkg_for() {
    case "$1:$PM" in
        pygobject:pacman) echo python-gobject ;;
        pygobject:apt)    echo python3-gi ;;
        pygobject:dnf)    echo python3-gobject ;;
        pygobject:zypper) echo python3-gobject ;;
        pygobject:xbps)   echo python3-gobject ;;
        python:pacman)    echo python ;;
        python:*)         echo python3 ;;
        fd:apt)           echo fd-find ;;
        fd:dnf)           echo fd-find ;;
        fd:*)             echo fd ;;
        cava:*)           echo cava ;;
        sqlite:pacman)    echo sqlite ;;
        sqlite:apt)       echo sqlite3 ;;
        sqlite:*)         echo sqlite ;;
        curl:*)           echo curl ;;
        # Same name everywhere it exists, which is everywhere with
        # Wayland: it is the only way to read or write the clipboard.
        wlclipboard:*)    echo wl-clipboard ;;
        xdgutils:*)       echo xdg-utils ;;
        *)                echo "" ;;
    esac
}

pm_install() {
    [ $# -gt 0 ] || return 0
    case $PM in
        pacman) sudo_run pacman -S --needed --noconfirm "$@" ;;
        apt)    sudo_run apt-get install -y "$@" ;;
        dnf)    sudo_run dnf install -y "$@" ;;
        zypper) sudo_run zypper --non-interactive install "$@" ;;
        xbps)   sudo_run xbps-install -y "$@" ;;
        emerge) sudo_run emerge --ask=n "$@" ;;
        nix)    nix-env -iA "$@" ;;
        *)      return 1 ;;
    esac
}

# ── Quickshell: a package everywhere, a different one each time ──
quickshell_hint() {
    case "$OS_ID" in
        arch|cachyos|endeavouros|manjaro|garuda|artix)
            echo "sudo pacman -S quickshell" ;;
        fedora|nobara|bazzite)
            echo "sudo dnf copr enable errornointernet/quickshell && sudo dnf install quickshell" ;;
        ubuntu|linuxmint|pop|zorin|elementary)
            echo "sudo add-apt-repository ppa:avengemedia/danklinux && sudo apt update && sudo apt install quickshell" ;;
        debian)
            echo "sudo apt install quickshell   (needs testing or unstable)" ;;
        opensuse*|suse|tumbleweed)
            echo "add the home:AvengeMedia:danklinux repository from the Open Build Service, then: sudo zypper install quickshell" ;;
        nixos)
            echo "nix profile install nixpkgs#quickshell" ;;
        gentoo)
            echo "enable the GURU overlay, then: sudo emerge gui-apps/quickshell" ;;
        *)
            echo "see https://quickshell.org/docs/master/guide/install-setup/" ;;
    esac
}

install_quickshell() {
    case "$OS_ID" in
        arch|cachyos|endeavouros|manjaro|garuda|artix)
            pm_install quickshell ;;
        fedora|nobara|bazzite)
            sudo_run dnf copr enable -y errornointernet/quickshell && pm_install quickshell ;;
        debian)
            pm_install quickshell ;;
        *)
            return 1 ;;
    esac
}

# ── kdotool ──────────────────────────────────────────────────────
#
# A named version with its checksum, and not "whatever the latest
# release is". This is the only thing the installer puts on the machine
# that somebody else built, and it goes into your own bin directory:
# fetching whatever a moving tag points at, over nothing but TLS to
# github.com, and running it is a lot of trust for one line of shell.
#
# The cost is that this number has to be raised by hand when upstream
# publishes a new one, and that is the trade: there is no way to check
# a file against a hash you do not have yet.
KDOTOOL_VERSION=0.3.0
KDOTOOL_SHA256=2079cc1d492b6e83e04def4d9376e34fcb36a4e3bdc637c8c2ee6fa547ce90ff
#
# Not optional: KWin exposes no protocol for listing windows, so
# without it there is no focus, no minimising and no running dots, and
# clicking an open application starts a second copy. It is in no
# distribution's repositories, but upstream publishes a static binary,
# which is what makes this possible anywhere.
install_kdotool() {
    # On Arch an AUR helper keeps it updated with everything else.
    if have paru; then paru -S --needed --noconfirm kdotool-bin && return 0; fi
    if have yay;  then yay  -S --needed --noconfirm kdotool-bin && return 0; fi

    arch=$(uname -m)
    if [ "$arch" = "x86_64" ] && have curl && have tar && have sha256sum; then
        say "Fetching kdotool $KDOTOOL_VERSION from its releases..."
        tmp=$(mktemp -d) || return 1
        url="https://github.com/jinliu/kdotool/releases/download"
        url="$url/v$KDOTOOL_VERSION/kdotool-$KDOTOOL_VERSION-x86_64-unknown-linux-gnu.tar.gz"

        curl -fsSL "$url" -o "$tmp/kdotool.tar.gz" || { rm -rf "$tmp"; return 1; }

        got=$(sha256sum "$tmp/kdotool.tar.gz" | cut -d' ' -f1)
        if [ "$got" != "$KDOTOOL_SHA256" ]; then
            err "the kdotool download is not what it should be."
            err "  expected $KDOTOOL_SHA256"
            err "  got      $got"
            err "Nothing was installed. Please report this."
            rm -rf "$tmp"
            return 1
        fi

        tar -xzf "$tmp/kdotool.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
        bin=$(find "$tmp" -type f -name kdotool -perm -u+x | head -1)
        [ -n "$bin" ] || { err "no kdotool binary inside the archive"; rm -rf "$tmp"; return 1; }
        mkdir -p "$PREFIX/bin"
        install -m755 "$bin" "$PREFIX/bin/kdotool"
        rm -rf "$tmp"
        say "kdotool installed to $PREFIX/bin"
        return 0
    fi

    # Anything that is not x86_64: build it, it is a small Rust program.
    if have cargo; then
        say "Building kdotool with cargo..."
        cargo install --git https://github.com/jinliu/kdotool --root "$PREFIX" && return 0
    fi
    return 1
}

# ── Getting the sources when piped through a shell ───────────────
fetch_sources() {
    here=""
    case "$0" in
        */*) here=$(cd "$(dirname "$0")" 2>/dev/null && pwd || true) ;;
    esac
    if [ -n "$here" ] && [ -f "$here/Shima.qml" ]; then
        SRC="$here"
        return 0
    fi

    say "Fetching Shima from $REPO ..."
    SRC=$(mktemp -d) || { err "cannot create a temporary directory"; exit 1; }
    TMPDIR_OWNED=$SRC
    if have git; then
        git clone --depth 1 --branch "$BRANCH" "$REPO" "$SRC/shima" >/dev/null 2>&1 \
            || { err "git clone failed"; exit 1; }
        SRC="$SRC/shima"
    elif have curl && have tar; then
        curl -fsSL "$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$SRC" \
            || { err "download failed"; exit 1; }
        SRC=$(find "$SRC" -maxdepth 1 -type d -name 'shima-*' | head -1)
    else
        err "git or curl is needed to fetch the sources"
        exit 1
    fi
    [ -f "$SRC/Shima.qml" ] || { err "the download does not look like Shima"; exit 1; }
}

cleanup() { [ -n "$TMPDIR_OWNED" ] && rm -rf "$TMPDIR_OWNED"; }
trap cleanup EXIT INT TERM

# ── What is needed ───────────────────────────────────────────────
check_desktop() {
    [ "${XDG_CURRENT_DESKTOP#*KDE}" != "$XDG_CURRENT_DESKTOP" ] && return 0
    have plasmashell && return 0
    say ""
    say "Warning: this does not look like a KDE Plasma session."
    say "Shima reads Plasma's own settings, menu and favourites, and"
    say "talks to KWin. It will start elsewhere, but most of it will"
    say "do nothing."
    ask "Continue anyway?" || exit 1
}

ensure_deps() {
    [ -n "$SKIP_DEPS" ] && return 0

    # Quickshell first: without it there is nothing to run.
    if ! have qs; then
        say ""
        say "Quickshell is missing, and Shima is a Quickshell configuration:"
        say "  $(quickshell_hint)"
        say ""
        if ask "Try to install it now?"; then
            install_quickshell || {
                err "Could not install it automatically. Run the line above and start again."
                exit 1
            }
        else
            err "Install Quickshell and run this again."
            exit 1
        fi
        have qs || { err "Quickshell still is not on PATH."; exit 1; }
    fi

    # The shortcut helper. Python is everywhere; PyGObject often is not.
    missing=""
    have python3 || missing="$missing $(pkg_for python)"
    python3 -c 'import gi' 2>/dev/null || missing="$missing $(pkg_for pygobject)"
    have sqlite3 || missing="$missing $(pkg_for sqlite)"
    have curl    || missing="$missing $(pkg_for curl)"
    # The clipboard history and the launcher's copy button are these
    # two programs and nothing else; Wayland offers no other way in.
    have wl-copy || missing="$missing $(pkg_for wlclipboard)"
    have xdg-open || missing="$missing $(pkg_for xdgutils)"
    missing=$(echo "$missing" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')

    if [ -n "$missing" ]; then
        say ""
        say "These are needed and missing:$missing"
        if [ -n "$PM" ] && ask "Install them?"; then
            pm_install $missing || err "Some could not be installed; carrying on."
        else
            say "Skipped. The global shortcut, the clipboard and some"
            say "panels may not work."
        fi
    fi

    if ! have kdotool; then
        say ""
        say "kdotool is missing. Shima needs it to focus and minimise"
        say "windows and to know what is open: KWin offers no protocol"
        say "for that, so there is nothing to fall back on."
        if ask "Install it?"; then
            install_kdotool || {
                err "Could not install kdotool. See https://github.com/jinliu/kdotool"
                exit 1
            }
        else
            err "Shima needs kdotool. Install it and run this again."
            exit 1
        fi
    fi

    # Optional ones: each switches off exactly one feature.
    opt=""
    have cava || opt="$opt $(pkg_for cava)"
    have fd   || opt="$opt $(pkg_for fd)"
    opt=$(echo "$opt" | tr ' ' '\n' | grep -v '^$' | tr '\n' ' ')
    if [ -n "$opt" ]; then
        say ""
        say "Optional, each turns off one thing:$opt"
        say "  cava  the audio visualiser        fd  faster file search"
        if [ -n "$PM" ] && ask "Install these too?"; then
            pm_install $opt || true
        fi
    fi

}

# ── Installing ───────────────────────────────────────────────────
do_install() {
    detect_os
    fetch_sources
    check_desktop
    ensure_deps

    rm -rf "$SHARE"
    mkdir -p "$SHARE" "$PREFIX/bin" "$PREFIX/share/applications"

    cp "$SRC"/*.qml "$SHARE/"
    for dir in components services translations helper; do
        [ -d "$SRC/$dir" ] && cp -r "$SRC/$dir" "$SHARE/"
    done
    # What the settings window draws: our own logotype and the two
    # marks it links with. Only those: the rest of assets/ is the brand
    # work and has no business on anybody's disk.
    mkdir -p "$SHARE/assets"
    cp -r "$SRC/assets/vendor" "$SHARE/assets/" 2>/dev/null || true
    cp "$SRC/assets/logo-white.svg" "$SHARE/assets/" 2>/dev/null || true
    cp "$SRC/LICENSE" "$SRC/README.md" "$SHARE/" 2>/dev/null || true
    chmod +x "$SHARE/helper/shima-shortcuts" "$SHARE/helper/shima-games" \
        2>/dev/null || true

    cp "$SRC/shima" "$BIN"
    chmod +x "$BIN"

    sed "s|^Exec=shima$|Exec=$BIN|" "$SRC/packaging/shima.desktop" > "$DESKTOP"

    # Icons where the freedesktop specification expects them, so that
    # the Icon=shima line in the .desktop file resolves.
    install -Dm644 "$SRC/packaging/shima.svg"    "$ICONS/scalable/apps/shima.svg"
    install -Dm644 "$SRC/packaging/shima-16.svg" "$ICONS/16x16/apps/shima.svg"
    install -Dm644 "$SRC/packaging/shima-22.svg" "$ICONS/22x22/apps/shima.svg"
    install -Dm644 "$SRC/packaging/shima-symbolic.svg" \
        "$ICONS/symbolic/apps/shima-symbolic.svg"

    if [ -n "$AUTOSTART_WANTED" ]; then
        mkdir -p "$(dirname "$AUTOSTART")"
        cp "$DESKTOP" "$AUTOSTART"
        say "Autostart enabled."
    fi

    say ""
    say "Installed to $SHARE"
    case ":$PATH:" in
        *":$PREFIX/bin:"*) say "Start it with: shima" ;;
        *) say "Start it with: $BIN"
           say "($PREFIX/bin is not in your PATH)" ;;
    esac
    say ""
    say "Shima replaces the Plasma panels; you may want to remove yours."
    [ -n "$AUTOSTART_WANTED" ] || say "Run with --autostart to start it with the session."
}

# ── Removing ─────────────────────────────────────────────────────
do_uninstall() {
    # While the program still exists: give back the global shortcut and
    # any key taken off Plasma. Afterwards there is nothing left to do
    # it with, and the Meta key would stay gone.
    if [ -x "$SHARE/helper/shima-shortcuts" ]; then
        "$SHARE/helper/shima-shortcuts" --cleanup || true
    elif [ -x "$BIN" ]; then
        "$BIN" --cleanup || true
    fi

    # The launcher before the shell, and not the other way round: it
    # watches what it starts and puts it back if it dies in the first
    # seconds, so killing the shell on its own brings it straight back
    # — while this is deleting the files underneath it.
    #
    # And ours, not everybody's. `pkill -x qs` takes down any Quickshell
    # on the machine, which on a desktop running a second configuration
    # is somebody else's shell. The entry point is a path inside this
    # user's cache directory, so naming it is enough.
    pkill -x shima 2>/dev/null || true
    pkill -f "$CACHE/shell.qml" 2>/dev/null || true

    rm -rf "$SHARE" "$CACHE"
    rm -f "$BIN" "$DESKTOP" "$AUTOSTART"
    rm -f "$ICONS/scalable/apps/shima.svg" "$ICONS/16x16/apps/shima.svg" \
          "$ICONS/22x22/apps/shima.svg" "$ICONS/symbolic/apps/shima-symbolic.svg"
    say "Removed the program."

    if [ -n "$PURGE" ]; then
        rm -rf "$CONFIG" "$STATE"
        say "Removed your settings and what it remembered."
    else
        say "Your settings are still in $CONFIG (use --purge to remove them)."
    fi
}

# ── Arguments ────────────────────────────────────────────────────
while [ $# -gt 0 ]; do
    case $1 in
        --autostart) AUTOSTART_WANTED=1 ;;
        --yes|-y)    ASSUME_YES=1 ;;
        --skip-deps) SKIP_DEPS=1 ;;
        --uninstall) ACTION=uninstall ;;
        --purge)     PURGE=1 ;;
        --prefix)
            shift
            [ -n "${1:-}" ] || { err "--prefix needs a directory"; exit 1; }
            PREFIX=$1
            SHARE="$PREFIX/share/shima"; BIN="$PREFIX/bin/shima"
            DESKTOP="$PREFIX/share/applications/shima.desktop"
            ICONS="$PREFIX/share/icons/hicolor"
            ;;
        --help|-h) usage; exit 0 ;;
        *) err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

case $ACTION in
    install)   do_install ;;
    uninstall) do_uninstall ;;
esac
