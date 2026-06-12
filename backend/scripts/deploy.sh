#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="root@36.213.128.58"
SSH_KEY="${HOME}/.ssh/mark_six_deploy"
REMOTE_DIR="/opt/new-site"
APP_NAME="new-site"
PORT="8790"

ssh -i "${SSH_KEY}" "${REMOTE_HOST}" "
  set -e
  if ss -lnt | grep -q ':${PORT} '; then
    if ! pm2 describe '${APP_NAME}' >/dev/null 2>&1; then
      echo 'Port ${PORT} is occupied by another process.' >&2
      exit 1
    fi
  fi
  mkdir -p '${REMOTE_DIR}'
"

rsync -az \
  --no-owner \
  --no-group \
  --exclude ".env" \
  --exclude ".venv/" \
  --exclude ".pytest_cache/" \
  --exclude "**/__pycache__/" \
  --exclude "*.egg-info/" \
  --exclude "tests/" \
  -e "ssh -i ${SSH_KEY}" \
  ./ "${REMOTE_HOST}:${REMOTE_DIR}/"

ssh -i "${SSH_KEY}" "${REMOTE_HOST}" "
  set -e
  cd '${REMOTE_DIR}'
  chown -R root:root '${REMOTE_DIR}'
  if [[ ! -f .env ]]; then
    printf '%s\n' \
      'APP_SERVICE_NAME=ai-pc-builder-api' \
      'APP_HOST=0.0.0.0' \
      'APP_PORT=${PORT}' > .env
    chmod 600 .env
  fi
  python3 -m venv .venv
  .venv/bin/python -m pip install --upgrade pip
  .venv/bin/python -m pip install .
  pm2 startOrRestart ecosystem.config.cjs --only '${APP_NAME}'
  pm2 save
"
