#!/usr/bin/env bash
set -euo pipefail

: "${MODE:?}" "${GITHUB_OUTPUT:?}" "${GITHUB_REPOSITORY:?}" "${GH_TOKEN:?}"
UPSTREAM="${UPSTREAM:-https://git.sr.ht/~xerool/fennel-ls}"

dir=$(mktemp -d)
git clone "$UPSTREAM" "$dir/src"
cd "$dir/src"

auto=false
if [ "$MODE" = auto ]; then
	auto=true
	tag=$(git tag -l --sort=-v:refname | head -n1)
	if [ -n "$tag" ] && ! gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
		MODE=release
	else
		MODE=prerelease
	fi
fi

if [ "$MODE" = prerelease ]; then
	sha=$(git rev-parse HEAD)
	short=${sha:0:12}
	tag="pre-$short"
	pre=true
	title="fennel-ls pre-release $short"
	body="Pre-release of $UPSTREAM \`$sha\`."
	latest=$(git tag -l --sort=-v:refname | head -n1)
	if [ "$auto" = true ] && [ -n "$latest" ] && [ "$(git rev-parse "$latest^{commit}")" = "$sha" ]; then
		echo "::notice::skip — HEAD is already upstream $latest"
		echo "should_release=false" >>"$GITHUB_OUTPUT"
		exit 0
	fi
else
	tag=$(git tag -l --sort=-v:refname | head -n1)
	[ -n "$tag" ] || { echo "no upstream tags" >&2; exit 1; }
	git checkout --detach "refs/tags/$tag"
	sha=$(git rev-parse HEAD)
	pre=false
	title="fennel-ls $tag"

	notes=$(git for-each-ref "refs/tags/$tag" --format='%(contents)' | sed \
		-e '/^-----BEGIN /,$d' \
		-e 's/^= \+\(.*\) \+=$/## \1/' \
		-e 's/^== \+\(.*\) \+==$/### \1/')

	body="${UPSTREAM%/}/refs/${tag} (\`$sha\`)"
	[ -n "${notes//[[:space:]]/}" ] && body="$body

$notes"
fi

if gh release view "$tag" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
	echo "::notice::skip — $tag already exists"
	echo "should_release=false" >>"$GITHUB_OUTPUT"
	exit 0
fi

delim="NIPAH_$(openssl rand -hex 8 2>/dev/null || echo "${RANDOM}_${RANDOM}_$$")"
{
	echo "should_release=true"
	echo "upstream_sha=$sha"
	echo "release_tag=$tag"
	echo "is_prerelease=$pre"
	echo "release_name=$title"
	echo "release_body<<$delim"
	echo "$body"
	echo "$delim"
} >>"$GITHUB_OUTPUT"
