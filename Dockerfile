FROM alpine:3.9

ENV TZ CST-8
ENV EXEC_USER www-data
ENV PHP_VERSION 7.3.4
ENV NGINX_VERSION 1.16.0
ENV PHP_SWOOLE 4.3.3
ENV PHP_REDIS 4.3.0
ENV PHP_YAF     3.0.8
ENV PHP_MONGODB 1.5.3

ENV PHP_DIR /usr/local/php
ENV NGINX_DIR /usr/local/nginx

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
        && apk add --no-cache --virtual .persistent-deps ca-certificates curl pcre libzip zlib freetype libpng jpeg libcrypto1.1 libssl1.1 libressl libstdc++ gettext-dev gettext bison \
        && set -xe \
        && addgroup -g 82 -S $EXEC_USER \
        && adduser -u 82 -D -S -G $EXEC_USER $EXEC_USER \
        && mkdir -p /usr/src && mkdir -p /usr/local/sbin \
        \
        \
        \
#开始安装php
        && export CFLAGS="-fstack-protector-strong -fpic -fpie -O2" CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2" LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" \
        && apk add --no-cache --virtual .php-deps autoconf dpkg-dev dpkg file g++ gcc libzip-dev libc-dev make pkgconf re2c coreutils curl-dev freetype-dev libpng-dev jpeg-dev zlib-dev libedit-dev libressl-dev libsodium-dev libxml2-dev sqlite-dev  \
        \
