#!/bin/bash
set -euo pipefail

: "${SERVICE_NAME:?The SERVICE_NAME variable has not been set.}"
: "${HOSTNAME:?The HOSTNAME variable has not been set.}"
: "${ROUTER_NAME:?The ROUTER_NAME variable has not been set.}"
: "${IMAGE_NAME:?The IMAGE_NAME variable has not been set.}"
: "${LABEL_PREVIEW:?The LABEL_PREVIEW variable has not been set.}"
: "${PROJECT_NAME:?The PROJECT_NAME variable has not been set.}"
: "${FIRST_PREVIEW:?The FIRST_PREVIEW variable has not been set.}"

trap 'echo "--- docker compose ps ---"; docker compose -f compose.preview.yaml -p ${SERVICE_NAME} ps || true; echo "--- docker compose logs (last 200 lines) ---"; docker compose -f compose.preview.yaml -p ${SERVICE_NAME} logs --no-color --tail=200 || true' ERR

if $FIRST_PREVIEW; then
  cp .env.preview .env
  sed -i "s#^APP_URL=.*#APP_URL=https://${HOSTNAME}#" .env

  KEY=$(openssl rand -base64 32 | sed 's/^/base64:/')
  sed -i "s#^APP_KEY=.*#APP_KEY=${KEY}#" .env

  ln -s ~/.htpasswd ./docker/nginx/.htpasswd || true
fi

docker compose -f compose.preview.yaml -p "${SERVICE_NAME}" pull app

echo "Starting containers with image ${IMAGE_NAME}..."
docker compose -f compose.preview.yaml -p "${SERVICE_NAME}" up -d --wait --pull=always

docker compose -f compose.preview.yaml -p "${SERVICE_NAME}" up -d --no-deps nginx --force-recreate

echo "Running migrations..."
if ! docker compose -f compose.preview.yaml -p "${SERVICE_NAME}" exec -T app php artisan migrate:fresh --seed --force; then
  echo "Migrations failed, retrying in 5s..."
  sleep 5
  docker compose -f compose.preview.yaml -p "${SERVICE_NAME}" exec -T app php artisan migrate:fresh --seed --force
fi
echo "✅ Migrations completed."

docker compose -f compose.preview.yaml -p "${SERVICE_NAME}" exec -T app php artisan app:create-admin-user

echo "Checking HTTP readiness for https://${HOSTNAME}/health ..."
READY_TIMEOUT=120
while true; do
  HTTP_CODE=$(curl -k -sS -o /dev/null -w "%{http_code}" --max-time 5 "https://${HOSTNAME}/health")
  if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✅ Readiness OK (200) at ${HOSTNAME}."
    break
  else
    sleep 2
    READY_TIMEOUT=$((READY_TIMEOUT-2))
    if [ $READY_TIMEOUT -le 0 ]; then
      echo "Error: HTTP readiness not achieved. Last code: ${HTTP_CODE}" >&2
      exit 1
    fi
  fi
done

echo "✅ Preview environment deployed successfully!"
