FROM docker.io/php:8.1-fpm-alpine
COPY ./setup-module-version /tmp/
ENV ARCH x64
ENV PHP_MAJOR_VERSION 8
ENV ORACLE_VERSION 21
ENV ORACLE_RELEASE 13
ENV WITH_ORACLE 1
# ARM64 Oracle version arm64 19.19
# ENV ARCH arm64
# ENV ORACLE_VERSION 19
# ENV ORACLE_RELEASE 19
ENV WITH_CURL 1
ENV WITH_LDAP 1
ENV WITH_NODE 0
ENV NODE_VERSION 19.9.0
ENV NODE_ARCH x64
# ARM64 Node
# ENV NODE_ARCH armv6l
ENV BUILD_CANVAS 0
ENV WITH_SQLITE 0 
ENV WITH_POSTGRESQL 0
ENV WITH_MEMCACHE 1
ENV WITH_PHP_COMPOSER 1
ENV WITH_PDO_MYSQL 1
ENV WITH_GD 1
ENV WITH_IMAGEMAGICK 1
ENV WITH_ZIP 1
ENV WITH_APCU 1
ENV WITH_OPENJDK 0
ENV WITH_SOAP 1
ENV LD_LIBRARY_PATH /usr/lib/oracle/$ORACLE_VERSION/client64/lib
ENV ORACLE_HOME /usr/lib/oracle/$ORACLE_VERSION/client64/lib
ENV TNS_ADMIN /usr/lib/oracle/$ORACLE_VERSION/client64/lib/network/admin
ENV NLS_LANG AMERICAN_AMERICA.UTF8
RUN set -xe \
    && source /tmp/setup-module-version \
