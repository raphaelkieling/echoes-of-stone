#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/dist/desktop"
CACHE_DIR="$ROOT_DIR/dist/.love-runtime-cache"
STAGING_DIR="$(mktemp -d)"
GAME_NAME="Echoes of Stone"
LOVE_VERSION="11.5"
GAME_DIR="$STAGING_DIR/game"
GAME_LOVE="$STAGING_DIR/$GAME_NAME.love"
TARGET="${1:-all}"
trap 'rm -rf "$STAGING_DIR"' EXIT

if [[ "$TARGET" != "all" && "$TARGET" != "windows" && "$TARGET" != "macos" ]]; then
	echo "Usage: $0 [all|windows|macos]" >&2
	exit 2
fi

mkdir -p "$GAME_DIR" "$CACHE_DIR" "$BUILD_ROOT"
cp -R "$ROOT_DIR/assets" "$ROOT_DIR/maps" "$ROOT_DIR/src" "$ROOT_DIR/vendor" \
	"$ROOT_DIR/main.lua" "$ROOT_DIR/conf.lua" "$GAME_DIR/"

# Keep developer-only console and overlays out of distributed builds.
sed 's/developmentMode = true/developmentMode = false/' \
	"$GAME_DIR/src/settings/BuildConfig.lua" \
	> "$GAME_DIR/src/settings/BuildConfig.lua.tmp"
mv "$GAME_DIR/src/settings/BuildConfig.lua.tmp" \
	"$GAME_DIR/src/settings/BuildConfig.lua"

(cd "$GAME_DIR" && zip -9 -qr "$GAME_LOVE" .)

download_if_missing() {
	local url="$1"
	local destination="$2"
	if [[ ! -f "$destination" ]]; then
		curl --fail --location --silent --show-error "$url" --output "$destination"
	fi
}

build_windows() {
	local runtime_zip="$CACHE_DIR/love-$LOVE_VERSION-win64.zip"
	local runtime_dir="$STAGING_DIR/windows-runtime"
	local output_dir="$BUILD_ROOT/windows"
	local package_dir="$STAGING_DIR/windows-package"
	local url="https://github.com/love2d/love/releases/download/$LOVE_VERSION/love-$LOVE_VERSION-win64.zip"

	download_if_missing "$url" "$runtime_zip"
	mkdir -p "$runtime_dir" "$package_dir"
	ditto -x -k "$runtime_zip" "$runtime_dir"
	local love_exe
	love_exe="$(find "$runtime_dir" -type f -iname love.exe -print -quit)"
	if [[ -z "$love_exe" ]]; then
		echo "Could not find love.exe in the official Windows runtime archive." >&2
		exit 1
	fi
	cp -R "$(dirname "$love_exe")"/. "$package_dir/"
	cat "$love_exe" "$GAME_LOVE" > "$package_dir/$GAME_NAME.exe"
	rm -f "$package_dir/love.exe"
	rm -rf "$output_dir"
	mkdir -p "$output_dir"
	cp -R "$package_dir"/. "$output_dir/"
	(cd "$output_dir" && zip -9 -qr "$BUILD_ROOT/echoes-of-stone-windows-x64.zip" .)
	echo "Windows x64 build: $BUILD_ROOT/echoes-of-stone-windows-x64.zip"
}

build_macos() {
	local runtime_zip="$CACHE_DIR/love-$LOVE_VERSION-macos.zip"
	local runtime_dir="$STAGING_DIR/macos-runtime"
	local output_dir="$BUILD_ROOT/macos"
	local app_path="$output_dir/$GAME_NAME.app"
	local url="https://github.com/love2d/love/releases/download/$LOVE_VERSION/love-$LOVE_VERSION-macos.zip"

	download_if_missing "$url" "$runtime_zip"
	mkdir -p "$runtime_dir"
	ditto -x -k "$runtime_zip" "$runtime_dir"
	local love_app
	love_app="$(find "$runtime_dir" -type d -name love.app -print -quit)"
	if [[ -z "$love_app" ]]; then
		echo "Could not find love.app in the official macOS runtime archive." >&2
		exit 1
	fi
	rm -rf "$output_dir"
	mkdir -p "$output_dir"
	ditto "$love_app" "$app_path"
	cp "$GAME_LOVE" "$app_path/Contents/Resources/$GAME_NAME.love"
	local plist="$app_path/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.echoesofstone.game' "$plist"
	/usr/libexec/PlistBuddy -c 'Set :CFBundleName Echoes of Stone' "$plist"
	/usr/libexec/PlistBuddy -c 'Delete :UTExportedTypeDeclarations' "$plist" >/dev/null 2>&1 || true
	ditto -c -k --sequesterRsrc --keepParent "$app_path" \
		"$BUILD_ROOT/echoes-of-stone-macos.zip"
	echo "macOS app: $app_path"
	echo "macOS ZIP: $BUILD_ROOT/echoes-of-stone-macos.zip"
}

if [[ "$TARGET" == "all" || "$TARGET" == "windows" ]]; then build_windows; fi
if [[ "$TARGET" == "all" || "$TARGET" == "macos" ]]; then build_macos; fi
