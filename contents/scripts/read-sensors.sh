#!/usr/bin/env bash

SCRIPT_DIRECTORY=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)

exec python3 "$SCRIPT_DIRECTORY/read-sensors.py"