#    && echo "http://mirror1.ku.ac.th/alpine/v3.19/main" > /etc/apk/repositories \
#    && echo "http://mirror1.ku.ac.th/alpine/v3.19/community" >> /etc/apk/repositories \
    && apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS git curl \
    && if [ ! $ARCH == "x64" ] ; then \
            URL_BASE=https://download.oracle.com/otn_software/linux/instantclient/instantclient-basiclite-linux-$ARCH.zip ; \
            URL_SDK=https://download.oracle.com/otn_software/linux/instantclient/instantclient-sdk-linux-$ARCH.zip ; \
            URL_SQLPLUS=https://download.oracle.com/otn_software/linux/instantclient/instantclient-sqlplus-linux-$ARCH.zip ; \
            LIB_ARCH=$(arch) ; \
       else \
            URL_BASE=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_VERSION}${ORACLE_RELEASE}000/instantclient-basic-linux.$ARCH-${ORACLE_VERSION}.${ORACLE_RELEASE}.0.0.0dbru.zip ; \
            URL_SDK=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_VERSION}${ORACLE_RELEASE}000/instantclient-sdk-linux.$ARCH-${ORACLE_VERSION}.${ORACLE_RELEASE}.0.0.0dbru.zip ; \
            URL_SQLPLUS=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_VERSION}${ORACLE_RELEASE}000/instantclient-sqlplus-linux.$ARCH-${ORACLE_VERSION}.${ORACLE_RELEASE}.0.0.0dbru.zip ; \
            LIB_ARCH="x86-64" ; \
       fi \ 
    && if [ $WITH_ORACLE -ne 0 ] ; then \
         BASE_NAME=instantclient_${ORACLE_VERSION}_${ORACLE_RELEASE} ; \
         #OCI8_VERSION=3.2.1 ; \
         apk add --no-cache --update libnsl libaio zlib; \
         apk add --no-cache --update --virtual .oci8-deps unzip ; \
         # install oracle client software \
         curl $URL_BASE > /tmp/base.zip ; \
         curl $URL_SDK > /tmp/sdk.zip ; \
         mkdir -p /usr/lib/oracle/${ORACLE_VERSION}/client64/bin ; \
         unzip -d /usr/lib/oracle/${ORACLE_VERSION}/client64 /tmp/base.zip ; \
         mv /usr/lib/oracle/${ORACLE_VERSION}/client64/${BASE_NAME} ${ORACLE_HOME} ; \
         mv /usr/lib/oracle/${ORACLE_VERSION}/client64/lib/*i /usr/lib/oracle/${ORACLE_VERSION}/client64/bin ; \
         unzip -d /tmp /tmp/sdk.zip ; \
         mv /tmp/${BASE_NAME}/sdk ${ORACLE_HOME} ; \
         ln -sf /lib/libc.musl-$(arch).so.1 /lib/libresolv.so.2 ; \
         ln -sf /lib/ld-musl-$(arch).so.1 /lib/ld-linux-${LIB_ARCH}.so.2 ; \ 
         # install oci8 \
         echo "instantclient,${ORACLE_HOME}" | pecl install oci8-$OCI8_VERSION ; \
         docker-php-ext-configure pdo_oci --with-pdo-oci=instantclient,$ORACLE_HOME ; \
         docker-php-ext-install pdo_oci ; \
         docker-php-ext-enable oci8 pdo_oci ; \
         apk del .oci8-deps ; \
         rm -rf ${ORACLE_HOME}/sdk /tmp/* ; \
       fi \
    && if [ $WITH_SOAP -ne 0 ] ; then \
         apk add --no-cache --update libxml2 ; \
         apk add --no-cache --update --virtual .soap-deps postgresql-dev libxml2-dev ; \
         docker-php-ext-install soap ; \
         apk del .soap-deps ; \
       fi \
    && if [ $WITH_OPENJDK -ne 0 ] ; then \
         apk add --no-cache --update openjdk8 ; \
       fi \
    && if [ $WITH_LDAP -ne 0 ] ; then \
         apk add --no-cache --update libldap ; \
         apk add --no-cache --update --virtual .ldap-deps openldap-dev; \
         docker-php-ext-install ldap ; \
         apk del .ldap-deps ; \
       fi \
    && if [ $WITH_APCU -ne 0 ] ; then \
         pecl install apcu ; \
         docker-php-ext-enable apcu ; \ 
       fi \
    && if [ $WITH_ZIP -ne 0 ] ; then \
          apk add --nocache --update libzip ; \
          apk add --no-cache --update --virtual .zip-deps libzip-dev; \
          docker-php-ext-install zip ; \
          apk del .zip-deps ; \
       fi \
    && if [ $WITH_CURL -ne 0 ] ; then \
         apk add --no-cache --update --virtual .curl-deps curl-dev ; \
         docker-php-ext-install curl ; \
         apk del .curl-deps ; \
       fi \
    && if [ $WITH_IMAGEMAGICK -ne 0 ] ; then \
         #IMAGICK_VERSION=3.7.0 ; \
         apk add --no-cache --update imagemagick ; \
         apk add --no-cache --update --virtual .imagemagick-deps imagemagick-dev ; \
         pecl install imagick-$IMAGICK_VERSION ; \
         docker-php-ext-enable imagick ; \
         apk del .imagemagick-deps ; \
       fi \
    && if [ $WITH_GD -ne 0 ] ; then \
         apk add --no-cache --update freetype libpng libjpeg-turbo ; \
         apk add --no-cache --update --virtual .gd-deps freetype-dev libpng-dev libjpeg-turbo-dev ; \
         docker-php-ext-configure gd --with-freetype --with-jpeg ; \
         docker-php-ext-install gd ; \
         apk del .gd-deps ; \
       fi \
    && if [ $WITH_PDO_MYSQL -ne 0 ] ; then \
         docker-php-ext-install pdo_mysql ; \
       fi \
    && if [ $WITH_PHP_COMPOSER -ne 0 ] ; then \
         curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer ; \
       fi \
    && if [ $WITH_MEMCACHE -ne 0 ] ; then \
         #MEMCACHE_VERSION=8.0 ; \
         apk add --no-cache --update libmemcached-libs libgomp ; \
         apk add --no-cache --update --virtual .memcached-deps zlib-dev libmemcached-dev cyrus-sasl-dev ; \
         pecl install memcache-$MEMCACHE_VERSION ; \
         pecl install igbinary ; \
         pecl install --nobuild memcached ; \
         cd "$(pecl config-get temp_dir)/memcached" ; \
         phpize ; \
         ./configure --enable-memcached-igbinary ; \
         make -j$(nproc) ; \
         make install ; \
         docker-php-ext-enable igbinary memcached memcache ; \
         apk del .memcached-deps ; \
       fi \
    && if [ $WITH_NODE -ne 0 ] ; then \
         apk add --no-cache --update icu icu-data-full ; \
         URL_NODEJS="https://unofficial-builds.nodejs.org/download/release/v$NODE_VERSION/node-v$NODE_VERSION-linux-$NODE_ARCH-musl.tar.xz" ; \
         curl -fsSLO --compressed $URL_NODEJS ; \
         tar -xJf "node-v$NODE_VERSION-linux-$NODE_ARCH-musl.tar.xz" -C /usr/local --strip-components=1 --no-same-owner ; \
         ln -s /usr/local/bin/node /usr/local/bin/nodejs; \
         rm -f "node-v$NODE_VERSION-linux-$NODE_ARCH-musl.tar.xz"; \ 
           if [ $BUILD_CANVAS -ne 0 ] ; then \
             apk add --no-cache --update giflib pango cairo pixman; \
             apk add --no-cache --update --virtual .canvas-deps python3 python3-dev pixman-dev giflib-dev pango-dev cairo-dev; \
             npm install -g --build-from-source canvas ; \
             apk del .canvas-deps ; \
           fi \
       fi \
    && if [ $WITH_SQLITE -ne 0 ]; then \
         apk add --no-cache --update sqlite ; \
         apk add --no-cache --update --virtual .sqlite-deps sqlite-dev ; \
         docker-php-ext-install pdo_sqlite ; \ 
         apk del .sqlite-deps ; \ 
       fi \
    && if [ $WITH_POSTGRESQL -ne 0 ]; then \
         apk add --no-cache --update libpq ; \
         apk add --no-cache --update --virtual .postgresql-deps postgresql-dev ; \
         docker-php-ext-install pgsql pdo_pgsql ; \
         apk del .postgresql-deps; \
       fi \
    && apk del .phpize-deps
