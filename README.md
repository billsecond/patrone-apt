# Patrone Linux packages

The apt repository Patrone Linux gets its own updates from, at
<https://billsecond.github.io/patrone-apt>. GitHub hosts it (Pages for the
index, a release for the files); Patrone runs no servers of its own.

Every Patrone Linux install has it already: `patrone-desktop` installs the
source (`/etc/apt/sources.list.d/patrone.sources`), the key
(`/usr/share/keyrings/patrone-archive-keyring.gpg`) and the pins that put
Patrone's builds before Ubuntu's (`/etc/apt/preferences.d/patrone.pref`).
Updates arrive through Patrone Software and the daily automatic updates
(unattended-upgrades allows the `Patrone` origin).

## What's in it

One suite, `resolute` (Ubuntu 26.04 LTS), component `main`, amd64, holding the
newest version of each package:

- Patrone's own packages: everything in Patrone Linux's `packaging/`.
- Patrone's builds of Ubuntu's packages that carry Patrone's changes: GDM
  (`gdm3`, `libgdm1`, `gir1.2-gdm-1.0`, `libgdm-dev`), GNOME Settings
  (`gnome-control-center` and its `-data`, `-dev` and `-faces`) and
  first-login setup (`gnome-initial-setup`). Their version is Ubuntu's plus
  `patroneN`.

The index's `Origin` is `Patrone` and its `Label` `Patrone Linux`.

## How it's laid out

| Where | What |
| --- | --- |
| `dists/resolute/` on `main` | The index: `Packages` (plain, `.gz`, `.xz`) and `Release`, signed as `InRelease` and `Release.gpg` |
| The [`pool` release](https://github.com/billsecond/patrone-apt/releases/tag/pool) | The `.deb` files: those the index names, and those the index before it named |
| `patrone-archive-keyring.gpg`, `.asc` | The public key |
| `patrone.sources` | The source as Patrone installs it |
| `tools/assemble-site.sh`, `.github/workflows/pages.yml` | On every push to `main`: the site, the index and key from `main` and the debs from the release, checked against the index's sums and published to Pages |
| `tools/check-ubuntu.sh`, `.github/workflows/check-ubuntu.yml` | Once a day: whether Ubuntu has updated a package Patrone rebuilds. Each one that's behind gets an issue (label `ubuntu-update`) that closes by itself once the rebuild is published |

The debs aren't in git: `patrone-branding` alone is about 90 MB, near git's
100 MB limit for a file, and each version would stay in the history. The
release has no such limit, and only the files of the last two indexes are
kept there.

## Publishing

On the dev VM, from Patrone Linux's repository, after building:

```
./packaging/publish.sh patrone-terminal       # its newest build in out/
./packaging/publish.sh gdm3                    # brings libgdm1 and the rest of that build
./packaging/publish.sh --all                   # the newest build of every package in out/
./packaging/publish.sh --dry-run --all         # what would change
```

It uploads the new debs to the `pool` release, writes and signs the index,
commits it here and pushes; Pages has it a minute or two later. A package
already published at that version or newer is skipped.

The dev VM also rebuilds GDM, GNOME Settings and first-login setup by itself
whenever Ubuntu updates them, and publishes them
(`packaging/ubuntu-updates.sh`, daily). The daily check here is the watchdog
for that.

## The key

`Patrone Linux Archive (billsecond.github.io/patrone-apt)`, Ed25519, no
expiry:

```
8FE6 1B83 753C 2636 CD74  0259 4FC3 52E3 D384 225F
```

The private key is never on GitHub. It lives on the dev VM, in
`~/.local/share/patrone-apt/gnupg` (with its revocation certificate in
`openpgp-revocs.d/`), backed up as `~/.local/share/patrone-apt/secret-key-backup.asc`.
Every Patrone install trusts this key alone for this repository: if it's
lost, installs can't be sent a new one, so keep a copy somewhere other than
the VM too.

## Adding it by hand

To try Patrone's packages on Ubuntu 26.04 LTS:

```
sudo curl -fsSLo /usr/share/keyrings/patrone-archive-keyring.gpg https://billsecond.github.io/patrone-apt/patrone-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/patrone.sources https://billsecond.github.io/patrone-apt/patrone.sources
sudo apt update
```

## Limits

GitHub Pages sites can be up to 1 GB and have a soft limit of 100 GB of
traffic a month. The site is the newest packages plus the previous ones
(about 250 MB now). If Patrone outgrows that, the index and debs can move to
any static host without changing the key; installs would need a
`patrone-desktop` update with the new address, published here first.
