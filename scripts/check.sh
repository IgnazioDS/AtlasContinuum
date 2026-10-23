#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ADDON_ROOT="$PROJECT_ROOT/WorldPane"
TOC="$ADDON_ROOT/WorldPane_Mainline.toc"
MIGRATION_ROOT="$PROJECT_ROOT/AtlasContinuum"
MIGRATION_TOC="$MIGRATION_ROOT/AtlasContinuum_Mainline.toc"

failures=0

if [ ! -f "$TOC" ]; then
	echo "ERROR: missing $TOC" >&2
	exit 1
fi

while IFS= read -r entry || [ -n "$entry" ]; do
	case "$entry" in
		''|'#'*) continue ;;
	esac
	path=$(printf '%s' "$entry" | tr '\\' '/')
	if [ ! -f "$ADDON_ROOT/$path" ]; then
		echo "ERROR: TOC entry does not exist: $path" >&2
		failures=$((failures + 1))
	fi
done < "$TOC"

if ! grep -Fq '## Interface: 120105' "$TOC"; then
	echo "ERROR: unexpected or missing Retail interface version" >&2
	failures=$((failures + 1))
fi

if ! grep -Fq 'Data\Retail\Client.lua' "$TOC"; then
	echo "ERROR: Retail client data is not selected" >&2
	failures=$((failures + 1))
fi

if ! grep -Fq '## Title: |cffe6b85cWorld|rPane' "$TOC" \
	|| ! grep -Fq '## SavedVariables: WorldPaneDB, WorldPaneLabDB' "$TOC" \
	|| ! grep -Fq 'Map\QuestBridge.lua' "$TOC"; then
	echo "ERROR: WorldPane identity or quest bridge is missing from the TOC" >&2
	failures=$((failures + 1))
fi

if [ ! -f "$MIGRATION_TOC" ] \
	|| ! grep -Fq '## LoadOnDemand: 1' "$MIGRATION_TOC" \
	|| ! grep -Fq '## SavedVariables: AtlasContinuumDB, AtlasContinuumLabDB' "$MIGRATION_TOC"; then
	echo "ERROR: the one-time legacy settings migration helper is missing or unsafe" >&2
	failures=$((failures + 1))
fi

if [ ! -f "$ADDON_ROOT/Media/Brand/Icon.tga" ] || [ ! -f "$ADDON_ROOT/NOTICE.md" ]; then
	echo "ERROR: branded icon or bundled attribution notice is missing" >&2
	failures=$((failures + 1))
fi

if grep -Eq '^## X-Curse-Project-ID:' "$TOC"; then
	echo "ERROR: manifest must not target the upstream CurseForge project" >&2
	failures=$((failures + 1))
fi

if grep -Fq 'Data\Forever\' "$TOC"; then
	echo "ERROR: Forever data is loaded by the Retail TOC" >&2
	failures=$((failures + 1))
fi

if grep -Eq '_G\.OpenMap[[:space:]]*=|^[[:space:]]*OpenMap(DB|CharDB|API|RetailLab)[[:space:]]*=' \
	"$ADDON_ROOT/Core.lua" "$ADDON_ROOT/API.lua" "$ADDON_ROOT/RetailLab/Audit.lua"; then
	echo "ERROR: upstream public globals remain in WorldPane runtime files" >&2
	failures=$((failures + 1))
fi

lua_compiler=''
for candidate in luac5.1 luac; do
	if command -v "$candidate" >/dev/null 2>&1; then
		lua_compiler=$candidate
		break
	fi
done

if [ -n "$lua_compiler" ]; then
	while IFS= read -r lua_file; do
		if ! "$lua_compiler" -p "$lua_file"; then
			failures=$((failures + 1))
		fi
	done <<EOF
$(find "$ADDON_ROOT" "$MIGRATION_ROOT" -type f -name '*.lua' -print | sort)
EOF
else
	echo "INFO: luac not installed; skipped Lua bytecode syntax check"
fi

lua_runtime=''
for candidate in lua5.1 lua; do
	if command -v "$candidate" >/dev/null 2>&1; then
		lua_runtime=$candidate
		break
	fi
done

if [ -n "$lua_runtime" ]; then
	if ! "$lua_runtime" "$PROJECT_ROOT/tests/audit_spec.lua" "$ADDON_ROOT/RetailLab/Audit.lua"; then
		failures=$((failures + 1))
	fi
	if ! "$lua_runtime" "$PROJECT_ROOT/tests/quest_bridge_spec.lua" "$ADDON_ROOT/Map/QuestBridge.lua"; then
		failures=$((failures + 1))
	fi
	if ! "$lua_runtime" "$PROJECT_ROOT/tests/retail_policy_spec.lua" "$ADDON_ROOT/Data/Retail/Client.lua"; then
		failures=$((failures + 1))
	fi
	if ! "$lua_runtime" "$PROJECT_ROOT/tests/migration_spec.lua" "$ADDON_ROOT/Migration.lua"; then
		failures=$((failures + 1))
	fi
else
	echo "INFO: lua not installed; skipped Retail audit, map policy and quest bridge behavior tests"
fi

if [ "$failures" -ne 0 ]; then
	echo "FAILED: $failures validation error(s)" >&2
	exit 1
fi

lua_count=$(find "$ADDON_ROOT" -type f -name '*.lua' | wc -l | tr -d ' ')
asset_count=$(find "$ADDON_ROOT/Media" -type f | wc -l | tr -d ' ')
echo "OK: WorldPane identity, TOCs, settings migration, Retail selection, audit, map policy and quest bridge behavior, $lua_count Lua files, and $asset_count media files validated"
