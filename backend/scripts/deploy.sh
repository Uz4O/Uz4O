#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="root@8.152.202.123"
SSH_KEY="${HOME}/.ssh/ai_builder_aliyun"
REMOTE_DIR="/opt/ai-builder-api"
SERVICE_NAME="ai-builder-api"
PORT="8790"

ssh -i "${SSH_KEY}" "${REMOTE_HOST}" "
  set -e
  if ss -lnt | grep -q ':${PORT} '; then
    if ! systemctl is-active --quiet '${SERVICE_NAME}'; then
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
  --exclude "build/" \
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
  systemctl daemon-reload
  systemctl restart '${SERVICE_NAME}'
"
