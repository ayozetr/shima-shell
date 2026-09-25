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
# The settings window as an application of its own, so it can be
# found in the menu by somebody who has turned the dock off.
DESKTOP_SETTINGS="$PREFIX/share/applications/shima-settings.desktop"
ICONS="$PREFIX/share/icons/hicolor"
AUTOSTART="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/shima.desktop"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/shima"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/shima"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/shima"

ACTION=install
PURGE=
AUTOSTART_WANTED=
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
prompt() {
    [ -r /dev/tty ] || return 1
    printf '%s [y/N] ' "$1" > /dev/tty
    read -r reply < /dev/tty || return 1
    case $reply in [yY]|[yY][eE][sS]|[sS]|[sS][iI]) return 0 ;; *) return 1 ;; esac
}

ask() {
    [ -n "$ASSUME_YES" ] && return 0
    prompt "$1"
}

# The same question, except that --yes does not answer it. Installing a
# package because a flag said yes to everything is one thing; putting
# somebody else's repository on a machine, where it stays and serves
# every update from here on, is another, and nobody should find that
# done to them by a line they pasted. Piped with no terminal it is a no
# as well, which is what running this through curl looks like.
ask_human() {
    prompt "$1"
}

# ── Which distribution ───────────────────────────────────────────
detect_os() {
    ID=""; ID_LIKE=""; VERSION_ID=""; VERSION_CODENAME=""; UBUNTU_CODENAME=""
    [ -r /etc/os-release ] && . /etc/os-release 2>/dev/null || true
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
    # openSUSE needs it: its repositories are published per version.
    OS_VERSION="${VERSION_ID:-}"
    # And Ubuntu needs the series name. Mint carries both: its own
    # (wilma, xia) and the Ubuntu it is built on, which is the one a
    # PPA is published for.
    OS_SERIES="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

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
        # No nix here on purpose: `nix-env -i` takes an attribute path
        # (`nixpkgs.python3`) and not a package name, and the names
        # this script deals in are the ones other distributions use.
        # Quickshell is installed by its own function, which knows the
        # attribute; everything else is printed for you to declare.
        *)      return 1 ;;
    esac
}

# ── Quickshell: a package everywhere, a different one each time ──
# Where the Open Build Service publishes for this system. Checked
# against what the project actually has: Tumbleweed, Slowroll and the
# 16.x line. There is nothing for Leap 15, which is why that case says
# so instead of handing over a URL that answers 404.
obs_target() {
    case "$OS_ID" in
        opensuse-tumbleweed|tumbleweed) echo "openSUSE_Tumbleweed" ;;
        opensuse-slowroll)              echo "openSUSE_Slowroll" ;;
        *) case "$OS_VERSION" in
               16.*) echo "$OS_VERSION" ;;
               *)    echo "" ;;
           esac ;;
    esac
}

# Printed, a line at a time, when there is no Quickshell. Some of these
# are what install_quickshell() will run for you; the rest are yours to
# run, and say why below.
quickshell_hint() {
    case "$OS_ID" in
        arch|cachyos|endeavouros|manjaro|garuda|artix)
            say "  sudo pacman -S quickshell" ;;
        fedora|nobara|bazzite)
            say "  sudo dnf copr enable errornointernet/quickshell && sudo dnf install quickshell" ;;
        ubuntu|linuxmint|pop|zorin|elementary|neon)
            ppa_has_quickshell
            case $? in
                1) say "  There is no build for ${OS_SERIES:-this release}: the repository"
                   say "  that carries Quickshell for Ubuntu publishes for the newest"
                   say "  series only, and this is not one of them."
                   say "  See https://quickshell.org/docs/master/guide/install-setup/" ;;
                *) say "  sudo add-apt-repository ppa:avengemedia/danklinux && sudo apt update && sudo apt install quickshell" ;;
            esac ;;
        debian)
            # Not in trixie itself: only in its backports, and in the
            # unstable lines. Checked against sources.debian.org, which
            # is the one that answers by suite — packages.debian.org
            # replies 200 for a page that says nothing of the sort.
            if [ "$OS_SERIES" = trixie ]; then
                say "  sudo apt install -t trixie-backports quickshell"
                say "  (it is in backports, not in trixie itself; the"
                say "   installer can enable them for you)"
            else
                say "  sudo apt install quickshell" ;
            fi ;;
        opensuse*|suse|tumbleweed)
            target=$(obs_target)
            if [ -n "$target" ]; then
                say "  sudo zypper addrepo https://download.opensuse.org/repositories/home:/AvengeMedia:/danklinux/$target/home:AvengeMedia:danklinux.repo"
                say "  sudo zypper --gpg-auto-import-keys refresh && sudo zypper install quickshell"
                say ""
                say "  That repository belongs to somebody else, and adding it means"
                say "  trusting its key for everything it ships from here on."
            else
                say "  There is no build for this version of openSUSE: the repository"
                say "  publishes for Tumbleweed, Slowroll and the 16.x line only."
                say "  See https://quickshell.org/docs/master/guide/install-setup/"
            fi ;;
        nixos)
            say "  nix profile install nixpkgs#quickshell" ;;
        gentoo)
            say "  sudo eselect repository enable guru"
            say "  sudo emaint sync -r guru"
            say "  sudo emerge gui-apps/quickshell"
            say ""
            say "  GURU is a testing overlay, so the last one may also want a line"
            say "  in /etc/portage/package.accept_keywords. That is your system's"
            say "  policy and not something this script should be writing."
            ;;
        *)
            say "  see https://quickshell.org/docs/master/guide/install-setup/" ;;
    esac
}

