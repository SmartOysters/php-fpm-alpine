# php-fpm-alpine

A Docker container

## Local Test

```bash
docker build --pull -t oceanfarmr/php-fpm-alpine:test-local .
```

OR - to buidl from scratch

```bash
docker build --pull --no-cache -t oceanfarmr/php-fpm-alpine:test-local .
```

```bash
docker run --rm oceanfarmr/php-fpm-alpine:test-local php -v
```

Then in the Dockerfiles you can add the following:

```Dockerfile
FROM oceanfarmr/php-fpm-alpine:test-local AS oceanfarmr_app
```

## To Create a Tag for Release

```bash
git tag v1.2.3 -a -m "Upgrade to PHP 8.3 and dependencies"
```

