#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE="$PROJECT_ROOT/AtlasContinuum"
retail_dir=${1:-}

if [ -z "$retail_dir" ] && command -v mdfind >/dev/null 2>&1; then
	retail_dir=$(mdfind 'kMDItemFSName == "_retail_"c' | head -n 1)
fi

if [ -z "$retail_dir" ]; then
	echo 'ERROR: Retail client not found. Run make install RETAIL_DIR="/path/to/_retail_"' >&2
	exit 1
fi

addons="$retail_dir/Interface/AddOns"
destination="$addons/AtlasContinuum"

if [ ! -d "$addons" ]; then
	echo "ERROR: AddOns directory does not exist: $addons" >&2
	exit 1
fi

if [ -L "$destination" ]; then
	current=$(readlink "$destination")
	if [ "$current" = "$SOURCE" ]; then
		echo "Already installed: $destination -> $SOURCE"
		exit 0
	fi
	echo "ERROR: refusing to replace existing symlink: $destination -> $current" >&2
	exit 1
fi

if [ -e "$destination" ]; then
	echo "ERROR: refusing to replace existing addon: $destination" >&2
	exit 1
fi

ln -s "$SOURCE" "$destination"
echo "Installed development link: $destination -> $SOURCE"
