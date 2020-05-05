FROM arm32v7/php:7.3-apache
LABEL Mitch Daniels <mdaniels@grimbon.nl>

ENV CACTI_VERSION=1.2.12

RUN apt-get upgrade && apt-get update && ACCEPT_EULA=Y && apt-get install -y \
        unzip \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libmemcached-dev \
        libzip-dev \
        libgeoip-dev \
        libxml2-dev \
        libxslt-dev \
        libtidy-dev \
        libssl-dev \
        zlib1g-dev \
        libpng-dev \
        libwebp-dev \
        libgmp-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libaio1 \
        libldap2-dev \
        apt-file \
        wget \
        vim \
        gnupg \
        gnupg2 \
        zip \
		file \
        git \
		make \
        gcc \
        g++ \
        autoconf \
        libc-dev \
        pkg-config \ 
		supervisor \
		cron \
		curl \
		snmpd \
		net-snmp* \
		help2man \
		libsnmp-dev \
		make \
		libtool \
		dos2unix \
		rrdtool \
		snmp \
		libmariadb-dev-compat \
    && pecl install geoip-1.1.1 \
    && pecl install apcu \
    && pecl install memcached \
    && pecl install timezonedb \
    && pecl install grpc \
    && docker-php-ext-configure gd --with-gd --with-freetype-dir=/usr/include/ --with-webp-dir=/usr/include/ --with-jpeg-dir=/usr/include/  \
    && docker-php-ext-configure zip --with-libzip \
    && docker-php-ext-install gd calendar gmp ldap sysvmsg pcntl iconv bcmath xml mbstring pdo tidy gettext intl pdo_mysql mysqli simplexml xml xsl xmlwriter zip opcache exif sockets snmp \
    && docker-php-ext-enable geoip apcu memcached timezonedb grpc \
    && printf "log_errors = On \nerror_log = /dev/stderr\n" > /usr/local/etc/php/conf.d/php-logs.ini

# Use the PORT environment variable in Apache configuration files.
RUN sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf

# Composer
RUN mkdir -p /usr/local/ssh
COPY ./resources/etc/ssh/* /usr/local/ssh/
RUN a2enmod proxy && \
    a2enmod proxy_http && \
    a2enmod proxy_ajp && \
    a2enmod rewrite && \
    a2enmod deflate && \
    a2enmod headers && \
    a2enmod proxy_balancer && \
    a2enmod proxy_connect && \
    a2enmod ssl && \
    a2enmod cache && \
    a2enmod expires && \
    chmod g+w /var/log/apache2 && \
    chmod 777 /var/lock/apache2 && \
    chmod 777 /var/run/apache2
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

########### Install CACTI ###########
RUN set -x \
  && mkdir -p /var/www/html/cacti \
  && cd /var/www/html/ \
  && curl -L https://www.cacti.net/downloads/cacti-"$CACTI_VERSION".tar.gz > cacti-"$CACTI_VERSION".tar.gz \
  && tar xzvf cacti-"$CACTI_VERSION".tar.gz  -C /var/www/html/ \
  && mv cacti-"$CACTI_VERSION"/* cacti/ \
  && rm -rf cacti-"$CACTI_VERSION".tar.gz html cacti-"$CACTI_VERSION"

########### Install SPINE ###########
RUN set -x \
  && cd /var/www/html/ \
  && curl -L https://www.cacti.net/downloads/spine/cacti-spine-"$CACTI_VERSION".tar.gz > cacti-spine-"$CACTI_VERSION".tar.gz \
  && tar xvzf cacti-spine-"$CACTI_VERSION".tar.gz \
  && cd cacti-spine-"$CACTI_VERSION" \
  && ./bootstrap \
  && ./configure \
  && make \
  && make install \
  && cd /var/www/html/ \
  && chown root:root /usr/local/spine/bin/spine \
  && chmod +s /usr/local/spine/bin/spine \
  && rm -rf cacti-spine-"$CACTI_VERSION" cacti-spine-"$CACTI_VERSION".tar.gz

# Switch to the production php.ini for production operations.
COPY ./resources/configs/production.ini /usr/local/etc/php/conf.d/production.ini

# Apache settings
COPY ./resources/etc/apache2/conf-enabled/host.conf /etc/apache2/conf-enabled/host.conf
COPY ./resources/etc/apache2/apache2.conf /etc/apache2/apache2.conf
COPY ./resources/etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/000-default.conf

# Add script to deal with Docker Secrets before starting apache
COPY ./resources/secrets.sh /usr/local/bin/secrets
COPY ./resources/startup.sh /usr/local/bin/startup
RUN chmod 755 /usr/local/bin/secrets && chmod 755 /usr/local/bin/startup

# Copy docker folder
COPY docker/ /docker/

########### SETUP CACTI ###########
RUN mkdir -p /var/www/html/cacti/rra/backup/ /var/www/html/cacti/rra/archive/ /var/www/html/cacti/cache \
  && chown -R www-data:www-data /var/www/html/cacti \
  && cp /docker/configurations/cacti/config.php /var/www/html/cacti/include/config.php \
  && cp /docker/configurations/cacti/global.php /var/www/html/cacti/include/global.php \
  && mv /var/www/html/cacti/include/vendor/csrf /var/www/html/cacti/include/

########### EXPOSE SNMP PORT ###########
EXPOSE 161/udp

########### SET WORKDIR ###########
WORKDIR /var/www/html/cacti

########### START SUPERVISORD ###########
RUN mkdir -p /var/log/supervisord \
  && touch /var/log/supervisord/supervisord.log \
  && chmod +x /docker/entrypoint.sh

COPY ./resources/bin/* /usr/local/bin/
RUN chmod -R 775 /usr/local/bin/

RUN adduser --home /var/www/html/cacti --no-create-home --disabled-login cacti

VOLUME ["/var/www/html/cacti/rra/"]

ENTRYPOINT ["/docker/entrypoint.sh"]
CMD ["cacti"]