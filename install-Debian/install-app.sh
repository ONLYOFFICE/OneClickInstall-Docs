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

if [ "$INSTALLATION_TYPE" = "COMMUNITY" ]; then
    ds_pkg_name="${package_sysname}-documentserver"
elif [ "$INSTALLATION_TYPE" = "ENTERPRISE" ]; then
    ds_pkg_name="${package_sysname}-documentserver-ee"
elif [ "$INSTALLATION_TYPE" = "DEVELOPER" ]; then
    ds_pkg_name="${package_sysname}-documentserver-de"
fi

apt-get -y update

if [ "$UPDATE" = "true" ] && [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
    ds_pkg_installed_name=$(dpkg -l | grep ${package_sysname}-documentserver | tail -n1 | awk '{print $2}')

    if [ ${ds_pkg_installed_name} != ${ds_pkg_name} ]; then
        apt-get remove -yq ${ds_pkg_installed_name}
        DOCUMENT_SERVER_INSTALLED="false"
    else
        apt-get install -y --only-upgrade ${ds_pkg_installed_name}
    fi
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "false" ]; then
    DS_PORT=${DS_PORT:-80}
    DS_COMMON_NAME=${DS_COMMON_NAME:-"ds"}

    DS_JWT_ENABLED=${DS_JWT_ENABLED:-true}
    DS_JWT_SECRET=${DS_JWT_SECRET:-$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)}
    DS_JWT_HEADER=${DS_JWT_HEADER:-AuthorizationJwt}

    echo ${package_sysname}-documentserver $DS_COMMON_NAME/ds-port select $DS_PORT | sudo debconf-set-selections
    echo ${ds_pkg_name} $DS_COMMON_NAME/jwt-enabled select ${DS_JWT_ENABLED} | sudo debconf-set-selections
    echo ${ds_pkg_name} $DS_COMMON_NAME/jwt-secret select ${DS_JWT_SECRET} | sudo debconf-set-selections
    echo ${ds_pkg_name} $DS_COMMON_NAME/jwt-header select ${DS_JWT_HEADER} | sudo debconf-set-selections
    [ -n "${WOPI_ENABLED}" ] && echo ${ds_pkg_name} $DS_COMMON_NAME/wopi-enabled boolean ${WOPI_ENABLED} | sudo debconf-set-selections

    if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
        DS_DB_HOST=localhost
        DS_DB_NAME=$DS_COMMON_NAME
        DS_DB_USER=$DS_COMMON_NAME
        DS_DB_PWD=$DS_COMMON_NAME

        DS_REDIS_HOST=localhost
        DS_RABBITMQ_HOST=localhost
        DS_RABBITMQ_USER=guest
        DS_RABBITMQ_PWD=guest

        echo ${package_sysname}-documentserver $DS_COMMON_NAME/db-pwd select $DS_DB_PWD | sudo debconf-set-selections
        echo ${package_sysname}-documentserver $DS_COMMON_NAME/db-user $DS_DB_USER | sudo debconf-set-selections
        echo ${package_sysname}-documentserver $DS_COMMON_NAME/db-name $DS_DB_NAME | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/redis-host select $DS_REDIS_HOST | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/rabbitmq-host select $DS_RABBITMQ_HOST | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/rabbitmq-user select $DS_RABBITMQ_USER | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/rabbitmq-pwd select $DS_RABBITMQ_PWD | sudo debconf-set-selections

        if ! su - postgres -s /bin/bash -c "psql -lqt" | cut -d \| -f 1 | grep -q ${DS_DB_NAME}; then
            su - postgres -s /bin/bash -c "psql -c \"CREATE USER ${DS_DB_USER} WITH password '${DS_DB_PWD}';\""
            su - postgres -s /bin/bash -c "psql -c \"CREATE DATABASE ${DS_DB_NAME} OWNER ${DS_DB_USER};\""
        fi
    fi

    apt-get install -yq ${ds_pkg_name}
fi

echo ""
echo "$RES_INSTALL_SUCCESS"
echo "$RES_QUESTIONS"
echo ""
