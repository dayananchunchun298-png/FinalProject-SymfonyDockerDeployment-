#!/bin/bash

# Railway injects PORT — default 8080 if missing
export PORT="${PORT:-8080}"

echo "=========================================="
echo " Starting Symfony (PORT=${PORT})"
echo "=========================================="

mkdir -p /run/php /var/cache/nginx var/log/nginx var/cache var/log
chown -R www-data:www-data var 2>/dev/null || true

echo "Rendering Nginx config..."
envsubst '${PORT}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

if ! nginx -t 2>&1; then
    echo "ERROR: invalid nginx configuration"
    cat /etc/nginx/conf.d/default.conf
    exit 1
fi

run_db_setup() {
    echo "Waiting for database (background)..."
    attempt=0
    max_attempts=90
    until php bin/console doctrine:query:sql "SELECT 1" >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "WARNING: Database not reachable. Set DATABASE_URL on Railway."
            return 1
        fi
        sleep 2
    done
    echo "Database is ready."
    php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration 2>&1 || true
    php bin/console cache:warmup --env=prod 2>&1 || true
}

run_db_setup &

echo "Starting PHP-FPM..."
if ! php-fpm -D 2>&1; then
    echo "php-fpm -D failed, trying --daemonize..."
    php-fpm --daemonize 2>&1 || {
        echo "ERROR: PHP-FPM could not start"
        exit 1
    }
fi

sleep 2

echo "Starting Nginx on 0.0.0.0:${PORT} ..."
exec nginx -g "daemon off;"
