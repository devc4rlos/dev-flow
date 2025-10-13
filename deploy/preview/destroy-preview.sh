#!/bin/bash
set -euo pipefail

: "${PR_NUMBER:?The PR_NUMBER variable has not been set.}"
: "${PROJECT_DIR:?The PROJECT_DIR variable has not been set.}"
: "${PROJECT_NAME:?The PROJECT_NAME variable has not been set.}"

export SERVICE_NAME="${PROJECT_NAME}-pr-${PR_NUMBER}"
export HOSTNAME="${PROJECT_NAME}-pr-${PR_NUMBER}.preview.carlosalexandre.com.br"
export ROUTER_NAME="${PROJECT_NAME}-pr-${PR_NUMBER}"

echo "Starting teardown of environment for PR #${PR_NUMBER}..."

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Project directory ${PROJECT_DIR} not found. Nothing to do."
  exit 0
fi

cd "${PROJECT_DIR}"

echo "--- State before removal ---"
docker compose -f compose.preview.yaml -p "${SERVICE_NAME}" ps -a || true

echo "--- Final logs (last 200) ---"
docker compose -f compose.preview.yaml -p "${SERVICE_NAME}" logs --no-color --tail=200 || true

echo "Shutting down stack and removing volumes..."
docker compose -f compose.preview.yaml -p "${SERVICE_NAME}" down -v --remove-orphans || true

echo "Removing project directory..."
cd ..
rm -rf "${PROJECT_DIR}"

echo "Removing Docker images labeled with this PR on the server..."
IMAGES_TO_DELETE=$(docker images -q --filter "label=br.com.carlosalexandre.preview.pr-${ROUTER_NAME}=${PR_NUMBER}")
if [ -n "$IMAGES_TO_DELETE" ]; then
  docker rmi "$IMAGES_TO_DELETE" || true
else
  echo "No Docker images with the PR label found."
fi

echo "Cleaning up dangling images and local cache..."
docker image prune -f || true
docker builder prune -f || true

echo "Removing project networks..."
for NET in $(docker network ls --format '{{.Name}}' | grep "^${SERVICE_NAME}"); do
  if [ "$NET" != "proxy" ]; then
    docker network rm "$NET" || true
  fi
done

echo "✅ PR environment #${PR_NUMBER} successfully destroyed."
