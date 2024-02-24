FROM php:8.1.4-fpm-alpine
LABEL maintainer="oceanfarmr <technology@oceanfarmr.com>"

RUN apk --update --no-cache add git shadow

RUN echo http://dl-cdn.alpinelinux.org/alpine/v3.12/community/ >> /etc/apk/repositories
RUN echo http://dl-cdn.alpinelinux.org/alpine/v3.12/main/ >> /etc/apk/repositories

RUN usermod -u 1000 www-data

RUN apk add php8 php8-zip acl fcgi file sudo composer zip gd make libzip-dev icu-dev libpng-dev libwebp-dev libjpeg-turbo-dev freetype-dev

RUN apk --update add nodejs yarn supervisor php8-pcntl

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

RUN docker-php-ext-install intl
RUN docker-php-ext-configure intl
RUN docker-php-ext-enable intl \
    && { find /usr/local/lib -type f -print0 | xargs -0r strip --strip-all -p 2>/dev/null || true; }
RUN docker-php-ext-configure zip && \
    docker-php-ext-install zip
RUN docker-php-ext-install pcntl
RUN docker-php-ext-configure calendar && \
    docker-php-ext-install calendar
RUN docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install gd

RUN apk add --no-cache \
        python3 \
        py3-pip \
    && pip3 install --upgrade pip \
    && pip3 install \
        awscli \
    && rm -rf /var/cache/apk/* \
    && ln -s /usr/bin/python3 /usr/bin/python
