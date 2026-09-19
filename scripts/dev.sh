#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build.sh
exec dist/SitLess.app/Contents/MacOS/SitLess --show
