#!/bin/sh
set -e

echo "Synchronizing image assets to the shared volume..."
rsync -av --delete /var/www/public_assets/ /var/www/public/
chown -R www-data:www-data /var/www/public

if [ ! -L "/var/www/public/storage" ]; then
    chown -R www-data:www-data /var/www/storage
fi

exec "$@"