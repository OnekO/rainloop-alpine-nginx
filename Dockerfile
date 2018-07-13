FROM alpine

RUN apk --no-cache add \
    coreutils \
    gettext \
    supervisor \
    nginx \
    php7 \
    php7-fpm \
#    php7-mcrypt \
    php7-iconv \
#    php7-zip \
#    php7-gd \
#    php7-exif \
#    php7-imagick \
    php7-apcu \
#    php7-phar \
    php7-json \
    php7-curl \
#    php7-ctype \
#    php7-fileinfo \
#    php7-xmlwriter \
#    php7-mbstring \
    php7-pdo_mysql \
    php7-opcache \
    php7-dom \
#    php7-pcntl \
#    php7-posix \
    tzdata \
    curl

RUN set -x ; \
    addgroup -g 82 -S www-data ; \
    adduser -u 82 -D -S -G www-data www-data && exit 0 ; exit 1

ENV VIRTUAL_HOST = "rainloop.lan"
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/rainloop.conf /etc/nginx/conf.d/default.conf
RUN envsubst '\$VIRTUAL_HOST' < /etc/nginx/conf.d/default.conf > /etc/nginx/conf.d/default.conf

ENV PHP_FPM_USER="www-data" \
    PHP_FPM_GROUP="www-data" \
    PHP_FPM_LISTEN_MODE="0660" \
    PHP_MEMORY_LIMIT="512M" \
    PHP_MAX_UPLOAD="100M" \
    PHP_MAX_FILE_UPLOAD="200" \
    PHP_MAX_POST="100M" \
    PHP_DISPLAY_ERRORS="On" \
    PHP_DISPLAY_STARTUP_ERRORS="On" \
    PHP_ERROR_REPORTING="E_COMPILE_ERROR\|E_RECOVERABLE_ERROR\|E_ERROR\|E_CORE_ERROR" \
    PHP_CGI_FIX_PATHINFO=0

RUN sed -i "s|;listen.owner\s*=\s*nobody|listen.owner = ${PHP_FPM_USER}|g" /etc/php7/php-fpm.conf && \
    sed -i "s|;listen.group\s*=\s*nobody|listen.group = ${PHP_FPM_GROUP}|g" /etc/php7/php-fpm.conf && \
    sed -i "s|;listen.mode\s*=\s*0660|listen.mode = ${PHP_FPM_LISTEN_MODE}|g" /etc/php7/php-fpm.conf && \
    sed -i "s|user\s*=\s*nobody|user = ${PHP_FPM_USER}|g" /etc/php7/php-fpm.conf && \
    sed -i "s|group\s*=\s*nobody|group = ${PHP_FPM_GROUP}|g" /etc/php7/php-fpm.conf && \
    sed -i "s|;log_level\s*=\s*notice|log_level = notice|g" /etc/php7/php-fpm.conf && \
    sed -i "s|display_errors\s*=\s*Off|display_errors = ${PHP_DISPLAY_ERRORS}|i" /etc/php7/php.ini && \
    sed -i "s|display_startup_errors\s*=\s*Off|display_startup_errors = ${PHP_DISPLAY_STARTUP_ERRORS}|i" /etc/php7/php.ini && \
    sed -i "s|error_reporting\s*=\s*E_ALL & ~E_DEPRECATED & ~E_STRICT|error_reporting = ${PHP_ERROR_REPORTING}|i" /etc/php7/php.ini && \
    sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php7/php.ini && \
    sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${PHP_MAX_UPLOAD}|i" /etc/php7/php.ini && \
    sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php7/php.ini && \
    sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php7/php.ini && \
    sed -i "s|;opcache.validate_timestamps=.*|opcache.validate_timestamps=0|i" /etc/php7/php.ini && \
    sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= ${PHP_CGI_FIX_PATHINFO}|i" /etc/php7/php.ini

ENV TIMEZONE "Europe/Madrid"

RUN cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php7/php.ini

WORKDIR /var/www/rainloop
RUN curl -sL https://repository.rainloop.net/installer.php | php
RUN find . -type d -exec chmod 755 {} \; && \
    find . -type f -exec chmod 644 {} \; && \
    chown -R www-data:www-data .

RUN ln -sf /dev/stdout /var/log/nginx/rainloop_access.log && ln -sf /dev/stderr /var/log/nginx/rainloop_error.log
RUN ln -sf /dev/stderr /var/log/php7/error.log
ADD supervisord.conf /etc/supervisord.conf

ENV MYSQL_HOST "db"
ENV MYSQL_USER "phabricator"
ENV MYSQL_PASSWORD "phabricator"
ENV MYSQL_PORT "3306"
ENV BASE_URI "http://phabricator.lan"
ENV CDN_URI "http://cdn.phabricator.lan"
ENV LOCAL_PATH "/var/www/phabricator/store"
ENV FORCE_HTTPS "true"

EXPOSE 80
ENTRYPOINT /usr/bin/supervisord -c /etc/supervisord.conf
