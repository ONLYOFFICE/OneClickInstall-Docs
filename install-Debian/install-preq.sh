#!/bin/bash

set -e

cat<<EOF

#######################################
#  INSTALL PREREQUISITES
#######################################

EOF

if [ "$DIST" = "debian" ] && [ $(apt-cache search ttf-mscorefonts-installer | wc -l) -eq 0 ]; then
    REPO_URL=$([ "$DISTRIB_CODENAME" = "buster" ] && echo "http://archive.debian.org/debian/" || echo "http://ftp.uk.debian.org/debian/")
    echo -e "deb $REPO_URL $DISTRIB_CODENAME main contrib\ndeb-src $REPO_URL $DISTRIB_CODENAME main contrib" > /etc/apt/sources.list
fi

apt-get -y update

if ! command -v locale-gen &> /dev/null; then
    apt-get install -yq locales
fi

if ! dpkg -l | grep -q "dirmngr"; then
    apt-get install -yq dirmngr
fi

if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    apt-get install -yq curl
fi

locale-gen en_US.UTF-8

#add nginx repo
if [[ "$DISTRIB_CODENAME" != noble ]]; then
    curl -s http://nginx.org/keys/nginx_signing.key | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/nginx.gpg --import
    chmod 644 /usr/share/keyrings/nginx.gpg
    echo "deb [signed-by=/usr/share/keyrings/nginx.gpg] http://nginx.org/packages/$DIST/ $DISTRIB_CODENAME nginx" | tee /etc/apt/sources.list.d/nginx.list
    #Temporary fix for missing nginx repository for debian bookworm
    [ "$DISTRIB_CODENAME" = "bookworm" ] && sed -i "s/$DISTRIB_CODENAME/buster/g" /etc/apt/sources.list.d/nginx.list
fi

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
