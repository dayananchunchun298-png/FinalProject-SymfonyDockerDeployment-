# syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# Stage 1: Install PHP dependencies with Composer
# -----------------------------------------------------------------------------
FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock symfony.lock ./

RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --ignore-platform-reqs

COPY . .

RUN composer dump-autoload --classmap-authoritative --no-dev

ENV APP_ENV=prod
ENV APP_DEBUG=0
ENV APP_SECRET=build-time-secret-change-in-production

RUN composer dump-env prod \
    && php bin/console importmap:install --no-interaction \
    && php bin/console cache:clear --env=prod --no-warmup \
    && php bin/console cache:warmup --env=prod \
    && php bin/console asset-map:compile --env=prod

# -----------------------------------------------------------------------------
# Stage 2: Production image (PHP-FPM + Nginx)
# -----------------------------------------------------------------------------
FROM php:8.3-fpm-bookworm AS app

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    gettext-base \
    libicu-dev \
    libzip-dev \
    unzip \
    pkg-config \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j1 intl opcache pdo_mysql zip \
    && rm -rf /var/lib/apt/lists/*

COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

WORKDIR /app

COPY --from=vendor /app /app

COPY nginx-main.conf /etc/nginx/nginx.conf
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p var/cache var/log \
    && chown -R www-data:www-data var public \
    && rm -f /etc/nginx/sites-enabled/default

ENV APP_ENV=prod
ENV APP_DEBUG=0
ENV PORT=80

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
