#!/usr/bin/env bash
# VidGrab — Production startup script
# Usage: bash start.sh
#
# Optional environment variables:
#   VIDGRAB_PORT       — server port (default: 8000)
#   VIDGRAB_HOST       — bind address (default: 0.0.0.0)
#   VIDGRAB_DOWNLOAD_DIR — download directory (default: ~/Downloads)
#   VIDGRAB_ADS_CONFIG — ads config file path (default: ./ads_config.json)
#   VIDGRAB_DOWNLOAD_LOG — download log file path (default: ./downloads_log.json)

set -e

PORT="${VIDGRAB_PORT:-8000}"
HOST="${VIDGRAB_HOST:-0.0.0.0}"
WORKERS="${VIDGRAB_WORKERS:-4}"

cd "$(dirname "$0")"

echo "==> Installing Python dependencies..."
pip install -q -r backend/requirements.txt

echo "==> Starting VidGrab server on $HOST:$PORT..."
exec gunicorn \
  -k uvicorn.workers.UvicornWorker \
  --bind "$HOST:$PORT" \
  --workers "$WORKERS" \
  --max-requests 10000 \
  --max-requests-jitter 2000 \
  --access-logfile - \
  --error-logfile - \
  --timeout 120 \
  backend.main:app
