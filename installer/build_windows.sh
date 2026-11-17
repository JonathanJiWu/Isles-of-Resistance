#!/usr/bin/env bash
# Builds the Windows release of Isles of Resistance for x64 and ARM64:
#   dist/IslesOfResistance-Setup-x64.exe     installer, Intel/AMD 64-bit
#   dist/IslesOfResistance-Setup-ARM64.exe   installer, Windows on ARM
#   dist/IslesOfResistance-Windows-x64.zip   no-install zip
#   dist/IslesOfResistance-Windows-ARM64.zip no-install zip
#   dist/SHA256SUMS.txt
#
# usage: GODOT=/path/to/godot installer/build_windows.sh [version]
#
# Needs: Godot 4.4.1 with its export templates installed, makensis (NSIS 3),
# Node.js 18+, zip and python3. Runs on Linux, macOS, or Windows with Git Bash.
# The version defaults to application/config/version in project.godot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WIN="$ROOT/installer/windows"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
GODOT="${GODOT:-godot}"
VERSION="${1:-$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$ROOT/project.godot")}"
VERSION="${VERSION#v}"

say() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 1.2.3 (got '$VERSION')"
for tool in "$GODOT" makensis node npm zip python3; do
	command -v "$tool" >/dev/null || die "'$tool' not found"
done

say "Isles of Resistance $VERSION for Windows (Godot $("$GODOT" --version))"
rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD" "$DIST"

say "Installing the resource stamper"
(cd "$WIN" && npm ci --no-audit --no-fund --loglevel=error)

say "Importing project"
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true

say "Writing license notices"
"$GODOT" --headless --path "$ROOT" -s "$WIN/notices.gd" -- \
	"$BUILD/THIRD-PARTY-NOTICES.txt" "$ROOT/Assets/fonts/OFL.txt" >/dev/null 2>&1
grep -q "Godot Engine" "$BUILD/THIRD-PARTY-NOTICES.txt" || die "notices were not generated"

build_arch() {
	local arch="$1" archname="$2" preset="$3"
	local out="$BUILD/windows-$arch"
	mkdir -p "$out"

	say "Exporting $preset"
	local log="$BUILD/export-$arch.log"
	if ! "$GODOT" --headless --path "$ROOT" --export-release "$preset" "$out/IslesOfResistance.exe" >"$log" 2>&1; then
		tail -40 "$log"; die "export of $preset failed"
	fi
	if grep -E "^(ERROR|SCRIPT ERROR)" "$log"; then die "export of $preset reported errors (see $log)"; fi
	[[ -s "$out/IslesOfResistance.exe" && -s "$out/IslesOfResistance.pck" ]] || die "export of $preset produced no game files"

	node "$WIN/stamp_exe.mjs" "$out/IslesOfResistance.exe" "$WIN/icon.ico" "$VERSION" "$arch"
	cp "$ROOT/LICENSE" "$out/LICENSE.txt"
	cp "$BUILD/THIRD-PARTY-NOTICES.txt" "$out/THIRD-PARTY-NOTICES.txt"

	say "Building installer ($archname)"
	makensis -V2 -INPUTCHARSET UTF8 \
		-DARCH="$arch" -DVERSION="$VERSION" -DSRCDIR="$out" \
		-DOUTFILE="$DIST/IslesOfResistance-Setup-$archname.exe" \
		"$WIN/IslesOfResistance.nsi"

	say "Packing zip ($archname)"
	local stage="$BUILD/zip-$arch/Isles of Resistance"
	mkdir -p "$stage"
	cp "$out"/IslesOfResistance.exe "$out"/IslesOfResistance.pck "$out"/LICENSE.txt "$out"/THIRD-PARTY-NOTICES.txt "$stage/"
	(cd "$BUILD/zip-$arch" && zip -q -9 -r "$DIST/IslesOfResistance-Windows-$archname.zip" "Isles of Resistance")
}

build_arch x64 x64 "Windows x64"
build_arch arm64 ARM64 "Windows ARM64"

say "Checksums"
(cd "$DIST" && python3 - <<'EOF'
import hashlib, os
names = sorted(n for n in os.listdir(".") if n != "SHA256SUMS.txt")
with open("SHA256SUMS.txt", "w", newline="\n") as f:
    for n in names:
        h = hashlib.sha256(open(n, "rb").read()).hexdigest()
        f.write(f"{h}  {n}\n")
EOF
)
cat "$DIST/SHA256SUMS.txt"
ls -lh "$DIST"
