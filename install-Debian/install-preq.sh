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

apt-get -y update
apt-get install -yq locales dirmngr curl

locale-gen en_US.UTF-8

# setup msttcorefonts
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections
if [ "$DIST" = "debian" ] && ! apt-cache show ttf-mscorefonts-installer &>/dev/null; then
    printf 'deb http://deb.debian.org/debian/ %s main contrib\ndeb-src http://deb.debian.org/debian/ %s main contrib\n' \
        "$DISTRIB_CODENAME" "$DISTRIB_CODENAME" > /etc/apt/sources.list
fi

#add nginx repo
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --batch --yes --dearmor -o /usr/share/keyrings/nginx.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx.gpg] https://nginx.org/packages/$DIST/ $DISTRIB_CODENAME nginx" | tee /etc/apt/sources.list.d/nginx.list

apt-get -y update

[ "$INSTALLATION_TYPE" != "COMMUNITY" ] && _ee_pkgs="redis-server postgresql rabbitmq-server" || _ee_pkgs=
apt-get install -yq wget \
                nano \
                nginx \
                expect \
                ${_ee_pkgs}

if [ -e /etc/redis/redis.conf ]; then
    sed -E -i "s_^bind.*_bind 127.0.0.1_; /^save\s[0-9]+/d" /etc/redis/redis.conf
    systemctl restart redis-server
fi
