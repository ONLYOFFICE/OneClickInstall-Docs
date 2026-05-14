#!/bin/bash

 #
 # Copyright (C) Ascensio System SIA, 2009-2026
 #
 # This program is a free software product. You can redistribute it and/or
 # modify it under the terms of the GNU Affero General Public License (AGPL)
 # version 3 as published by the Free Software Foundation, together with the
 # additional terms provided in the LICENSE file.
 #
 # This program is distributed WITHOUT ANY WARRANTY; without even the implied
 # warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. For
 # details, see the GNU AGPL at: https://www.gnu.org/licenses/agpl-3.0.html
 #
 # You can contact Ascensio System SIA by email at info@onlyoffice.com
 # or by postal mail at 20A-6 Ernesta Birznieka-Upisha Street, Riga,
 # LV-1050, Latvia, European Union.
 #
 # The interactive user interfaces in modified versions of the Program
 # are required to display Appropriate Legal Notices in accordance with
 # Section 5 of the GNU AGPL version 3.
 #
 # No trademark rights are granted under this License.
 #
 # All non-code elements of the Product, including illustrations,
 # icon sets, and technical writing content, are licensed under the
 # Creative Commons Attribution-ShareAlike 4.0 International License:
 # https://creativecommons.org/licenses/by-sa/4.0/legalcode
 #
 # This license applies only to such non-code elements and does not
 # modify or replace the licensing terms applicable to the Program's
 # source code, which remains licensed under the GNU Affero General
 # Public License v3.
 #
 # SPDX-License-Identifier: AGPL-3.0-only
 #

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
[ "$INSTALLATION_TYPE" != "COMMUNITY" ] && _ee_pkgs="redis-server postgresql rabbitmq-server" || _ee_pkgs=
apt-get install -yq wget \
                nano \
                nginx-extras \
                expect \
                ${_ee_pkgs}

if [ -e /etc/redis/redis.conf ]; then
    sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis/redis.conf
    sed -r "/^save\s[0-9]+/d" -i /etc/redis/redis.conf
    service redis-server restart
fi
