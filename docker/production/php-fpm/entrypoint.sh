#!/bin/sh
set -e

# Worker mode
if [ "$IS_WORKER" = "true" ]; then
  echo "Starting queue worker..."
  exec php artisan queue:work --sleep=3 --tries=3 --max-time=3600
fi

# Initialize storage directory if empty
if [ ! "$(ls -A /var/www/storage)" ]; then
  echo "Initializing storage directory..."
  cp -R /var/www/storage-init/. /var/www/storage
  chown -R www-data:www-data /var/www/storage
fi

rm -rf /var/www/storage-init

# Run migrations
php artisan migrate --force

# Cache configs
php artisan config:cache
php artisan route:cache

# Run php-fpm
exec "$@"