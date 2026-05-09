#!/bin/bash
set -e

MAIN_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_ACTIVATE="$MAIN_DIR/.venv/bin/activate"

if [ ! -f "$VENV_ACTIVATE" ]; then
  echo "Error: .venv not found. Run install.sh first."
  exit 1
fi

source "$VENV_ACTIVATE"

echo "Starting LeRobot UI at http://localhost:8000"
cd "$MAIN_DIR/src/lerobot/webui"
exec python -m backend.main
