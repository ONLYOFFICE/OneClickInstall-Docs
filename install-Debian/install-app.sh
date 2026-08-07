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
ds_pkg_source="${DS_PACKAGE_PATH:-$ds_pkg_name}"

if [ "$UPDATE" = "true" ] && [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
    ds_pkg_installed_name=$(dpkg -l | awk -v pkg="${package_sysname}-documentserver" '$1=="ii" && index($2,pkg)==1{print $2}' | tail -n1)
    if [ -z "${ds_pkg_installed_name}" ]; then
        DOCUMENT_SERVER_INSTALLED="false"
    elif [ -n "${ds_pkg_installed_name}" ] && [ "${ds_pkg_installed_name}" != "${ds_pkg_name}" ]; then
        apt-get remove -yq "${ds_pkg_installed_name}"
        DOCUMENT_SERVER_INSTALLED="false"
    else
        if [ -n "${DS_PACKAGE_PATH}" ]; then
            apt-get install -yq "${ds_pkg_source}"
        else
            apt-get install -y --only-upgrade "${ds_pkg_name}"
        fi
    fi
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "false" ]; then
    DS_COMMON_NAME=${DS_COMMON_NAME:-"ds"}
    DS_PORT=${DS_PORT:-80}
    DS_JWT_ENABLED=${DS_JWT_ENABLED:-true}
    DS_JWT_SECRET=${DS_JWT_SECRET:-$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)}
    DS_JWT_HEADER=${DS_JWT_HEADER:-AuthorizationJwt}

    echo ${ds_pkg_name} $DS_COMMON_NAME/ds-port select $DS_PORT | sudo debconf-set-selections
    echo ${ds_pkg_name} $DS_COMMON_NAME/jwt-enabled boolean ${DS_JWT_ENABLED} | sudo debconf-set-selections
    echo ${ds_pkg_name} $DS_COMMON_NAME/jwt-secret password ${DS_JWT_SECRET} | sudo debconf-set-selections
    echo ${ds_pkg_name} $DS_COMMON_NAME/jwt-header string ${DS_JWT_HEADER} | sudo debconf-set-selections
    [ -n "${WOPI_ENABLED}" ] && echo ${ds_pkg_name} $DS_COMMON_NAME/wopi-enabled boolean ${WOPI_ENABLED} | sudo debconf-set-selections

    if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
        echo ${ds_pkg_name} $DS_COMMON_NAME/db-pwd password "${DS_DB_PWD:-$DS_COMMON_NAME}" | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/db-user string "${DS_DB_USER:-$DS_COMMON_NAME}" | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/db-name string "${DS_DB_NAME:-$DS_COMMON_NAME}" | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/redis-host string "${DS_REDIS_HOST:-localhost}" | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/rabbitmq-host string "${DS_RABBITMQ_HOST:-localhost}" | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/rabbitmq-user string "${DS_RABBITMQ_USER:-guest}" | sudo debconf-set-selections
        echo ${ds_pkg_name} $DS_COMMON_NAME/rabbitmq-pwd password "${DS_RABBITMQ_PWD:-guest}" | sudo debconf-set-selections

        if ! su - postgres -s /bin/bash -c "psql -lqt" | cut -d \| -f 1 | grep -q "${DS_DB_NAME:-$DS_COMMON_NAME}"; then
            su - postgres -s /bin/bash -c "psql -c \"CREATE USER ${DS_DB_USER:-$DS_COMMON_NAME} WITH password '${DS_DB_PWD:-$DS_COMMON_NAME}';\""
            su - postgres -s /bin/bash -c "psql -c \"CREATE DATABASE ${DS_DB_NAME:-$DS_COMMON_NAME} OWNER ${DS_DB_USER:-$DS_COMMON_NAME};\""
        fi
    fi

    if [ "${DS_PORT}" = "80" ]; then
        [ -e /etc/nginx/sites-enabled/default ] && \
            mv -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default.disabled
        [ -e /etc/nginx/conf.d/default.conf ] && \
            mv -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled
        echo "Note: nginx default sites disabled to avoid conflict with ${ds_pkg_name}."
        systemctl is-active --quiet nginx && systemctl reload nginx || systemctl start nginx
    fi

    apt-get install -yq "${ds_pkg_source}"
fi

if [ -n "${DS_LICENSE_PATH:-}" ]; then
    install -m 644 "$DS_LICENSE_PATH" "/var/www/${package_sysname}/Data/license.lic"
    chown --reference="/var/www/${package_sysname}/Data" "/var/www/${package_sysname}/Data/license.lic"
    chmod 640 "/var/www/${package_sysname}/Data/license.lic"
    echo "[OK] License installed at /var/www/${package_sysname}/Data/license.lic"
fi

echo ""
echo "$RES_INSTALL_SUCCESS"
echo "$RES_QUESTIONS"
echo ""
