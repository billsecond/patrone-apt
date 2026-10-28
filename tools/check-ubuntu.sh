#!/usr/bin/env bash
# Compares Patrone's builds of Ubuntu's packages with what Ubuntu has
# published since. A package in Patrone's index is one of those builds when
# its version is Ubuntu's plus "patroneN" (GDM, GNOME Settings and first-login
# setup today). For each such source package, one line:
#
#   current|behind SOURCE BUILT-FROM UBUNTU'S-NEWEST POCKET
#
# BUILT-FROM is the Ubuntu version Patrone's build is made from, and
# UBUNTU'S-NEWEST the newest Ubuntu has published for resolute in its release,
# security or updates pocket (Launchpad's API; -proposed and backports don't
# count). Used by the daily check (.github/workflows/check-ubuntu.yml) and by
# the dev VM's rebuilds (packaging/ubuntu-updates.sh in Patrone Linux's
# repository).
#
#   tools/check-ubuntu.sh [PACKAGES-FILE]
set -euo pipefail

series=resolute
packages=${1:-$(dirname "$0")/../dists/$series/main/binary-amd64/Packages}
api=https://api.launchpad.net/devel/ubuntu

# Each of Patrone's builds of an Ubuntu package: its source, and the Ubuntu
# version it's built from
builds=$(awk '
    $1 == "Package:" { source = $2 }
    $1 == "Source:" { source = $2 }
    $1 == "Version:" { version = $2 }
    /^$/ { if (version ~ /patrone[0-9]+$/) print source, version; source = version = "" }
    END { if (version ~ /patrone[0-9]+$/) print source, version }
' "$packages" | sed 's/patrone[0-9]*$//' | sort -u)

[ -n "$builds" ] || exit 0
while read -r source built_from; do
    json=$(curl -fsS --retry 3 "$api/+archive/primary?ws.op=getPublishedSources&source_name=$source&exact_match=true&distro_series=$api/$series&status=Published")
    newest= pocket=
    while read -r version from; do
        if [ -z "$newest" ] || dpkg --compare-versions "$version" gt "$newest"; then
            newest=$version pocket=$from
        fi
    done < <(jq -r '.entries[] | select(.pocket == "Release" or .pocket == "Security" or .pocket == "Updates")
                    | "\(.source_package_version) \(.pocket)"' <<<"$json")
    if [ -z "$newest" ]; then
        echo "Launchpad lists no $source for $series" >&2
        exit 1
    fi
    if dpkg --compare-versions "$newest" gt "$built_from"; then
        state=behind
    else
        state=current
    fi
    echo "$state $source $built_from $newest $pocket"
done <<<"$builds"
