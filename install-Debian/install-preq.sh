#!/bin/bash

set -e

cat<<EOF

#######################################
#  INSTALL PREREQUISITES
#######################################

EOF

if [ "$DIST" = "debian" ] && [ $(apt-cache search ttf-mscorefonts-installer | wc -l) -eq 0 ]; then
		echo "deb http://ftp.uk.debian.org/debian/ $DISTRIB_CODENAME main contrib" >> /etc/apt/sources.list
		echo "deb-src http://ftp.uk.debian.org/debian/ $DISTRIB_CODENAME main contrib" >> /etc/apt/sources.list
fi

apt-get -y update

if ! dpkg -l | grep -q "locales"; then
	apt-get install -yq locales
fi

if ! dpkg -l | grep -q "dirmngr"; then
	apt-get install -yq dirmngr
fi

if ! dpkg -l | grep -q "software-properties-common"; then
	apt-get install -yq software-properties-common
fi

if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
  apt-get install -yq curl;
fi

locale-gen en_US.UTF-8

#add nginx repo
wget http://nginx.org/keys/nginx_signing.key
apt-key add nginx_signing.key
echo "deb [arch=$ARCH] http://nginx.org/packages/$DIST/ $DISTRIB_CODENAME nginx" | tee /etc/apt/sources.list.d/nginx.list
rm nginx_signing.key

# setup msttcorefonts
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

# install
apt-get install -yq wget \
				nano \
				postgresql \
				redis-server \
				rabbitmq-server \
				nginx-extras \
				expect
		
if [ -e /etc/redis/redis.conf ]; then
 sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis/redis.conf
 sed -r "/^save\s[0-9]+/d" -i /etc/redis/redis.conf
 
 service redis-server restart
fi
