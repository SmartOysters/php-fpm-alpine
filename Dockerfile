FROM php:8.3-fpm-alpine3.24
LABEL maintainer="oceanfarmr <technology@oceanfarmr.com>"

# Existing system utilities retained.
RUN apk --update --no-cache add git shadow

# Retain existing runtime packages and utilities during the security upgrade.
# gmp is explicit because PHP's gmp.so requires libgmp.so.10 at runtime.
RUN apk add --no-cache \
    acl fcgi file sudo composer zip gd make gmp \
    libzip-dev icu-dev libpng-dev libwebp-dev libjpeg-turbo-dev freetype-dev

RUN apk --update add nodejs yarn supervisor

# Retain the PostgreSQL client tools used by the existing base image.
# postgresql-dev is installed temporarily below for PHP extension compilation.
RUN apk add --no-cache postgresql

# Python / AWS CLI setup unchanged.
RUN apk add --no-cache python3 \
  && python3 -m venv /opt/py \
  && /opt/py/bin/python -m ensurepip --upgrade \
  && /opt/py/bin/pip install --no-cache-dir --upgrade "pip" "setuptools>=78.1.1" \
  && /opt/py/bin/pip install --no-cache-dir "awscli<2" \
  && ln -sf /opt/py/bin/aws /usr/local/bin/aws \
  && ln -sf /usr/bin/python3 /usr/bin/python

# Composer copy unchanged.
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Align www-data UID with host if you need 1000.
RUN usermod -u 1000 www-data

# Install each PHP extension once. Identify shared library dependencies
# after compilation, before removing compiler/header packages.
RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        binutils \
        pax-utils \
        zlib-dev \
        gmp-dev \
        icu-dev \
        libzip-dev \
        libpng-dev \
        libwebp-dev \
        libjpeg-turbo-dev \
        freetype-dev \
        postgresql-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j"$(nproc)" \
        calendar \
        gd \
        gmp \
        intl \
        pcntl \
        pdo_pgsql \
        pgsql \
        zip; \
    find /usr/local/lib/php/extensions -name '*.so' -exec strip --strip-unneeded {} +; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' \
            --recursive /usr/local/lib/php/extensions \
        | tr ',' '\n' \
        | sort -u \
        | awk 'NF { print "so:" $1 }' \
    )"; \
    if [ -n "$runDeps" ]; then \
        apk add --no-cache --virtual .phpexts-rundeps $runDeps; \
    fi; \
    apk del .build-deps; \
    php -m; \
    php --ri gmp