# Whether that repository has anything for this release, asked of
# Launchpad before anybody is invited to trust it.
#
# It matters: the repository builds for the newest series only —
# questing, resolute, stonking when this was written — and not for the
# long-term ones, which is what most Ubuntu machines run. Adding a
# stranger's repository and then finding it has nothing for you is the
# worst of both: the trust is given and nothing comes back. Asking
# costs one request and ages better than a list written in here.
#
# Answers: 0 it has it, 1 it does not, 2 could not find out.
PPA_ASKED=
PPA_ANSWER=2
ppa_has_quickshell() {
    [ -n "$PPA_ASKED" ] && return "$PPA_ANSWER"
    PPA_ASKED=1
    ppa_ask_launchpad
    PPA_ANSWER=$?
    return "$PPA_ANSWER"
}

ppa_ask_launchpad() {
    [ -n "$OS_SERIES" ] || return 2
    have curl || return 2
    api="https://api.launchpad.net/devel/~avengemedia/+archive/ubuntu/danklinux"
    api="$api?ws.op=getPublishedBinaries&binary_name=quickshell"
    api="$api&exact_match=true&status=Published"
    out=$(curl -fsS --max-time 15 "$api" 2>/dev/null) || return 2
    case $out in
        *"/ubuntu/$OS_SERIES/"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Ubuntu does not carry Quickshell, and the way in is one person's
# repository. Adding it is not the same kind of act as installing a
# package, so it gets a question of its own that --yes cannot answer,
# and it says what is being agreed to and how to undo it.
add_ppa_quickshell() {
    ppa="ppa:avengemedia/danklinux"

    ppa_has_quickshell
    case $? in
        1)  err ""
            err "That repository has no build for ${OS_SERIES:-this release}."
            err "It publishes for the newest Ubuntu series only, so adding it"
            err "here would leave you trusting it for nothing in return."
            err "Build Quickshell from source, or use a release it covers:"
            err "  https://quickshell.org/docs/master/guide/install-setup/"
            return 1 ;;
        2)  say ""
            say "Could not check whether that repository has a build for"
            say "${OS_SERIES:-this release}; carrying on so you can decide." ;;
    esac
    say ""
    say "Quickshell is not in Ubuntu's own archive. The way in is $ppa,"
    say "which belongs to somebody else: adding it means trusting its key"
    say "for everything it ships, in this install and in every update after"
    say "it, for the whole system."
    say ""
    say "It stays until you take it out:"
    say "  sudo add-apt-repository --remove $ppa"
    say ""
    ask_human "Add that repository?" || {
        err "Not added. Install Quickshell yourself and run this again."
        return 1
    }

    # On a minimal install the command that adds repositories is itself
    # a package.
    have add-apt-repository || pm_install software-properties-common || return 1
    sudo_run add-apt-repository -y "$ppa" || return 1
    sudo_run apt-get update || return 1
    pm_install quickshell
}

