#!/bin/bash

set -e

cat<<EOF

#######################################
#  INSTALL PREREQUISITES
#######################################

EOF

rm -f /etc/apt/sources.list.d/builds-ubuntu-sphinxsearch-rel22-bionic.list
rm -f /etc/apt/sources.list.d/certbot-ubuntu-certbot-bionic.list

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

if ! dpkg -l | grep -q "apt-transport-https"; then
	apt-get install -yq apt-transport-https
fi

if ! dpkg -l | grep -q "software-properties-common"; then
	apt-get install -yq software-properties-common
fi

if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
  apt-get install -yq curl;
fi

locale-gen en_US.UTF-8

if [ "$DIST" = "ubuntu" ]; then	
	# add java repo
	add-apt-repository -y ppa:openjdk-r/ppa

	# add redis repo
	add-apt-repository -y ppa:chris-lea/redis-server

	# ffmpeg
	if [ "$DISTRIB_CODENAME" = "trusty" ]; then
		add-apt-repository ppa:mc3man/trusty-media
	fi		
fi

# add nodejs repo
echo "deb https://deb.nodesource.com/node_12.x $DISTRIB_CODENAME main" | tee /etc/apt/sources.list.d/nodesource.list
echo "deb-src https://deb.nodesource.com/node_12.x $DISTRIB_CODENAME main" >> /etc/apt/sources.list.d/nodesource.list
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -

apt-get update

nodeversion=$(apt-cache madison nodejs | grep "| 12." | sed -n '1p' | cut -d'|' -f2 | tr -d ' ')

#add nginx repo
wget http://nginx.org/keys/nginx_signing.key
apt-key add nginx_signing.key
echo "deb [arch=$ARCH] http://nginx.org/packages/$DIST/ $DISTRIB_CODENAME nginx" | tee /etc/apt/sources.list.d/nginx.list
rm nginx_signing.key

# setup msttcorefonts
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

# add certbot repo ###
if [ "$DIST" = "ubuntu" ] && [ "$DISTRIB_CODENAME" = "focal" ]; then # Ubuntu 20.04
	snap install --classic certbot
elif [ "$DIST" = "ubuntu" ]; then
	add-apt-repository -y ppa:certbot/certbot
	apt-get -y update	
	apt-get install -yq certbot
elif [ "$DIST" = "debian" ] && [ "$DISTRIB_CODENAME" = "stretch" ]; then # Debian 9
	apt-get install -yq certbot
elif [ "$DIST" = "debian" ] && [ "$DISTRIB_CODENAME" = "jessie" ]; then # Debian 8
	echo "deb http://ftp.debian.org/debian jessie-backports main" | tee /etc/apt/sources.list.d/jessie_backports.list
	echo "deb http://www.deb-multimedia.org jessie main non-free" | tee /etc/apt/sources.list.d/deb_multimedia.list

	apt-get -y update
	apt-get install -yq certbot -t jessie-backports
	apt-get install -yq openjdk-8-jre-headless -t jessie-backports	
	apt-get install -yq deb-multimedia-keyring		
fi

# install
apt-get install -yq wget \
				cron \
				rsyslog \
				ruby-dev \
				ruby-god \
				nodejs=$nodeversion \
				htop \
				nano \
				dnsutils \
				postgresql \
				redis-server \
				rabbitmq-server \
				apt-transport-https \
				python3-pip \
				nginx-extras \
				expect

if [ "$DIST" = "debian" ] && [ "$DISTRIB_CODENAME" = "buster" ]; then
    apt-get install -yq openjdk-11-jdk
else
	apt-get install -yq openjdk-8-jre-headless 
fi

if apt-cache search --names-only '^ffmpeg$' | grep -q "ffmpeg"; then
	apt-get install -yq ffmpeg
fi
		
if [ -e /etc/redis/redis.conf ]; then
 sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis/redis.conf
 sed -r "/^save\s[0-9]+/d" -i /etc/redis/redis.conf
 
 service redis-server restart
fi
				
npm config set prefix '/usr/'