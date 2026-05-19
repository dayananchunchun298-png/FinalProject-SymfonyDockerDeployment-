#!/bin/bash
set -e

export PORT="${PORT:-80}"

echo "Rendering Nginx configuration (PORT=${PORT})..."
envsubst '${PORT}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

echo "Waiting for database..."
attempt=0
max_attempts=30
until php bin/console doctrine:query:sql "SELECT 1" >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$max_attempts" ]; then
        echo "Database not reachable after ${max_attempts} attempts."
        exit 1
    fi
    echo "Database unavailable - retrying (${attempt}/${max_attempts})..."
    sleep 2
done
echo "Database is ready."

echo "Running database migrations..."
php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration

if [ "${APP_ENV}" = "prod" ]; then
    echo "Warming production cache..."
    php bin/console cache:warmup --env=prod
fi

echo "Starting PHP-FPM..."
php-fpm -F &
PHP_PID=$!

echo "Waiting for PHP-FPM to start..."
sleep 2

echo "Starting Nginx..."
nginx -g "daemon off;" &
NGINX_PID=$!

wait -n "$PHP_PID" "$NGINX_PID"
exit $?
