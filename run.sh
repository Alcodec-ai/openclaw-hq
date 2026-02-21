#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

PORT="${OPENCLAW_HQ_PORT:-7843}"

# Check Python
if command -v python3 &>/dev/null; then
    PY=python3
elif command -v python &>/dev/null; then
    PY=python
else
    echo "Python not found. Install Python 3.10+ first."
    exit 1
fi

# Create venv if needed
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    $PY -m venv .venv
fi

# Activate
if [ "$(uname)" = "Darwin" ]; then
    source .venv/bin/activate
else
    source .venv/bin/activate
fi

# Install deps
pip install -q -r requirements.txt

echo ""
echo "  OpenClaw HQ Dashboard"
echo "  http://localhost:${PORT}"
echo ""

python dashboard.py
