#!/usr/bin/env bash
set -euo pipefail

: "${UPSTREAM_SHA:?}"
UPSTREAM="${UPSTREAM:-https://git.sr.ht/~xerool/fennel-ls}"
LUA_VERSION="${LUA_VERSION:-5.5.0}"

sys=$(uname -s)
mach=$(uname -m)
j=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)

curl -fsSL -o "lua-$LUA_VERSION.tar.gz" "https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz"
tar xzf "lua-$LUA_VERSION.tar.gz"

git clone "$UPSTREAM" fennel-ls
git -C fennel-ls checkout --detach "$UPSTREAM_SHA"

build_lua() {
	local builddir=$1 plat=$2 cc=$3
	cp -a "lua-$LUA_VERSION" "$builddir"
	make -C "$builddir" -j"$j" "$plat" CC="$cc"
}

compile() {
	local lua_bin=$1 lua_dir=$2 cc=$3 out=$4
	(
		cd fennel-ls
		CC="$cc" "$lua_bin" fennel \
			--add-macro-path "src/?.fnlm" \
			--add-fennel-path "src/?.fnl;deps/?.fnl" \
			--add-package-path "deps/?.lua" \
			--skip-include "fennel.compiler,fennel.specials" \
			--compile-binary src/fennel-ls.fnl "$out" \
			"$lua_dir/liblua.a" "$lua_dir"
	) >&2
	local built="fennel-ls/$out"
	[ -f "$built" ] || built="fennel-ls/${out}.exe"
	echo "$built"
}

assets=()
case "$sys" in
	Linux)
		sudo apt-get update -qq
		sudo apt-get install -y -qq build-essential libreadline-dev
		build_lua lua-native linux gcc
		lua_dir=$(cd lua-native/src && pwd)
		asset=fennel-ls-x86_64-unknown-linux-gnu
		built=$(compile "$lua_dir/lua" "$lua_dir" gcc out)
		cp "$built" "$asset"
		"./$asset" --version
		assets+=("$asset")
		;;
	Darwin)
		build_lua lua-native macosx cc
		lua_dir=$(cd lua-native/src && pwd)
		lua_bin=$lua_dir/lua

		case "$mach" in
			arm64) native_asset=fennel-ls-aarch64-apple-darwin ;;
			*)     native_asset=fennel-ls-x86_64-apple-darwin ;;
		esac
		built=$(compile "$lua_bin" "$lua_dir" cc out-native)
		cp "$built" "$native_asset"
		"./$native_asset" --version
		assets+=("$native_asset")

		if [ "$mach" = arm64 ]; then
			cross_arch=x86_64
			cross_asset=fennel-ls-x86_64-apple-darwin
		else
			cross_arch=arm64
			cross_asset=fennel-ls-aarch64-apple-darwin
		fi
		build_lua "lua-$cross_arch" macosx "cc -arch $cross_arch"
		xdir=$(cd "lua-$cross_arch/src" && pwd)
		built=$(compile "$lua_bin" "$xdir" "cc -arch $cross_arch" out-cross)
		cp "$built" "$cross_asset"
		file "$cross_asset"
		file "$cross_asset" | grep -q "$cross_arch" \
			|| { echo "cross build produced wrong arch" >&2; exit 1; }
		assets+=("$cross_asset")
		;;
	MINGW*|MSYS*|CYGWIN*)
		build_lua lua-native mingw gcc
		lua_dir=$(cd lua-native/src && pwd)
		asset=fennel-ls-x86_64-pc-windows-gnu.exe
		built=$(compile "$lua_dir/lua.exe" "$lua_dir" gcc out)
		cp "$built" "$asset"
		"./$asset" --version
		assets+=("$asset")
		;;
	*)
		echo "unsupported: $sys $mach" >&2
		exit 1
		;;
esac

{
	echo "asset<<ASSET_EOF"
	printf '%s\n' "${assets[@]}"
	echo "ASSET_EOF"
} >>"${GITHUB_OUTPUT:-/dev/null}"
