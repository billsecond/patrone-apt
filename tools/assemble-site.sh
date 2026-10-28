#!/usr/bin/env bash
# Puts the site together for GitHub Pages: the signed index (dists/), the
# key, the landing page, and every .deb the index names, fetched from the
# "pool" release and checked against the index's SHA256 sums. The debs the
# previous index named come too, so a computer that read that one just
# before this update can still download what it lists.
#
#   tools/assemble-site.sh SITE      (in the repository, with gh signed in)
set -euo pipefail

site=$1
index=dists/resolute/main/binary-amd64/Packages

rm -rf "$site"
mkdir -p "$site"
cp -r dists index.html patrone-archive-keyring.gpg patrone-archive-keyring.asc \
    patrone.sources "$site/"
[ -f "$index" ] || exit 0

# Filename and SHA256 of each deb, in this index and the previous one
files() { awk '$1 == "Filename:" { f = $2 } $1 == "SHA256:" { print $2 "  " f }'; }
{
    files <"$index"
    if git rev-parse -q --verify HEAD~1 >/dev/null && git cat-file -e "HEAD~1:$index" 2>/dev/null; then
        git show "HEAD~1:$index" | files
    fi
} | sort -u >"$site/.sums"

patterns=()
while read -r _ file; do
    [ "${file%/*}" = pool/main ] || { echo "Unexpected path in the index: $file" >&2; exit 1; }
    patterns+=(-p "${file##*/}")
done <"$site/.sums"
mkdir -p "$site/pool/main"
gh release download pool --dir "$site/pool/main" "${patterns[@]}"
(cd "$site" && sha256sum --check --quiet .sums)
rm "$site/.sums"
du -sh "$site"
