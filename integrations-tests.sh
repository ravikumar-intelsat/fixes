#!/usr/bin/env bash
# Run migrations and tests in venv (no Docker for app).
# Usage: ./run-migrations-and-tests.sh
# Requires: venv activated, DB running (run ./start-db.sh first).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON=$(command -v python3 || command -v python)
[[ -z "$PYTHON" ]] && { echo "python/python3 not found. Activate venv or install Python."; exit 1; }

# Load .env for Config (integration tests need full config)
if [[ -f .env ]]; then
  set -a
  source <(tr -d '\r' < .env)
  set +a
fi
export DB_HOST=localhost DB_NAME=gateway_swap_test DB_USERNAME=postgres DB_PASSWORD=postgres DB_PORT=${DB_PORT:-5433} PYTHONPATH=src

mkdir -p test-results

# Install deps from requirements.txt
$PYTHON -m pip install -q -r requirements.txt

# PYTHONPATH=src fixes gateway_swap imports
$PYTHON alembic/create_database.py

$PYTHON -m alembic upgrade head

$PYTHON -m pytest -v \
  --junitxml=./test-results/test-results.xml \
  --no-cov-on-fail \
  --cov=gateway_swap \
  --cov-report xml:./test-results/cov.xml \
  tests/
