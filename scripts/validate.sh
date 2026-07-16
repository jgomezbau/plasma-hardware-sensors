#!/usr/bin/env bash

set -euo pipefail

ROOT_DIRECTORY=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
    pwd -P
)

cd "$ROOT_DIRECTORY"

python3 - <<'PY'
import json
from pathlib import Path

metadata = json.loads(Path("metadata.json").read_text(encoding="utf-8"))
plugin = metadata.get("KPlugin", {})

required_plugin_fields = {
    "Id",
    "Name",
    "Description",
    "Version",
    "License",
}

missing = sorted(
    field for field in required_plugin_fields
    if not str(plugin.get(field, "")).strip()
)

if metadata.get("KPackageStructure") != "Plasma/Applet":
    raise SystemExit("metadata.json: KPackageStructure must be Plasma/Applet")

if missing:
    raise SystemExit(
        "metadata.json: missing KPlugin fields: " + ", ".join(missing)
    )
PY

find contents/scripts tests -name '*.py' -print0 \
    | xargs -0 python3 -m py_compile

python3 -m pytest

SENSOR_JSON=$(mktemp)
trap 'rm -f "$SENSOR_JSON"' EXIT

./contents/scripts/read-sensors.sh > "$SENSOR_JSON"
python3 -m json.tool "$SENSOR_JSON" > /dev/null

if command -v kpackagetool6 > /dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --show . > /dev/null
else
    echo "kpackagetool6 not found; skipping package metadata smoke check"
fi
