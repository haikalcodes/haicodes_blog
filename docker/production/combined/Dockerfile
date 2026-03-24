# ============================================
# Stage 1: Composer dependencies
# ============================================
FROM php:8.5-fpm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip libpq-dev libonig-dev libssl-dev \
    libxml2-dev libcurl4-openssl-dev libicu-dev libzip-dev \
    && docker-php-ext-install -j$(nproc) pdo_pgsql pgsql intl zip bcmath \
    && pecl install redis && docker-php-ext-enable redis \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www
COPY . /var/www

RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/local/bin --filename=composer \
    && composer install --no-dev --optimize-autoloader \
    --no-interaction --no-progress --prefer-dist

# ============================================
# Stage 2: Build frontend assets
# ============================================
FROM debian AS assets

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl nodejs npm \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www
COPY . /var/www
RUN npm install && npm run build

# ============================================
# Stage 3: Production image (nginx + php-fpm)
# ============================================
FROM php:8.5-fpm AS production

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx supervisor libpq-dev libicu-dev libzip-dev \
    libfcgi-bin procps \
    && apt-get autoremove -y && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# PHP-FPM healthcheck script
RUN curl -o /usr/local/bin/php-fpm-healthcheck \
    https://raw.githubusercontent.com/renatomefi/php-fpm-healthcheck/master/php-fpm-healthcheck \
    && chmod +x /usr/local/bin/php-fpm-healthcheck

# Copy PHP extensions from builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Production PHP config
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY docker/common/php-fpm/status.conf /usr/local/etc/php-fpm.d/status.conf

# Copy app code + vendor
COPY --from=builder /var/www /var/www

# Copy built frontend assets
COPY --from=assets /var/www/public/build /var/www/public/build

# Config files
COPY docker/production/combined/nginx.conf /etc/nginx/nginx.conf
COPY docker/production/combined/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/production/combined/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY docker/production/combined/php-fpm-tuning.conf /usr/local/etc/php-fpm.d/zzz-tuning.conf

# Entrypoint (runs migrations + cache)
COPY docker/production/php-fpm/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Initial storage structure
COPY storage /var/www/storage-init

WORKDIR /var/www
RUN chown -R www-data:www-data /var/www

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
