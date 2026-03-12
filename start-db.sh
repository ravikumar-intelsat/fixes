#!/usr/bin/env bash
# Start PostgreSQL test DB in Docker.
# Usage: ./start-db.sh
# Run migrations/tests separately with run-migrations-and-tests.sh (assumes DB is up).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON=$(command -v python3 || command -v python)
[[ -z "$PYTHON" ]] && { echo "python/python3 not found."; exit 1; }

if [[ -f .env ]]; then
  set -a
  source <(grep -v '^#' .env | grep -v '^$' | tr -d '\r')
  set +a
fi
export DB_PORT=${DB_PORT:-5433}

docker rm -f gateway_swap_test_db 2>/dev/null || true
docker network create arc_geo_dev_net 2>/dev/null || true
DB_PORT=$DB_PORT docker compose -f compose.yml --profile test-integration up -d gateway_swap_test_db

echo "Waiting for PostgreSQL on localhost:${DB_PORT}..."
sleep 5
for i in $(seq 1 60); do
  if $PYTHON -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(3)
try: s.connect(('127.0.0.1', $DB_PORT)); s.close(); exit(0)
except: exit(1)
" 2>/dev/null; then
    echo "PostgreSQL ready on localhost:${DB_PORT}"
    exit 0
  fi
  if [[ $i -eq 60 ]]; then
    echo "PostgreSQL not reachable. Container logs:"
    docker logs --tail 30 gateway_swap_test_db 2>&1
    exit 1
  fi
  sleep 1
done
