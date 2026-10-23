#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOC="$PROJECT_ROOT/AtlasContinuum/AtlasContinuum_Mainline.toc"
DIST="$PROJECT_ROOT/dist"

"$PROJECT_ROOT/scripts/check.sh"

version=$(sed -n 's/^## Version: //p' "$TOC" | head -n 1 | tr -d '\r' | tr -c 'A-Za-z0-9._+-' '-' | sed 's/-$//')
if [ -z "$version" ]; then
	echo "ERROR: version not found in $TOC" >&2
	exit 1
fi

mkdir -p "$DIST"
artifact="$DIST/AtlasContinuum-$version.zip"
temporary="$DIST/.AtlasContinuum-$version.$$.tmp.zip"

(
	cd "$PROJECT_ROOT"
	zip -qr "$temporary" AtlasContinuum -x '*/.DS_Store'
)

unzip -tq "$temporary" >/dev/null
mv -f "$temporary" "$artifact"
echo "$artifact"
