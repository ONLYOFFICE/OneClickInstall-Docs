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
#  INSTALL APP
#######################################

EOF

for SVC in $package_services; do
    systemctl start $SVC
    systemctl enable $SVC
done

if [ "$INSTALLATION_TYPE" = "COMMUNITY" ]; then
    ds_pkg_name="${package_sysname}-documentserver"
elif [ "$INSTALLATION_TYPE" = "ENTERPRISE" ]; then
    ds_pkg_name="${package_sysname}-documentserver-ee"
elif [ "$INSTALLATION_TYPE" = "DEVELOPER" ]; then
    ds_pkg_name="${package_sysname}-documentserver-de"
fi

if [ "$UPDATE" = "true" ] && [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
    ds_pkg_installed_name=$(rpm -qa --qf '%{NAME}\n' | grep ${package_sysname}-documentserver)
    if [ ${ds_pkg_installed_name} != ${ds_pkg_name} ]; then
        ${package_manager} -y remove ${ds_pkg_installed_name}
        DOCUMENT_SERVER_INSTALLED="false"
    else
        ${package_manager} -y update ${ds_pkg_installed_name} --nobest # --no-best for rhel 8 compatibility
    fi
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "false" ]; then
    declare -x DS_PORT=${DS_PORT:-80}

    DS_COMMON_NAME=${DS_COMMON_NAME:-"ds"}

    if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
        DS_DB_HOST=localhost
        DS_DB_NAME=$DS_COMMON_NAME
        DS_DB_USER=$DS_COMMON_NAME
        DS_DB_PWD=$DS_COMMON_NAME
        DS_REDIS_HOST=localhost
        DS_RABBITMQ_HOST=localhost
        DS_RABBITMQ_USER=guest
        DS_RABBITMQ_PWD=guest

        if ! su - postgres -s /bin/bash -c "psql -lqt" | cut -d \| -f 1 | grep -q ${DS_DB_NAME}; then
            su - postgres -s /bin/bash -c "psql -c \"CREATE USER ${DS_DB_USER} WITH password '${DS_DB_PWD}';\""
            su - postgres -s /bin/bash -c "psql -c \"CREATE DATABASE ${DS_DB_NAME} OWNER ${DS_DB_USER};\""
        fi
    fi

    declare -x JWT_ENABLED=${JWT_ENABLED:-true}
    declare -x JWT_SECRET=${JWT_SECRET:-$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)}
    declare -x JWT_HEADER=${JWT_HEADER:-AuthorizationJwt}
    [ -n "${WOPI_ENABLED}" ] && declare -x WOPI_ENABLED

    ${package_manager} -y install ${ds_pkg_name} --nobest # --nobest for rhel 8 compatibility
    sed -i "s/ default_server//" /etc/nginx/nginx.conf # drop default_server from nginx.conf so nginx binds port 80 without conflicts

if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
expect << EOF

    set timeout -1
    log_user 1

    spawn documentserver-configure.sh

    expect "Configuring database access..."

    expect -re "Host"
    send "\025$DS_DB_HOST\r"

    expect -re "Database name"
    send "\025$DS_DB_NAME\r"

    expect -re "User"
    send "\025$DS_DB_USER\r"

    expect -re "Password"
    send "\025$DS_DB_PWD\r"

    expect "Configuring redis access..."
    send "\025$DS_REDIS_HOST\r"

    expect "Configuring AMQP access... "
    expect -re "Host"
    send "\025$DS_RABBITMQ_HOST\r"

    expect -re "User"
    send "\025$DS_RABBITMQ_USER\r"

    expect -re "Password"
    send "\025$DS_RABBITMQ_PWD\r"

    expect eof

EOF
else
    documentserver-configure.sh
fi
    DOCUMENT_SERVER_INSTALLED="true"
fi

if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --zone=public --add-service=http
    firewall-cmd --permanent --zone=public --add-service=https
    firewall-cmd --permanent --zone=public --add-port=${DS_PORT:-80}/tcp
    firewall-cmd --reload
fi

echo ""
echo "$RES_INSTALL_SUCCESS"
echo "$RES_QUESTIONS"
echo ""
