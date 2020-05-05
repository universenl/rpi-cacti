#!/bin/sh

update_cacti_db_config() {
    set -x \
    && sed -i 's/$DB_TYPE/mysql/g' /var/www/html/cacti/include/config.php \
    && sed -i 's/$DB_NAME/'$DB_NAME'/g' /var/www/html/cacti/include/config.php \
    && sed -i 's/$DB_HOSTNAME/'$DB_HOSTNAME'/g' /var/www/html/cacti/include/config.php \
    && sed -i 's/$DB_USERNAME/'$DB_USERNAME'/g' /var/www/html/cacti/include/config.php \
    && sed -i 's/$DB_PASSWORD/'$DB_PASSWORD'/g' /var/www/html/cacti/include/config.php \
    && sed -i 's/$DB_PORT/3306/g' /var/www/html/cacti/include/config.php \
    && sed -i 's/$DB_SSL/false/g' /var/www/html/cacti/include/config.php \
    && sed -i 's/$CACTI_VERSION/'$CACTI_VERSION'/g' /var/www/html/cacti/include/global.php
}

update_spine_config() {
    if [ ! -e "/usr/local/spine/etc/spine.conf" ]; then
      set -x \
      && cp -f /docker/configurations/spine/spine.conf /usr/local/spine/etc/spine.conf \
      && sed -i 's/$DB_HOSTNAME/'$DB_HOSTNAME'/g' /usr/local/spine/etc/spine.conf  \
      && sed -i 's/$DB_NAME/'$DB_NAME'/g' /usr/local/spine/etc/spine.conf \
      && sed -i 's/$DB_USERNAME/'$DB_USERNAME'/g' /usr/local/spine/etc/spine.conf \
      && sed -i 's/$DB_PASSWORD/'$DB_PASSWORD'/g' /usr/local/spine/etc/spine.conf \
      && sed -i 's/$DB_PORT/3306/g' /usr/local/spine/etc/spine.conf \
      && chown -R www-data:www-data /usr/local/spine/
    fi
}

update_rra_path() {
    mkdir -p /var/www/html/cacti/rra/backup/ /var/www/html/cacti/rra/archive/ \
    && chown -R www-data:www-data /var/www/html/cacti/rra/
}

start_flow_capture() {
    service flow-capture start
}

spine_db_update() {
    set -x \
    && mysql -h $DB_HOSTNAME -u$DB_USERNAME -p $DB_PASSWORD -e "REPLACE INTO cacti.settings SET name='path_spine', value='/usr/local/spine/bin/spine';" \
    && echo "spine configuration updated"
}

start_supervisord(){
  supervisord --configuration=/docker/configurations/supervisord/supervisor.conf
}

echo "Setting up cron"
chmod +x /usr/local/bin/setup-cron
su -c "/usr/local/bin/setup-cron" -s /bin/sh



if [ "$1" = "cacti" ];then
  set -x \
  && update_cacti_db_config \
  && update_spine_config \
  && update_rra_path \
  && start_supervisord
fi

#echo "Starting cron"
#	cron
#echo "Starting apache"
	#apache2-foreground