# Fedora has it in a COPR, which is Fedora's own service for builds
# that are not in the distribution — and enabling one is a subcommand
# that may not be installed. Since dnf5 it lives in dnf5-plugins, and
# before that in dnf-plugins-core, the same way `add-apt-repository`
# is a package of its own on Ubuntu. Without it `dnf copr` answers
# "unknown command" and the install stops for a reason nobody would
# guess from the message.
fedora_install_quickshell() {
    if ! dnf copr --help >/dev/null 2>&1; then
        say ""
        say "The command that enables a COPR is not installed. Adding it."
        if dnf --version 2>/dev/null | grep -q '^dnf5'; then
            pm_install dnf5-plugins || return 1
        else
            pm_install dnf-plugins-core || return 1
        fi
    fi
    sudo_run dnf copr enable -y errornointernet/quickshell || return 1
    pm_install quickshell
}

# Debian carries Quickshell, but not in stable: trixie has it only in
# backports. Those are Debian's own — not a stranger's repository — so
# this asks the ordinary question rather than the one --yes cannot
# answer, and only when the package cannot be had as things stand.
debian_install_quickshell() {
    if apt-cache policy quickshell 2>/dev/null | grep -qE 'Candidate: [0-9]'; then
        pm_install quickshell
        return
    fi

    [ "$OS_SERIES" = trixie ] || { pm_install quickshell; return; }

    say ""
    say "Quickshell is not in trixie itself, only in trixie-backports."
    say "Those are Debian's own packages, built for this release."
    say ""
    ask "Enable trixie-backports and install it from there?" || {
        err "Then install it yourself with:"
        err "  sudo apt install -t trixie-backports quickshell"
        return 1
    }

    list=/etc/apt/sources.list.d/shima-backports.list
    printf 'deb http://deb.debian.org/debian trixie-backports main\n' \
        | sudo_run tee "$list" >/dev/null || return 1
    sudo_run apt-get update || return 1
    sudo_run apt-get install -y -t trixie-backports quickshell
}

# nixpkgs is the distribution's own, so there is nobody new to trust
# here. The first spelling is the one Quickshell documents and needs
# flakes turned on; the second works without them.
nix_install_quickshell() {
    nix profile install nixpkgs#quickshell 2>/dev/null && return 0
    nix-env -iA nixpkgs.quickshell
}

# Whether the case below is one this script can actually carry out.
# Asked before offering, so nobody is invited to try something that
# answers "could not" the moment they say yes.
can_install_quickshell() {
    case "$OS_ID" in
        arch|cachyos|endeavouros|manjaro|garuda|artix) return 0 ;;
        fedora|nobara|bazzite)                         return 0 ;;
        debian)                                        return 0 ;;
        # Only where that repository has something for this series.
        # Unknown counts as yes: without an answer it is the person in
        # front of the machine who should decide, not us.
        ubuntu|linuxmint|pop|zorin|elementary|neon)
            ppa_has_quickshell
            [ $? -eq 1 ] && return 1
            return 0 ;;
        nixos)                                         return 0 ;;
        *)                                             return 1 ;;
    esac
}

install_quickshell() {
    case "$OS_ID" in
        arch|cachyos|endeavouros|manjaro|garuda|artix)
            pm_install quickshell ;;
        fedora|nobara|bazzite)
            fedora_install_quickshell ;;
        debian)
            debian_install_quickshell ;;
        ubuntu|linuxmint|pop|zorin|elementary|neon)
            add_ppa_quickshell ;;
        nixos)
            nix_install_quickshell ;;
        # openSUSE and Gentoo are printed and not run: the first needs a
        # repository that is not published for every version, and the
        # second needs an overlay plus a keyword of your own choosing.
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

cleanup() {
    case $TMPDIR_OWNED in ?*) rm -rf "$TMPDIR_OWNED" ;; esac
}
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
        quickshell_hint
        say ""
        if can_install_quickshell; then
            if ask "Try to install it now?"; then
                install_quickshell || {
                    err "Did not get it installed. Use the lines above and start again."
                    exit 1
                }
            else
                err "Install Quickshell and run this again."
                exit 1
            fi
        else
            err "Install Quickshell with the lines above and run this again."
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
        # NixOS is left to declare its own. `nix-env -i` wants an
        # attribute path and not a package name, and the names above
        # are the ones apt and pacman use: handing them over would fail
        # on every one. Somebody running NixOS puts them in their
        # configuration anyway, which is the whole point of it.
        if [ "$OS_ID" = nixos ]; then
            say ""
            say "Add them to your configuration; this will not install them"
            say "for you, since the names above are not the ones nixpkgs uses."
        elif [ -n "$PM" ] && ask "Install them?"; then
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
        if [ "$OS_ID" != nixos ] && [ -n "$PM" ] && ask "Install these too?"; then
            pm_install $opt || true
        fi
    fi

}

