#!/bin/sh
# Copyright (C) 2026 Alok K. Dhir
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# Build the os-loupe and os-eero packages on an OPNsense box and publish them to this package repository
# (repo/, served by GitHub Pages at https://alokdhir.github.io/os-plugins/).
#
#   SSH="ssh -i key" ROUTER=user@router tools/publish.sh
#
# The plugins' checkouts sit next to this one (LOUPE_DIR, EERO_DIR), as does opnsense/plugins (PLUGINS_DIR).
# Packages are built from what is committed (git archive HEAD of each repository), with OPNsense's own plugin
# tooling (a checkout of opnsense/plugins, PLUGINS_DIR) on the OPNsense box, so their dependencies are the
# versions OPNsense ships. They hold no compiled code: one package serves every architecture.
# A changed plugin needs a new PLUGIN_VERSION (or PLUGIN_REVISION) in its Makefile, or pkg won't upgrade to it.

set -e
cd "$(dirname "$0")/.."
HERE=$(pwd)
: "${ROUTER:?set ROUTER=user@router (an OPNsense box to build on)}"
SSH=${SSH:-ssh}
LOUPE=${LOUPE_DIR:-$HERE/../os-loupe}
EERO=${EERO_DIR:-$HERE/../os-eero}
PLUGINS=${PLUGINS_DIR:-$HERE/../opnsense-plugins}
# the repository index is signed with this key; routers check it against dhir-os-plugins.pub
KEY=${SIGNING_KEY:-$HOME/.config/opnsense/dhir-os-plugins.key}
[ -r "$KEY" ] || { echo "no signing key at $KEY (set SIGNING_KEY)" >&2; exit 1; }
PLUGIN_DIRS="$LOUPE:loupe $EERO:eero"

for p in "$HERE:" $PLUGIN_DIRS; do
    dir=${p%:*}
    if [ -n "$(git -C "$dir" status --porcelain)" ]; then
        echo "$dir has uncommitted changes: packages are built from what is committed" >&2
        exit 1
    fi
done
[ -d "$PLUGINS/Mk" ] || { echo "no opnsense/plugins checkout at $PLUGINS (set PLUGINS_DIR)" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# the build tree: opnsense/plugins tooling plus each plugin under net-mgmt/
mkdir -p "$WORK/plugins/net-mgmt"
git -C "$PLUGINS" archive HEAD Mk Scripts Templates | tar -xf - -C "$WORK/plugins"
BUILD=""
for p in $PLUGIN_DIRS; do
    dir=${p%:*} name=${p#*:}
    mkdir -p "$WORK/plugins/net-mgmt/$name"
    git -C "$dir" archive HEAD | tar -xf - -C "$WORK/plugins/net-mgmt/$name"
    version=$(sed -n 's/^PLUGIN_VERSION=[[:space:]]*//p' "$dir/Makefile")
    commit="$version 0 $(git -C "$dir" rev-parse --short HEAD)"
    # GIT: the commit comes from PLUGIN_COMMIT, the build tree has no history; PLUGIN_DEVEL empty: a release package (os-NAME, not os-NAME-devel); PLUGIN_NO_ABI: any FreeBSD ABI/arch
    BUILD="$BUILD (cd plugins/net-mgmt/$name && make package GIT=/nonexistent PLUGIN_DEVEL= PLUGIN_NO_ABI=yes PLUGIN_COMMIT='$commit' >/dev/null) &&"
done

REMOTE=$($SSH "$ROUTER" mktemp -d /tmp/publish.XXXXXX)
# a version already published must not change under the same name (pkg would never offer it): an unchanged
# plugin keeps its published package (a rebuild differs only in timestamps); a changed one needs a new version
cat > "$WORK/plugins/samever.sh" <<'CHECK'
set -e
for pkg in repo/All/*.pkg; do
    name=$(basename "$pkg")
    fetch -qo "old-$name" "https://alokdhir.github.io/os-plugins/repo/All/$name" 2>/dev/null || continue
    # the version file records the commit built from: it changes with every commit, plugin files or not
    same() { tar -xOf "$1" --exclude '+*' --exclude '*/opnsense/version/*' 2>/dev/null | sha256; }
    if [ "$(same "$pkg")" != "$(same "old-$name")" ]; then
        echo "$name is already published with different contents: bump PLUGIN_VERSION" >&2
        exit 1
    fi
    mv "old-$name" "$pkg"
done
CHECK
COPYFILE_DISABLE=1 tar -czf - -C "$WORK" plugins | $SSH "$ROUTER" "tar -xzf - -C $REMOTE"
# the key is on the build box only while the index is signed
$SSH "$ROUTER" "umask 077 && cat > $REMOTE/signing.key" < "$KEY"
$SSH "$ROUTER" "cd $REMOTE && $BUILD mkdir -p repo/All && cp plugins/net-mgmt/*/work/pkg/*.pkg repo/All/ && sh plugins/samever.sh && cd repo && pkg repo . $REMOTE/signing.key >/dev/null; rc=\$?; rm -f $REMOTE/signing.key; exit \$rc" || { $SSH "$ROUTER" "rm -rf $REMOTE"; exit 1; }
$SSH "$ROUTER" "tar -czf - -C $REMOTE repo; rm -rf $REMOTE" | tar -xzf - -C "$WORK"

git pull -q --ff-only
rm -rf repo
cp -R "$WORK/repo" repo
git add -A repo
# REINDEX=1 publishes a new index even when no package changed (a new signing key)
if [ -z "$REINDEX" ] && git diff --cached --quiet -- repo/All; then
    git reset -q && git checkout -q -- repo
    echo "nothing new to publish"
    exit 0
fi
git commit -qm "Packages: $(cd repo/All && ls *.pkg | sed 's/\.pkg$//' | tr '\n' ' ')"
git push -q
echo "published: $(cd repo/All && ls | tr '\n' ' ')"
