FROM php:8.4-fpm-alpine3.21
LABEL maintainer="oceanfarmr <technology@oceanfarmr.com>"

RUN apk --update --no-cache add git shadow

# System packages (no php8-*), build deps, and runtime libs
RUN apk add acl fcgi file sudo composer zip gd make libzip-dev icu-dev libpng-dev libwebp-dev libjpeg-turbo-dev freetype-dev

RUN apk --update add nodejs yarn supervisor

RUN set -eux; \
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		zlib-dev \
	; \
    runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-cache --virtual .phpexts-rundeps $runDeps; \
	\
	apk del .build-deps

RUN apk add postgresql postgresql-dev \
  && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
  && docker-php-ext-install pdo pdo_pgsql pgsql

# PIP Setup
RUN apk add --no-cache python3 \
  && python3 -m venv /opt/py \
  && /opt/py/bin/python -m ensurepip --upgrade \
  && /opt/py/bin/pip install --no-cache-dir --upgrade "pip" "setuptools>=78.1.1" \
  && /opt/py/bin/pip install --no-cache-dir "awscli<2" \
  && ln -sf /opt/py/bin/aws /usr/local/bin/aws \
  && ln -sf /usr/bin/python3 /usr/bin/python

# Use Composer from the official image (prebuilt, no extra PHP pulled in)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Align www-data UID with host if you need 1000 (Alpine www-data is 82 by default)
RUN usermod -u 1000 www-data

# Build & enable PHP extensions
RUN set -eux; \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
        icu-dev libzip-dev libpng-dev libwebp-dev libjpeg-turbo-dev freetype-dev postgresql-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-configure zip; \
    docker-php-ext-configure intl; \
    docker-php-ext-install -j"$(nproc)" intl zip gd pcntl pdo_pgsql pgsql; \
    apk del .build-deps

RUN docker-php-ext-configure calendar && \
    docker-php-ext-install calendar
RUN docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install gd

RUN find /usr/local/lib/php/extensions -name '*.so' -exec strip --strip-unneeded {} +