# ── Installing ───────────────────────────────────────────────────
#
# The .desktop files ship with `Exec=shima`, which has to become the
# path this install used. Written with awk and not sed: the path is
# data, and sed would read a `|`, a `&` or a backslash in it as
# syntax. A path with a space in it also has to be quoted, or the
# line is not a valid Exec.
desktop_to() {
    quoted=$BIN
    case $BIN in *" "*) quoted="\"$BIN\"" ;; esac
    awk -v bin="$quoted" '
        /^Exec=shima$/  { print "Exec=" bin; next }
        /^Exec=shima /  { print "Exec=" bin substr($0, 11); next }
                        { print }
    ' "$1" > "$2"
}

do_install() {
    detect_os
    # Before fetching anything: being told this is not a Plasma session
    # is worth knowing before a download, not after one.
    check_desktop
    fetch_sources
    ensure_deps

    rm -rf "$SHARE"
    mkdir -p "$SHARE" "$PREFIX/bin" "$PREFIX/share/applications"

    cp "$SRC"/*.qml "$SHARE/"
    for dir in components services translations helper; do
        [ -d "$SRC/$dir" ] && cp -r "$SRC/$dir" "$SHARE/"
    done
    # Python leaves this behind next to a script it has imported, and
    # a copy of the tree carries it along: bytecode compiled for
    # somebody else's Python, on your disk, for nothing.
    rm -rf "$SHARE/helper/__pycache__"
    # What the settings window draws: our own logotype and the two
    # marks it links with. Only those: the rest of assets/ is the brand
    # work and has no business on anybody's disk.
    mkdir -p "$SHARE/assets"
    cp -r "$SRC/assets/vendor" "$SHARE/assets/" 2>/dev/null || true
    cp "$SRC/assets/logo-white.svg" "$SHARE/assets/" 2>/dev/null || true
    cp "$SRC/LICENSE" "$SRC/README.md" "$SHARE/" 2>/dev/null || true
    # What every setting means. The README points at it, and the
    # package installs it, so this had no business being the one way
    # in that leaves you without it.
    mkdir -p "$SHARE/docs"
    cp "$SRC/docs/settings.md" "$SHARE/docs/" 2>/dev/null || true
    chmod +x "$SHARE/helper/shima-shortcuts" "$SHARE/helper/shima-games" \
        2>/dev/null || true

    cp "$SRC/shima" "$BIN"
    chmod +x "$BIN"

    desktop_to "$SRC/packaging/shima.desktop" "$DESKTOP"
    desktop_to "$SRC/packaging/shima-settings.desktop" "$DESKTOP_SETTINGS"

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
# Whether the Shima that is running is the one being removed. The
# shell says where it was started from, so it can be asked rather than
# guessed. This matters because everything below — stopping it, handing
# Plasma its keys back — is done to the session and not to a directory:
# removing a copy installed under another prefix used to take down the
# one you were using and leave you without your shortcuts. Found by
# doing exactly that.
running_is_ours() {
    for pid in $(pgrep -x qs 2>/dev/null); do
        dir=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null \
              | sed -n 's/^SHIMA_DATA_DIR=//p' | head -1)
        [ -n "$dir" ] && [ "$dir" = "$SHARE" ] && return 0
    done
    return 1
}

do_uninstall() {
    mine=no
    running_is_ours && mine=yes

    # While the program still exists: give back the global shortcut and
    # any key taken off Plasma. Afterwards there is nothing left to do
    # it with, and the Meta key would stay gone. Only for the one that
    # is running, though: the keys belong to the session, and a copy
    # being deleted elsewhere has no business handing them back.
    if [ "$mine" = yes ]; then
        if [ -x "$SHARE/helper/shima-shortcuts" ]; then
            "$SHARE/helper/shima-shortcuts" --cleanup || true
        elif [ -x "$BIN" ]; then
            "$BIN" --cleanup || true
        fi
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
    if [ "$mine" = yes ]; then
        pkill -x shima 2>/dev/null || true
        pkill -f "$CACHE/shell.qml" 2>/dev/null || true
        rm -rf "$CACHE"
    fi

    rm -rf "$SHARE"
    rm -f "$BIN" "$DESKTOP" "$DESKTOP_SETTINGS" "$AUTOSTART"
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
            DESKTOP_SETTINGS="$PREFIX/share/applications/shima-settings.desktop"
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
