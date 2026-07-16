#!/usr/bin/env bash

set -euo pipefail

ROOT_DIRECTORY=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." &&
    pwd -P
)

cd "$ROOT_DIRECTORY"

VERSION=$(
    python3 - <<'PY'
import json
from pathlib import Path

metadata = json.loads(Path("metadata.json").read_text(encoding="utf-8"))
print(metadata["KPlugin"]["Version"])
PY
)

PACKAGE_NAME="plasma-hardware-sensors-${VERSION}.plasmoid"
PACKAGE_PATH="dist/${PACKAGE_NAME}"

mkdir -p dist
rm -f "$PACKAGE_PATH" "${PACKAGE_PATH}.sha256"

zip -qr "$PACKAGE_PATH" \
    metadata.json \
    contents \
    README.md \
    CHANGELOG.md \
    LICENSE \
    -x '*/__pycache__/*' '*.pyc'

(
    cd dist
    sha256sum "$PACKAGE_NAME" > "${PACKAGE_NAME}.sha256"
)

echo "$PACKAGE_PATH"
