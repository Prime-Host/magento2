#!/bin/bash

# change php user
sed -i s/www-data/$PRIMEHOST_USER/g /usr/local/etc/php-fpm.d/*

# make all user changes only on first creation or if the user changed
if [ ! -f /home/$PRIMEHOST_USER ]; then
  # Create custom ssh_user with sudo privileges
  useradd -m -d /home/$PRIMEHOST_USER -G root -s /bin/zsh $PRIMEHOST_USER \
  && usermod -a -G $PRIMEHOST_USER $PRIMEHOST_USER \
  && usermod -a -G sudo $PRIMEHOST_USER

  # Set passwords for the custom user and root
  echo "$PRIMEHOST_USER:$PRIMEHOST_PASSWORD" | chpasswd
  echo "root:$PRIMEHOST_PASSWORD" | chpasswd
fi

# Enviroment Variables for cronjob and backup folder
printenv > /etc/environment
sed -i s,/root,/home/$PRIMEHOST_USER,g /etc/environment
if [ ! -f /home/$PRIMEHOST_USER/backup ]; then
    mkdir /home/$PRIMEHOST_USER/backup
fi

# insert cronjob
if [ ! -f /var/spool/cron/crontabs/$PRIMEHOST_USER ]; then
sudo -u $PRIMEHOST_USER bash << EOF
crontab -l | { cat; echo "TZ=Europe/Berlin
SHELL=/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
* * * * * perl -le 'sleep rand 40' && php /usr/share/nginx/www/bin/magento cron:run | grep -v 'Ran jobs by schedule' >> /usr/share/nginx/www/var/log/magento.cron.log && php /usr/share/nginx/www/update/cron.php >> /usr/share/nginx/www/var/log/update.cron.log && php /usr/share/nginx/www/bin/magento setup:cron:run >> /usr/share/nginx/www/var/log/setup.cron.log
0 3 * * * mysqldump -u"root" -p"$PRIMEHOST_PASSWORD" -h"$PRIMEHOST_DOMAIN"-db magento2 > /home/$PRIMEHOST_USER/backup/dump.sql"; } | crontab -
EOF
fi

unset PRIMEHOST_USER PRIMEHOST_PASSWORD PRIMEHOST_DOMAIN

# start all the services
/usr/bin/supervisord
