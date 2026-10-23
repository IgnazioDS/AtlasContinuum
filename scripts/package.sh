#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TOC="$PROJECT_ROOT/WorldPane/WorldPane_Mainline.toc"
DIST="$PROJECT_ROOT/dist"

"$PROJECT_ROOT/scripts/check.sh"

version=$(sed -n 's/^## Version: //p' "$TOC" | head -n 1 | tr -d '\r' | tr -c 'A-Za-z0-9._+-' '-' | sed 's/-$//')
if [ -z "$version" ]; then
	echo "ERROR: version not found in $TOC" >&2
	exit 1
fi

mkdir -p "$DIST"
artifact="$DIST/WorldPane-$version.zip"
temporary="$DIST/.WorldPane-$version.$$.tmp.zip"

(
	cd "$PROJECT_ROOT"
	zip -qr "$temporary" WorldPane AtlasContinuum -x '*/.DS_Store'
)

unzip -tq "$temporary" >/dev/null
if ! unzip -Z1 "$temporary" | grep -Fqx 'WorldPane/WorldPane_Mainline.toc' \
	|| ! unzip -Z1 "$temporary" | grep -Fqx 'AtlasContinuum/AtlasContinuum_Mainline.toc'; then
	echo "ERROR: package roots are incomplete" >&2
	rm -f "$temporary"
	exit 1
fi
mv -f "$temporary" "$artifact"
echo "$artifact"
