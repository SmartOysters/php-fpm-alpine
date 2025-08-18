# Pin to a specific PHP & Alpine for repeatable builds (adjust versions as needed)
FROM php:8.2.21-fpm-alpine3.20
LABEL maintainer="oceanfarmr <technology@oceanfarmr.com>"

# System packages (no php8-*), build deps, and runtime libs
RUN apk add --no-cache \
      git shadow bash curl unzip \
      icu-dev libzip-dev zlib-dev \
      libpng-dev libwebp-dev libjpeg-turbo-dev freetype-dev \
      postgresql-dev libpq \
      nodejs yarn supervisor \
      python3 py3-pip

# Optional: install AWS CLI via pip (keep it minimal)
RUN pip3 install --upgrade pip && pip3 install awscli && rm -rf /root/.cache

# Use Composer from the official image (prebuilt, no extra PHP pulled in)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Align www-data UID with host if you need 1000 (Alpine www-data is 82 by default)
RUN usermod -u 1000 www-data || true

# Build & enable PHP extensions
# Note: configure BEFORE install
RUN set -eux; \
    docker-php-ext-configure intl; \
    docker-php-ext-configure zip; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j"$(nproc)" \
        intl zip gd pcntl opcache pdo_pgsql pgsql

# (Optional) strip symbols to shrink image
RUN find /usr/local/lib/php/extensions -name '*.so' -exec strip --strip-unneeded {} + || true

# Set working directory
WORKDIR /var/www/html

# (Optional) tune PHP-FPM & opcache via INI
# COPY .docker/php/conf.d/*.ini /usr/local/etc/php/conf.d/

# Ensure ownership for runtime (if you write to /var/www/html)
RUN chown -R www-data:www-data /var/www/html

# Expose FPM port
EXPOSE 9000

# Default command
CMD ["php-fpm"]
