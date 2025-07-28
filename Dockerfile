ARG VERSION=8
FROM docker.io/php:${VERSION}-fpm-alpine
COPY ./setup-module-version /tmp/
RUN set -xe \
    && echo $PHP_VERSION \
    && source /tmp/setup-module-version \
    && echo "export LD_LIBRARY_PATH=/usr/lib/oracle/$ORACLE_MAJOR/client64/lib" > /etc/profile.d/oracle-client.sh \
    && echo "export ORACLE_HOME=/usr/lib/oracle/$ORACLE_MAJOR/client64/lib" >> /etc/profile.d/oracle-client.sh \
    && echo "export TNS_ADMIN=/usr/lib/oracle/$ORACLE_MAJOR/client64/lib/network/admin" >> /etc/profile.d/oracle-client.sh \
    && echo "export NLS_LANG=AMERICAN_AMERICA.UTF8" >> /etc/profile.d/oracle-client.sh \
    && source /etc/profile \
    && apk upgrade --no-cache \
    && apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS git curl \
    && pecl channel-update pecl.php.net \
    && LIB_ARCH=$(arch) \
    && ARCH=$(arch) \
    && if [ $LIB_ARCH == "x86_64" ] ; then \
	    ARCH="x64" ; \
	    LIB_ARCH="x86-64" ; \
       fi \
    && if [ $WITH_ORACLE -ne 0 ] ; then \
         URL_BASE=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_VERSION}/instantclient-basic-linux.$ARCH-${ORACLE_MAJOR}.${ORACLE_MINOR}.zip ; \
         URL_SDK=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_VERSION}/instantclient-sdk-linux.$ARCH-${ORACLE_MAJOR}.${ORACLE_MINOR}.zip ; \
         URL_SQLPLUS=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_VERSION}/instantclient-sqlplus-linux.$ARCH-${ORACLE_MAJOR}.${ORACLE_MINOR}.zip ; \
         BASE_NAME=instantclient_${ORACLE_MAJOR} ; \
         #OCI8_VERSION=3.2.1 ; \
         apk add --no-cache --update libnsl libaio zlib; \
         apk add --no-cache --update --virtual .oci8-deps unzip ; \
         # install oracle client software \
         curl $URL_BASE > /tmp/base.zip ; \
         curl $URL_SDK > /tmp/sdk.zip ; \
         mkdir -p /usr/lib/oracle/${ORACLE_MAJOR}/client64/bin ; \
         unzip -d /usr/lib/oracle/${ORACLE_MAJOR}/client64 /tmp/base.zip ; \
         mv /usr/lib/oracle/${ORACLE_MAJOR}/client64/${BASE_NAME}* ${ORACLE_HOME} ; \
         mv /usr/lib/oracle/${ORACLE_MAJOR}/client64/lib/*i /usr/lib/oracle/${ORACLE_MAJOR}/client64/bin ; \
         unzip -d /tmp /tmp/sdk.zip ; \
         mv /tmp/${BASE_NAME}*/sdk ${ORACLE_HOME} ; \
         ln -sf /lib/libc.musl-$(arch).so.1 /lib/libresolv.so.2 ; \
         ln -sf /lib/ld-musl-$(arch).so.1 /lib/ld-linux-${LIB_ARCH}.so.2 ; \ 
         # install oci8 \
         echo "instantclient,${ORACLE_HOME}" | pecl install oci8-$OCI8_VERSION ; \
         echo "instantclient,${ORACLE_HOME}" | pecl install pdo_oci-$PDO_OCI_VERSION ; \ 
         docker-php-ext-enable oci8 ; \
         docker-php-ext-enable pdo_oci ; \
         apk del --no-cache .oci8-deps ; \
         rm -rf ${ORACLE_HOME}/sdk /tmp/* ; \
       fi \
    && if [ $WITH_SOAP -ne 0 ] ; then \
         apk add --no-cache --update libxml2 ; \
         apk add --no-cache --update --virtual .soap-deps postgresql-dev libxml2-dev ; \
         docker-php-ext-install soap ; \
         apk del --no-cache .soap-deps ; \
       fi \
    && if [ $WITH_OPENJDK -ne 0 ] ; then \
         apk add --no-cache --update openjdk8 ; \
       fi \
    && if [ $WITH_LDAP -ne 0 ] ; then \
         apk add --no-cache --update libldap ; \
         apk add --no-cache --update --virtual .ldap-deps openldap-dev; \
         docker-php-ext-install ldap ; \
         apk del --no-cache .ldap-deps ; \
       fi \
    && if [ $WITH_APCU -ne 0 ] ; then \
         pecl install apcu ; \
         docker-php-ext-enable apcu ; \ 
       fi \
    && if [ $WITH_ZIP -ne 0 ] ; then \
          apk add --nocache --update libzip ; \
          apk add --no-cache --update --virtual .zip-deps libzip-dev; \
          docker-php-ext-install zip ; \
          apk del --no-cache .zip-deps ; \
       fi \
    && if [ $WITH_CURL -ne 0 ] ; then \
         apk add --no-cache --update --virtual .curl-deps curl-dev ; \
         docker-php-ext-install curl ; \
         apk del --no-cache .curl-deps ; \
       fi \
    && if [ $WITH_IMAGEMAGICK -ne 0 ] ; then \
         #IMAGICK_VERSION=3.7.0 ; \
         apk add --no-cache --update imagemagick ; \
         apk add --no-cache --update --virtual .imagemagick-deps imagemagick-dev ; \
         pecl install imagick-$IMAGICK_VERSION ; \
         docker-php-ext-enable imagick ; \
         apk del --no-cache .imagemagick-deps ; \
       fi \
    && if [ $WITH_GD -ne 0 ] ; then \
         apk add --no-cache --update freetype libpng libjpeg-turbo ; \
         apk add --no-cache --update --virtual .gd-deps freetype-dev libpng-dev libjpeg-turbo-dev ; \
         docker-php-ext-configure gd --with-freetype --with-jpeg ; \
         docker-php-ext-install gd ; \
         apk del --no-cache .gd-deps ; \
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
         apk del --no-cache .memcached-deps ; \
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
             apk del --no-cache .canvas-deps ; \
           fi \
       fi \
    && if [ $WITH_SQLITE -ne 0 ]; then \
         apk add --no-cache --update sqlite ; \
         apk add --no-cache --update --virtual .sqlite-deps sqlite-dev ; \
         docker-php-ext-install pdo_sqlite ; \ 
         apk del --no-cache .sqlite-deps ; \ 
       fi \
    && if [ $WITH_POSTGRESQL -ne 0 ]; then \
         apk add --no-cache --update libpq ; \
         apk add --no-cache --update --virtual .postgresql-deps postgresql-dev ; \
         docker-php-ext-install pgsql pdo_pgsql ; \
         apk del --no-cache .postgresql-deps; \
       fi \
    && apk del --no-cache .phpize-deps \
    && if [ $WITH_GS -ne 0 ] ; then \
         apk add --no-cache ghostscript ; \
       fi
