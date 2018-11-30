#!/bin/bash

VERSION=$1
FPM_PORT=$2
PHP_REPO=https://museum.php.net/php${VERSION:0:1}/

# Download and extract PHP

mkdir -p /opt/php-${VERSION}
mkdir -p /usr/local/src/php${VERSION:0:1}-build
cd /usr/local/src/php${VERSION:0:1}-build
wget ${PHP_REPO}php-${VERSION}.tar.bz2 -O php-${VERSION}.tar.bz2
tar jxf php-${VERSION}.tar.bz2

# Install OpenSSL
# In order to use the OpenSSL functions you need to install the » OpenSSL library.
# PHP 5 requires at least OpenSSL >= 0.9.6.
# However later PHP 5 versions have some compilation issues and should be used at least with OpenSSL >= 0.9.8
# which is also a minimal version for PHP 7.0. Other versions (PHP >= 7.1.0) require OpenSSL >= 1.0.1.
# http://php.net/manual/en/openssl.requirements.php
if [ ${VERSION:0:1} -eq 5 ] || [ $(echo ${VERSION//.} | egrep -o '[[:digit:]]{2}' | head -n1) -eq 70 ]; then
	if [ ! -d "/usr/local/openssl-0.9.8" ]; then
	    cd /usr/local/src/php${VERSION:0:1}-build
	    wget https://www.openssl.org/source/old/0.9.x/openssl-0.9.8zh.tar.gz -O openssl-0.9.8zh.tar.gz
	    tar xvfz openssl-0.9.8zh.tar.gz
	    cd openssl-0.9.8zh
	    ./config --prefix=/usr/local --openssldir=/usr/local/openssl-0.9.8
	fi
OPENSSLPATH=/usr/local/openssl-0.9.8
fi

if [ $(echo ${VERSION//.} | egrep -o '[[:digit:]]{2}' | head -n1) -ge 71 ]; then
	if [ ! -d "/usr/local/openssl-1.0.2" ]; then
	    cd /usr/local/src/php7-build
	    wget https://www.openssl.org/source/old/1.0.2/openssl-1.0.2.tar.gz -O openssl-1.0.2.tar.gz
	    tar xvfz openssl-1.0.2.tar.gz
	    cd openssl-1.0.2
	    ./config --prefix=/usr/local --openssldir=/usr/local/openssl-1.0.2
	fi
OPENSSLPATH=/usr/local/openssl-1.0.2
fi
# Build openssl
sudo make
sudo make install_sw

# Configurate php
cd /usr/local/src/php${VERSION:0:1}-build/php-${VERSION}
./configure --prefix=/opt/php-${VERSION} --with-zlib-dir --with-freetype-dir --enable-mbstring --with-libxml-dir=/usr --enable-soap --enable-calendar --with-curl --with-mcrypt --with-zlib --with-gd --disable-rpath --enable-inline-optimization --with-bz2 --with-zlib --enable-sockets --enable-sysvsem --enable-sysvshm --enable-pcntl --enable-mbregex --enable-exif --enable-bcmath --with-mhash --enable-zip --with-pcre-regex --with-mysql --with-pdo-mysql --with-mysqli --with-jpeg-dir=/usr --with-png-dir=/usr --enable-gd-native-ttf --with-openssl --with-openssl-dir=${OPENSSLPATH} --with-fpm-user=www-data --with-fpm-group=www-data --with-libdir=/lib/x86_64-linux-gnu --enable-ftp --with-kerberos --with-gettext --with-xmlrpc --with-xsl --enable-fpm

# Build php
sudo make
sudo make install

# Copy php.ini
sudo cp /usr/local/src/php${VERSION:0:1}-build/php-${VERSION}/php.ini-production /opt/php-${VERSION}/lib/php.ini

# Copy php-fpm.conf
sudo cp /opt/php-${VERSION}/etc/php-fpm.conf.default /opt/php-${VERSION}/etc/php-fpm.conf

# Edit php-fpm

sudo sed -i "s/;pid =/pid =/" /opt/php-${VERSION}/etc/php-fpm.conf

# Create the pool directory for PHP-FPM for php 5
if [ ${VERSION:0:1} -eq 5 ]; then
	sudo sed -i "s/:9000/:${FPM_PORT}/" /opt/php-${VERSION}/etc/php-fpm.conf
	sudo sed -i "s/;include=.*/include=\/opt\/php-${VERSION}\/etc\/pool.d\/*.conf/g" /opt/php-${VERSION}/etc/php-fpm.conf
	sudo mkdir /opt/php-${VERSION}/etc/pool.d
fi

# Copy www.conf for php7
if [ ${VERSION:0:1} -eq 7 ]; then
	sudo sed -i "s/:9000/:${FPM_PORT}/" /opt/php-${VERSION}/etc/php-fpm.d/www.conf.default
	sudo cp /opt/php-${VERSION}/etc/php-fpm.d/www.conf.default /opt/php-${VERSION}/etc/php-fpm.d/www.conf
fi
# Next create an init script for PHP-FPM
cat > /etc/init.d/php-${VERSION}-fpm<<'SCRIPT'
#! /bin/sh
### BEGIN INIT INFO
# Provides:          php-VERSION-fpm
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts php-VERSION-fpm
# Description:       starts the PHP FastCGI Process Manager daemon
### END INIT INFO
php_fpm_BIN=/opt/php-VERSION/sbin/php-fpm
php_fpm_CONF=/opt/php-VERSION/etc/php-fpm.conf
php_fpm_PID=/opt/php-VERSION/var/run/php-fpm.pid
php_opts="--fpm-config $php_fpm_CONF"
wait_for_pid () {
        try=0
        while test $try -lt 35 ; do
                case "$1" in
                        'created')
                        if [ -f "$2" ] ; then
                                try=''
                                break
                        fi
                        ;;
                        'removed')
                        if [ ! -f "$2" ] ; then
                                try=''
                                break
                        fi
                        ;;
                esac
                echo -n .
                try=`expr $try + 1`
                sleep 1
        done
}
case "$1" in
        start)
                echo -n "Starting php-fpm "
                $php_fpm_BIN $php_opts
                if [ "$?" != 0 ] ; then
                        echo " failed"
                        exit 1
                fi
                wait_for_pid created $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed"
                        exit 1
                else
                        echo " done"
                fi
        ;;
        stop)
                echo -n "Gracefully shutting down php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -QUIT `cat $php_fpm_PID`
                wait_for_pid removed $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed. Use force-exit"
                        exit 1
                else
                        echo " done"
                       echo " done"
                fi
        ;;
        force-quit)
                echo -n "Terminating php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -TERM `cat $php_fpm_PID`
                wait_for_pid removed $php_fpm_PID
                if [ -n "$try" ] ; then
                        echo " failed"
                        exit 1
                else
                        echo " done"
                fi
        ;;
        restart)
                $0 stop
                $0 start
        ;;
        reload)
                echo -n "Reload service php-fpm "
                if [ ! -r $php_fpm_PID ] ; then
                        echo "warning, no pid file found - php-fpm is not running ?"
                        exit 1
                fi
                kill -USR2 `cat $php_fpm_PID`
                echo " done"
        ;;
        *)
                echo "Usage: $0 {start|stop|force-quit|restart|reload}"
                exit 1
        ;;
esac
SCRIPT

# REPLACE VERSION FOR STARTUP SCRIPT
sudo sed -i "s/VERSION/${VERSION}/" /etc/init.d/php-${VERSION}-fpm

# Make the init script executable and create the system startup links
chmod 755 /etc/init.d/php-${VERSION}-fpm
insserv php-${VERSION}-fpm

# Finally start PHP-FPM
sudo /etc/init.d/php-${VERSION}-fpm start