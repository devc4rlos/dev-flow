#!/bin/bash
set -euo pipefail

echo "🚀 Deploying image: $IMAGE_TAG"

docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" pull app

docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" up -d --pull=always --remove-orphans

docker compose -f "${COMPOSE_FILE}" -p "${SERVICE_NAME}" up -d --no-deps nginx --force-recreate

docker compose -f "${COMPOSE_FILE}" exec -T app php artisan migrate --force

docker image prune -af

echo "✅ Deployment of $IMAGE_TAG finished successfully!"