#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIRECTORY=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd -P
)

exec python3 "$SCRIPT_DIRECTORY/read-sensors.py"
