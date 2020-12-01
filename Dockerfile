FROM ubuntu:20.04

LABEL maintainer="Hlyan Htet"

ENV DEBIAN_FRONTEND=noninteractive

# adjust timezone
RUN apt-get update \
    && apt-get install -y gnupg tzdata \
    && echo "Asia/Rangoon" > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata

# install essential packages
RUN apt-get update \
    && apt-get install -y curl zip unzip git \
    supervisor sqlite3 wget nginx vim

RUN apt-get update \
    && apt-get install -y software-properties-common

# install php7-*
RUN add-apt-repository ppa:ondrej/php \
    && add-apt-repository ppa:ondrej/nginx

# php7.4-bcmath php7.4-mbstring is what laravel expect
# php7.4-dev php7.4-common is use in installing oci8 driver
# php7.4-xml php7.4-xmlrpc php7.4-zip php7.4-gd is to use when work with excel sheet in php
# laravel test use sqlite for db purpose as default, so php7.4-sqlite need to connect sqlite.
RUN apt-get update \
    && apt-get install -y php7.4 php7.4-cli \
    php7.4-bcmath php7.4-mbstring php7.4-xmlrpc \
    php7.4-common php7.4-mysql php7.4-xml \
    php7.4-dev php7.4-fpm php7.4-sqlite \
    php7.4-zip php7.4-gd

# install postgres modules which support for pdo
RUN apt-get update \
    && apt-get install php7.4-pgsql

RUN phpenmod -v 7.4 -s fpm pgsql

# install composer by running sh
COPY scripts/composer.sh ./

RUN chmod +x composer.sh
RUN ./composer.sh
RUN rm composer.sh \
    && mv composer.phar /usr/local/bin/composer

# clean packages and set nginx daemon off
RUN apt-get update && mkdir /run/php \
        && apt-get -y autoremove \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
        && echo "daemon off;" >> /etc/nginx/nginx.conf

# log ouput synchronize
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# add configuration for nginx, supervisord, php-fpm
ADD ./config/nginx/default /etc/nginx/sites-available/default
ADD ./config/supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD ./config/php_fpm/php-fpm.conf /etc/php/7.4/fpm/php-fpm.conf

# prepare for entrypoint sh
ADD ./scripts/initiate.sh /usr/local/bin/initiate
RUN chmod +x /usr/local/bin/initiate

# RUN PHP FPM Service
RUN service php7.4-fpm restart

# Add Cron for scheduling
RUN apt-get update \
    && apt-get install -y cron

# Expose to port 80
EXPOSE 80

# run entrypoint sh
ENTRYPOINT ["initiate"]
