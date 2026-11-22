#!/usr/bin/env bash
# Set the version, commit it and tag it: scripts/version.sh v1.0.0
#
# Writes 1.0.0 to VERSION, commits only that file, and adds an annotated tag
# v1.0.0. If VERSION already holds that version, it only adds the tag. It
# needs a clean working tree and does not push.
set -euo pipefail

cd "$(dirname "$0")/.."

tag=${1:-}
if [[ ! $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: $0 vX.Y.Z (got '$tag')" >&2
    exit 1
fi
if [[ -n $(git status --porcelain --untracked-files=no) ]]; then
    echo "commit or stash your changes first" >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/$tag" > /dev/null; then
    echo "tag $tag already exists" >&2
    exit 1
fi

if [[ $(< VERSION) != "${tag#v}" ]]; then
    echo "${tag#v}" > VERSION
    git commit -m "Release $tag" VERSION
fi
git tag -a "$tag" -m "$tag"
echo "Tagged $tag. Push with: git push --follow-tags"
