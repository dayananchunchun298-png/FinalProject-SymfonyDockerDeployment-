#!/bin/bash

# Railway injects PORT — default 8080 if missing
export PORT="${PORT:-8080}"

# Railway MySQL provides MYSQL_URL; Symfony needs DATABASE_URL
if [ -z "$DATABASE_URL" ] && [ -n "$MYSQL_URL" ]; then
    export DATABASE_URL="$MYSQL_URL"
    echo "Using MYSQL_URL as DATABASE_URL"
fi
if [ -z "$DATABASE_URL" ] && [ -n "$MYSQL_PRIVATE_URL" ]; then
    export DATABASE_URL="$MYSQL_PRIVATE_URL"
    echo "Using MYSQL_PRIVATE_URL as DATABASE_URL"
fi
if [ -n "$DATABASE_URL" ] && [[ "$DATABASE_URL" != *"serverVersion"* ]]; then
    if [[ "$DATABASE_URL" == *"?"* ]]; then
        export DATABASE_URL="${DATABASE_URL}&serverVersion=8.0.32&charset=utf8mb4"
    else
        export DATABASE_URL="${DATABASE_URL}?serverVersion=8.0.32&charset=utf8mb4"
    fi
fi

echo "=========================================="
echo " Starting Symfony (PORT=${PORT})"
if [ -n "$DATABASE_URL" ]; then
    echo " DATABASE_URL is set"
else
    echo " WARNING: DATABASE_URL is NOT set — add it on Railway"
fi
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

echo "Starting PHP-FPM..."
if ! php-fpm -D 2>&1; then
    echo "php-fpm -D failed, trying --daemonize..."
    php-fpm --daemonize 2>&1 || {
        echo "ERROR: PHP-FPM could not start"
        exit 1
    }
fi

# DB setup after web server is up — avoids slowing Railway health checks
( sleep 5 && run_db_setup ) &

echo "Starting Nginx on 0.0.0.0:${PORT} ..."
exec nginx -g "daemon off;"
