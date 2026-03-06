#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Python Tests ==="
python3 -m unittest discover -s "$DIR" -p "test_*.py" -v

echo ""
echo "=== Shell Tests ==="
bash "$DIR/test_config_functions.sh"
bash "$DIR/test_url_parsing.sh"

echo ""
echo "All tests passed."