#安装libiconv  php的iconv函数需要  若不需要，可以省略
        && wget http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.15.tar.gz && tar -xvf libiconv-1.15.tar.gz && rm -rf libiconv-1.15.tar.gz && cd libiconv-1.15 && ./configure --prefix=/usr/local/libiconv && make && make install && make clean && cd .. && rm -rf libiconv-1.15 \
        \
        \
        && cd /usr/src && wget http://jp2.php.net/distributions/php-$PHP_VERSION.tar.gz && tar -xvf php-$PHP_VERSION.tar.gz && rm -rf php-$PHP_VERSION.tar.gz && mv php-$PHP_VERSION php  \
        && cd /usr/src/php \
        && gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
        && mkdir -p $PHP_DIR/etc/php.d && mkdir -p $PHP_DIR/var/log && chown -R $EXEC_USER.$EXEC_USER $PHP_DIR/var/log && mkdir -p $PHP_DIR/var/session && chown -R $EXEC_USER.$EXEC_USER $PHP_DIR/var/session \
        && ./configure \
                --prefix=$PHP_DIR \
                --with-config-file-path=$PHP_DIR/etc \
                --with-config-file-scan-dir=$PHP_DIR/etc/php.d \
                --build="$gnuArch" \
                --disable-cgi \
                --enable-option-checking=fatal \
                --enable-bcmath \
                --enable-mbstring \
                --enable-mysqlnd \
                --enable-xml \
                --enable-zip \
                --enable-pcntl \
                --enable-soap \
                --enable-sockets \
                --enable-fpm --with-fpm-user=$EXEC_USER --with-fpm-group=$EXEC_USER \
                --with-sodium=shared \
                --with-gd \
                --with-curl \
                --with-openssl \
                --with-gettext \
                --with-zlib \
                --with-mhash \
                --with-mysqli=mysqlnd \
                --with-pdo-mysql=mysqlnd \
                --with-freetype-dir \
                --with-jpeg-dir \
                --with-png-dir \
                --with-iconv=/usr/local/libiconv \
                \
        && make -j "$(nproc)" \
        && make install && make clean \
        && cp php.ini-production $PHP_DIR/lib/php.ini && cp $PHP_DIR/etc/php-fpm.conf.default $PHP_DIR/etc/php-fpm.conf && cp $PHP_DIR/etc/php-fpm.d/www.conf.default $PHP_DIR/etc/php-fpm.d/www.conf \
        && cd ext \
        && wget http://pecl.php.net/get/swoole-$PHP_SWOOLE.tgz && tar -xvf swoole-$PHP_SWOOLE.tgz && rm -rf swoole-$PHP_SWOOLE.tgz && cd swoole-$PHP_SWOOLE && $PHP_DIR/bin/phpize && ./configure --with-php-config=$PHP_DIR/bin/php-config --enable-coroutine --enable-openssl --enable-http2 --enable-sockets --enable-mysqlnd --enable-async-redis && make && make install && make clean && cd .. \
        && { echo 'extension = swoole.so'; } | tee $PHP_DIR/etc/php.d/swoole.ini \
        && wget http://pecl.php.net/get/redis-$PHP_REDIS.tgz && tar -xvf redis-$PHP_REDIS.tgz && rm -rf redis-$PHP_REDIS.tgz && cd redis-$PHP_REDIS && $PHP_DIR/bin/phpize && ./configure --with-php-config=$PHP_DIR/bin/php-config && make && make install && make clean && cd .. \
        && { echo 'extension = redis.so'; } | tee $PHP_DIR/etc/php.d/redis.ini \
        && wget http://pecl.php.net/get/yaf-$PHP_YAF.tgz && tar -xvf yaf-$PHP_YAF.tgz && rm -rf yaf-$PHP_YAF.tgz && cd yaf-$PHP_YAF && $PHP_DIR/bin/phpize && ./configure --with-php-config=$PHP_DIR/bin/php-config && make && make install && make clean && cd .. \
        && { echo 'extension = yaf.so'; } | tee $PHP_DIR/etc/php.d/yaf.ini \
        && wget http://pecl.php.net/get/mongodb-$PHP_MONGODB.tgz && tar -xvf mongodb-$PHP_MONGODB.tgz && rm -rf mongodb-$PHP_MONGODB.tgz && cd mongodb-$PHP_MONGODB && $PHP_DIR/bin/phpize && ./configure --with-php-config=$PHP_DIR/bin/php-config && make && make install && make clean && cd .. \
        && { echo 'extension = mongodb.so'; } | tee $PHP_DIR/etc/php.d/mongodb.ini \
        && { \
                echo '[global]'; \
                echo "error_log = $PHP_DIR/var/log/error.log"; \
                echo 'daemonize = no'; \
                echo '[docker]'; \
                echo "user = $EXEC_USER"; \
                echo "group = $EXEC_USER"; \
                echo "listen =  $PHP_DIR/var/run/php-fpm.sock"; \
                echo "listen.owner = $EXEC_USER"; \
                echo "listen.group = $EXEC_USER"; \
                echo 'listen.mode = 0660'; \
                echo 'pm = dynamic'; \
                echo 'pm.max_children = 55'; \
                echo 'pm.start_servers = 10'; \
                echo 'pm.min_spare_servers = 10'; \
                echo 'pm.max_spare_servers = 55'; \
                echo 'pm.max_requests = 500'; \
                echo "access.log = $PHP_DIR/var/log/access.log"; \
                echo 'clear_env = no'; \
                echo 'catch_workers_output = yes'; \
                echo 'php_value[session.save_handler] = files'; \
                echo "php_value[session.save_path]    = $PHP_DIR/var/session"; \
        } | tee $PHP_DIR/etc/php-fpm.d/docker.conf \
        && rm -rf $PHP_DIR/etc/php-fpm.d/www.conf \
        && export -n CFLAGS CPPFLAGS LDFLAGS \
        && cd / && apk del .php-deps && rm -rf /usr/src/php && rm -rf /tmp/pear ~/.pearrc \
        \
        && ln -s $PHP_DIR/bin/php /usr/local/bin/php \
        && ln -s $PHP_DIR/bin/phpdbg /usr/local/bin/phpdbg \
        && ln -s $PHP_DIR/bin/php-config /usr/local/bin/php-config \
        && ln -s $PHP_DIR/bin/phpize /usr/local/bin/phpize  \
        && ln -s $PHP_DIR/bin/pecl /usr/local/bin/pecl \
        && ln -s $PHP_DIR/bin/pear /usr/local/bin/pear \
        && ln -s $PHP_DIR/bin/phar.phar /usr/local/bin/phar \
        && ln -s $PHP_DIR/sbin/php-fpm /usr/local/sbin/php-fpm \
        \
        \
        \
        \
