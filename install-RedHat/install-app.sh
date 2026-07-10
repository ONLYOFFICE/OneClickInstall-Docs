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

ds_pkg_name="${package_sysname}-documentserver"
case "${INSTALLATION_TYPE}" in
    "DEVELOPER") ds_pkg_name+="-de" ;;
    "ENTERPRISE") ds_pkg_name+="-ee" ;;
esac

if [ "$UPDATE" = "true" ] && [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
    ds_pkg_installed_name=$(rpm -qa --qf '%{NAME}\n' | grep "${package_sysname}-documentserver")
    if [ "${ds_pkg_installed_name}" != "${ds_pkg_name}" ]; then
        dnf -y remove "${ds_pkg_installed_name}"
        DOCUMENT_SERVER_INSTALLED="false"
    else
        dnf -y update "${ds_pkg_installed_name}" --nobest # --no-best for rhel 8 compatibility
    fi
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "false" ]; then
    declare -x DS_PORT=${DS_PORT:-80}
    declare -x JWT_ENABLED=${JWT_ENABLED:-true}
    declare -x JWT_SECRET=${JWT_SECRET:-$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)}
    declare -x JWT_HEADER=${JWT_HEADER:-AuthorizationJwt}
    [ -n "${WOPI_ENABLED}" ] && declare -x WOPI_ENABLED

    if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
        DS_COMMON_NAME=${DS_COMMON_NAME:-ds}
        DS_DB_HOST=${DS_DB_HOST:-localhost}
        DS_DB_NAME=${DS_DB_NAME:-$DS_COMMON_NAME}
        DS_DB_USER=${DS_DB_USER:-$DS_COMMON_NAME}
        DS_DB_PWD=${DS_DB_PWD:-$DS_COMMON_NAME}

        if ! su - postgres -s /bin/bash -c "psql -lqt" | cut -d \| -f 1 | grep -q "${DS_DB_NAME}"; then
            su - postgres -s /bin/bash -c "psql -c \"CREATE USER ${DS_DB_USER} WITH password '${DS_DB_PWD}';\""
            su - postgres -s /bin/bash -c "psql -c \"CREATE DATABASE ${DS_DB_NAME} OWNER ${DS_DB_USER};\""
        fi
    fi
    
    dnf -y install "${ds_pkg_name}" --nobest # --nobest for rhel 8 compatibility

    if [ "${DS_PORT}" = "80" ]; then
        [ -e /etc/nginx/nginx.conf ] && sed -i "s/ default_server//" /etc/nginx/nginx.conf && \
            echo "Note: removed default_server from /etc/nginx/nginx.conf to avoid conflict with ${ds_pkg_name}."
        [ -e /etc/nginx/conf.d/default.conf ] && \
            mv -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled && \
            echo "Note: nginx default site disabled to avoid conflict with ${ds_pkg_name}."
        systemctl stop nginx || true
    fi

    ds_configure_args=()
    if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
        ds_configure_args=(
            --redishost "${DS_REDIS_HOST:-localhost}"
            --amqphost "${DS_RABBITMQ_HOST:-localhost}"
            --amqpuser "${DS_RABBITMQ_USER:-guest}"
            --amqppassword "${DS_RABBITMQ_PWD:-guest}"
            --databasehost "${DS_DB_HOST:-localhost}"
            --databasename "$DS_DB_NAME"
            --databaseuser "$DS_DB_USER"
            --databasepassword "$DS_DB_PWD"
        )
    fi
    documentserver-configure "${ds_configure_args[@]}"
fi

if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --zone=public --add-service=http --add-service=https
    firewall-cmd --permanent --zone=public --add-port="${DS_PORT:-80}/tcp"
    firewall-cmd --reload
fi

echo ""
echo "$RES_INSTALL_SUCCESS"
echo "$RES_QUESTIONS"
echo ""
