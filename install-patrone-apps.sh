#!/usr/bin/env bash
# Installs Patrone's apps on a computer that isn't running PatroneOS.
#
#   curl -fsSL https://billsecond.github.io/patrone-apt/install-patrone-apps.sh | bash
#
# On Ubuntu 26.04 LTS (resolute) and systems built on it, amd64, it adds the
# "apps" component of this repository (patrone-apps.sources, never
# patrone.sources), then installs every app in it through apt, so they're
# updated with the rest of the system. It asks for your password through
# sudo. Patrone's guest tools and Virtual Machine Setup are only for virtual
# machines, so they're left out on real hardware.
#
# Anywhere else, or with --flatpak, it installs the apps that come as
# Flatpaks (Terminal, File Manager, Notepad, Task Manager, Unpack) for your
# account, from Flathub (for the GNOME runtime) and Patrone's app index. That
# needs flatpak, and no sudo.
#
# Run it again to pick up apps added since. Removing them: the README,
# "Patrone's apps on Ubuntu".
set -euo pipefail

site=https://billsecond.github.io/patrone-apt
flatpaks=(org.patrone.Terminal org.patrone.FileManager org.patrone.Notepad
    org.patrone.TaskManager org.patrone.Unpack)
apps=(patrone-terminal patrone-file-manager patrone-notepad
    patrone-task-manager patrone-unpack patrone-shell-config
    patrone-remote-desktop)
vm_apps=(patrone-guest-tools patrone-hyperv-setup)

say() { printf '%s\n' "$*"; }
die() { printf 'install-patrone-apps: %s\n' "$*" >&2; exit 1; }

# All in a function, so a download that stops part way runs nothing, and with
# stdin closed for apt and flatpak, which would otherwise read the rest of
# this script when it comes through a pipe
main() {
    flatpak=no
    for arg in "$@"; do
        case $arg in
            --flatpak) flatpak=yes ;;
            -h|--help) say "Usage: install-patrone-apps.sh [--flatpak]"; exit 0 ;;
            *) die "unknown option $arg (try --help)" ;;
        esac
    done

    [ -r /etc/os-release ] && . /etc/os-release
    [ "${ID:-}" != patrone ] || die "this is PatroneOS, which has Patrone's apps already"

    codename=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}
    if [ $flatpak = no ] && { [ "$codename" != resolute ] ||
        [ "$(dpkg --print-architecture 2>/dev/null)" != amd64 ]; }; then
        say "This isn't Ubuntu 26.04 on amd64, so Patrone's apps come as Flatpaks."
        flatpak=yes
    fi

    if [ $flatpak = yes ]; then
        command -v flatpak >/dev/null ||
            die "install flatpak first (https://flatpak.org/setup/), then run this again"
        [ "$(uname -m)" = x86_64 ] || die "Patrone's Flatpaks are for x86_64 only"
        flatpak remote-add --user --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo
        flatpak remote-add --user --if-not-exists patrone-app-index \
            https://billsecond.github.io/patrone-app-index/patrone-app-index.flatpakrepo
        flatpak install --user --noninteractive patrone-app-index "${flatpaks[@]}" </dev/null
        say "Done. Patrone's apps are in your app menu; flatpak update keeps them current."
        exit 0
    fi

    sudo=sudo
    [ "$(id -u)" -ne 0 ] || sudo=
    command -v curl >/dev/null || { $sudo apt-get update </dev/null && $sudo apt-get install -y curl </dev/null; }

    if systemd-detect-virt --vm -q 2>/dev/null; then
        apps+=("${vm_apps[@]}")
    fi

    [ ! -e /etc/apt/sources.list.d/patrone.sources ] ||
        say "Note: /etc/apt/sources.list.d/patrone.sources is PatroneOS's, and replaces Ubuntu's own packages."

    say "Adding Patrone's apps to apt ($site, the apps component)"
    $sudo curl -fsSLo /usr/share/keyrings/patrone-archive-keyring.gpg \
        "$site/patrone-archive-keyring.gpg"
    $sudo curl -fsSLo /etc/apt/sources.list.d/patrone-apps.sources \
        "$site/patrone-apps.sources"
    $sudo apt-get update </dev/null
    $sudo apt-get install -y "${apps[@]}" </dev/null
    say "Done: ${apps[*]}. Software Updater and apt upgrade keep them current."
}

main "$@"