#开始安装nginx
        && export CFLAGS="-pipe -O -W -Wall -Wpointer-arith -Wno-unused-parameter -Werror" \
        && apk add --no-cache --virtual .nginx-deps gcc libc-dev make openssl-dev pcre-dev zlib-dev linux-headers gnupg libxslt-dev gd-dev geoip-dev \
        && cd /usr/src && wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz && tar -xvf nginx-$NGINX_VERSION.tar.gz && rm nginx-$NGINX_VERSION.tar.gz && mv nginx-$NGINX_VERSION nginx \
        && cd /usr/src/nginx \
        && mkdir -p $NGINX_DIR/conf.d && mkdir -p $NGINX_DIR/logs && chown -R $EXEC_USER.$EXEC_USER $NGINX_DIR/logs && mkdir -p $NGINX_DIR/run && chown -R $EXEC_USER.$EXEC_USER $NGINX_DIR/run \
        && ./configure \
                --prefix=$NGINX_DIR \
                --conf-path=$NGINX_DIR/conf/nginx.conf \
                --modules-path=$NGINX_DIR/modules \
                --user=$EXEC_USER \
                --group=$EXEC_USER \
                --with-http_ssl_module \
                --with-http_v2_module \
                --with-http_realip_module \
                --with-http_geoip_module=dynamic \
                --with-http_gunzip_module \
                --with-http_gzip_static_module \
#               --with-http_addition_module \
#               --with-http_sub_module \
#               --with-http_dav_module \
#               --with-http_flv_module \
#               --with-http_mp4_module \
#               --with-http_random_index_module \
#               --with-http_secure_link_module \
#               --with-http_stub_status_module \
#               --with-http_auth_request_module \
#               --with-http_xslt_module=dynamic \
#               --with-http_image_filter_module=dynamic \
#               --with-threads \
#               --with-stream \
#               --with-stream_ssl_module \
#               --with-stream_ssl_preread_module \
#               --with-stream_realip_module \
#               --with-stream_geoip_module=dynamic \
#               --with-http_slice_module \
#               --with-mail \
#               --with-mail_ssl_module \
#               --with-compat \
#               --with-file-aio \
                \
        && make -j$(getconf _NPROCESSORS_ONLN) \
        && make install && make clean \
        && { \
                echo -e ""; \
                echo -e "user $EXEC_USER;"; \
                echo -e "worker_processes  1;\n\n"; \
                echo -e "error_log  $NGINX_DIR/logs/error.log warn;"; \
                echo -e "pid  $NGINX_DIR/run/nginx.pid;\n\n"; \
                echo -e "events {"; \
                echo -e "       worker_connections  1024;"; \
                echo -e "}\n\n"; \
                echo -e "http {"; \
                echo -e "       include       $NGINX_DIR/conf/mime.types;"; \
                echo -e "       default_type  application/octet-stream;\n\n"; \
                echo -e "       log_format  main  '\$remote_addr - \$remote_user [\$time_local] \"\$request\" \$status $body_bytes_sent \"\$http_referer\" \"\$http_user_agent\" \"\$http_x_forwarded_for\"'"; \
                echo -e "       access_log  $NGINX_DIR/logs/access.log  main;\n\n"; \
                echo -e "       sendfile        on;"; \
                echo -e "       keepalive_timeout  65;\n\n"; \
                echo -e "       include $NGINX_DIR/conf.d/*.conf;"; \
                echo -e "}\n\n"; \
        } | tee $NGINX_DIR/conf/nginx.conf \
        && export -n CFLAGS \
        && cd / && apk del .nginx-deps && rm -rf /usr/src/nginx \
        \
        && ln -s $NGINX_DIR/sbin/nginx /usr/local/sbin/nginx
