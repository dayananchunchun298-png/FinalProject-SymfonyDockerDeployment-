#!/bin/bash
set -e

export PORT="${PORT:-80}"

echo "Rendering Nginx configuration (PORT=${PORT})..."
envsubst '${PORT}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

run_db_setup() {
    echo "Waiting for database..."
    attempt=0
    max_attempts=90
    until php bin/console doctrine:query:sql "SELECT 1" >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ "$attempt" -ge "$max_attempts" ]; then
            echo "WARNING: Database not reachable after ${max_attempts} attempts."
            echo "The web app will still run — check DATABASE_URL on Railway."
            return 1
        fi
        echo "Database unavailable - retrying (${attempt}/${max_attempts})..."
        sleep 2
    done

    echo "Database is ready."
    php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration || echo "Migration warning (non-fatal)"
    if [ "${APP_ENV}" = "prod" ]; then
        php bin/console cache:warmup --env=prod || echo "Cache warmup warning (non-fatal)"
    fi
    return 0
}

# Run DB setup in background — Railway needs HTTP up quickly on $PORT
run_db_setup &

echo "Starting PHP-FPM..."
php-fpm -D

echo "Starting Nginx on 0.0.0.0:${PORT}..."
exec nginx -g "daemon off;"
