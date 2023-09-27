FROM php:8-fpm-alpine
ENV ORACLE_VERSION 21
ENV ORACLE_RELEASE 11
ENV LD_LIBRARY_PATH /usr/lib/oracle/$ORACLE_VERSION/client64/lib
ENV ORACLE_HOME /usr/lib/oracle/$ORACLE_VERSION/client64/lib
ENV TNS_ADMIN /usr/lib/oracle/$ORACLE_VERSION/client64/lib/network/admin
ENV NLS_LANG AMERICAN_AMERICA.UTF8
ENV NODE_VERSION 19.9.0
# Install PHP Extensions (igbinary & memcached + memcache + oci8 + pdo_oci)
RUN set -xe \
    && apk add --no-cache --update sqlite git libzip curl libmemcached-libs zlib libnsl libaio libldap freetype libpng libjpeg-turbo gcompat libgomp libpq imagemagick \
    && export URL_NODEJS="https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64-musl.tar.xz" \
    && export URL_BASE=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_VERSION}${ORACLE_RELEASE}000/instantclient-basic-linux.x64-${ORACLE_VERSION}.${ORACLE_RELEASE}.0.0.0dbru.zip \
    && export URL_SDK=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_VERSION}${ORACLE_RELEASE}000/instantclient-sdk-linux.x64-${ORACLE_VERSION}.${ORACLE_RELEASE}.0.0.0dbru.zip \
    && export URL_SQLPLUS=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_VERSION}${ORACLE_RELEASE}000/instantclient-sqlplus-linux.x64-${ORACLE_VERSION}.${ORACLE_RELEASE}.0.0.0dbru.zip \
    && export BASE_NAME=instantclient_${ORACLE_VERSION}_${ORACLE_RELEASE} \
    && export OCI8_VERSION=3.2.1 \
    && export MEMCACHE_VERSION=8.0 \
    && export IMAGICK_VERSION=3.7.0 \
    && cd /tmp/ \
    && curl -fsSLO --compressed $URL_NODEJS  \
    && tar -xJf "node-v$NODE_VERSION-linux-x64-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
    && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
    && rm -f "node-v$NODE_VERSION-linux-x64-musl.tar.xz" \
# install package need to build modules
    && apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS \
    && apk add --no-cache --update --virtual .memcached-deps zlib-dev libmemcached-dev cyrus-sasl-dev \
    && apk add --no-cache --update --virtual .oci8-deps unzip \
    && apk add --no-cache --update --virtual .openldap-deps openldap-dev \
    && apk add --no-cache --update --virtual .gd-deps freetype-dev libpng-dev libjpeg-turbo-dev \
    && apk add --no-cache --update --virtual .zip-deps libzip-dev \
    && apk add --no-cache --update --virtual .curl-deps curl-dev \
    && apk add --no-cache --update --virtual .imagemagick imagemagick-dev \
    && apk add --no-cache --update --virtual .postgresql postgresql-dev \
    && apk add --no-cache --update --virtual .sqlite sqlite-dev \
# install oracle client software
    && curl $URL_BASE > base.zip \
    && curl $URL_SDK > sdk.zip \
    && mkdir -p /usr/lib/oracle/${MAJOR}/client64/bin \
    && unzip -d /usr/lib/oracle/${MAJOR}/client64 /tmp/base.zip \
    && mv /usr/lib/oracle/${MAJOR}/client64/${BASE_NAME} ${ORACLE_HOME} \
    && mv /usr/lib/oracle/${MAJOR}/client64/lib/*i /usr/lib/oracle/${MAJOR}/client64/bin \
    && unzip -d /tmp /tmp/sdk.zip \
    && mv /tmp/${BASE_NAME}/sdk ${ORACLE_HOME} \
    && ln -sf /lib/libc.musl-x86_64.so.1 /lib/libresolv.so.2 \
    && ln -sf /lib/ld-musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2 \ 
# install oci8
    && echo "instantclient,${ORACLE_HOME}" | pecl install oci8-$OCI8_VERSION \
# install memcache
    && pecl install memcache-$MEMCACHE_VERSION \
# install imagick
    && pecl install imagick-$IMAGICK_VERSION \
# Install php composer
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
    && docker-php-ext-install pgsql pdo_sqlite pdo_pgsql pdo_mysql pdo_oci ldap gd zip curl \
    && docker-php-ext-enable igbinary memcached memcache oci8 apcu imagick \
    && rm -rf ${ORACLE_HOME}/sdk /tmp/* \
    apk del .memcached-deps .phpize-deps .oci8-deps .openldap-deps .gd-deps .zip-deps .curl-deps .imagemagick .postgresql 
