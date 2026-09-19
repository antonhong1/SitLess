#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh
exec dist/FocusBar.app/Contents/MacOS/FocusBar --show
