FROM php:8.1-fpm-alpine
ENV LD_LIBRARY_PATH /usr/lib/oracle/21/client64/lib
ENV ORACLE_HOME /usr/lib/oracle/21/client64/lib
ENV TNS_ADMIN /usr/lib/oracle/21/client64/lib/network/admin
ENV NLS_LANG AMERICAN_AMERICA.UTF8
# Install PHP Extensions (igbinary & memcached + memcache)
RUN set -xe \
    && apk add --no-cache --update git libzip curl libmemcached-libs zlib libnsl libaio libldap freetype libpng libjpeg-turbo gcompat icu-data-full libgomp imagemagick  \
    && export URL_BASE=https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-basic-linux.x64-21.6.0.0.0dbru.zip \
    && export URL_SDK=https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-sdk-linux.x64-21.6.0.0.0dbru.zip \
    && export URL_SQLPLUS=https://download.oracle.com/otn_software/linux/instantclient/216000/instantclient-sqlplus-linux.x64-21.6.0.0.0dbru.zip \
    && export BASE_NAME=instantclient_21_6 \
    && cd /tmp/ \
    && apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS \
    && apk add --no-cache --update --virtual .memcached-deps zlib-dev libmemcached-dev cyrus-sasl-dev \
    && apk add --no-cache --update --virtual .oci8-deps unzip \
    && apk add --no-cache --update --virtual .openldap-deps openldap-dev \
    && apk add --no-cache --update --virtual .gd-deps freetype-dev libpng-dev libjpeg-turbo-dev \
    && apk add --no-cache --update --virtual .zip-deps libzip-dev \
    && apk add --no-cache --update --virtual .curl-deps curl-dev \
    && apk add --no-cache --update --virtual .imagemagick imagemagick-dev \
    && echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories \
    && echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk add --no-cache --update nodejs nodejs-current npm \
    && pecl install imagick-3.7.0 \
    && curl $URL_BASE > base.zip \
    && curl $URL_SDK > sdk.zip \
    && mkdir -p /usr/lib/oracle/21/client64/bin \
    && unzip -d /usr/lib/oracle/21/client64 /tmp/base.zip \
    && mv /usr/lib/oracle/21/client64/${BASE_NAME} ${ORACLE_HOME} \
    && mv /usr/lib/oracle/21/client64/lib/*i /usr/lib/oracle/21/client64/bin \
    && unzip -d /tmp /tmp/sdk.zip \
    && mv /tmp/${BASE_NAME}/sdk ${ORACLE_HOME} \
    && ln -sf /lib/libc.musl-x86_64.so.1 /lib/libresolv.so.2 \
    && ln -sf /lib/ld-musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2 \ 
    && echo "instantclient,${ORACLE_HOME}" | pecl install oci8-3.2.1 \
    && pecl install memcache-8.0 \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
# Install igbinary (memcached's deps) \
    && pecl install igbinary \
# Install memcached \
    && ( \
        pecl install --nobuild memcached \
        && cd "$(pecl config-get temp_dir)/memcached" \
        && phpize \
        && ./configure --enable-memcached-igbinary \
        && make -j$(nproc) \
        && make install \
        && cd /tmp/ \
    ) \
# Enable PHP extensions \
    && docker-php-ext-configure pdo_oci --with-pdo-oci=instantclient,$ORACLE_HOME \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && pecl install apcu \
    && docker-php-ext-install pdo_mysql pdo_oci ldap gd zip curl exif \
    && docker-php-ext-enable igbinary memcached memcache oci8 apcu imagick \
    && rm -rf ${ORACLE_HOME}/sdk /tmp/* \
    && apk del .memcached-deps .phpize-deps .oci8-deps .openldap-deps .gd-deps .zip-deps .curl-deps .imagemagick
USER 1000
