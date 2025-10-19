#!/bin/bash
set -euo pipefail

: "${SERVICE_NAME:?The SERVICE_NAME variable has not been set.}"
: "${HOSTNAME:?The HOSTNAME variable has not been set.}"
: "${ROUTER_NAME:?The ROUTER_NAME variable has not been set.}"
: "${IMAGE_NAME:?The IMAGE_NAME variable has not been set.}"
: "${LABEL_PREVIEW:?The LABEL_PREVIEW variable has not been set.}"
: "${PROJECT_NAME:?The PROJECT_NAME variable has not been set.}"

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
IMAGES_TO_DELETE=$(docker images -q --filter "label=${LABEL_PREVIEW}.preview.pr-${ROUTER_NAME}=true")
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
