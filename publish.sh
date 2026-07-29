#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_TAG:?}" "${RELEASE_NAME:?}" "${RELEASE_BODY:?}" "${IS_PRERELEASE:?}"
: "${GH_TOKEN:?}" "${GITHUB_REPOSITORY:?}"
dir="${1:-.}"

if gh release view "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
	echo "::notice::skip — $RELEASE_TAG already exists"
	exit 0
fi

printf '%s\n' "$RELEASE_BODY" >notes.md
args=(release create "$RELEASE_TAG" --repo "$GITHUB_REPOSITORY" --title "$RELEASE_NAME" --notes-file notes.md --target "${GITHUB_SHA:-HEAD}")
[ "$IS_PRERELEASE" = true ] && args+=(--prerelease)
gh "${args[@]}" "$dir"/*
