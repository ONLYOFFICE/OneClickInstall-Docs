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
#  CHECK PORTS
#######################################

EOF

if ! rpm -q net-tools &>/dev/null; then
    yum -y install net-tools
fi

[ "${INSTALLATION_TYPE}" != "COMMUNITY" ] && _ee=1 || _ee=
PORT_PATTERN="${_ee:+:5432$|:5672$|}:6379$|:8000$|:${DS_PORT:-80}$"
PORT_LIST="${_ee:+5432, 5672, }6379, 8000, ${DS_PORT:-80}"

if rpm -qa | grep ${package_sysname}-documentserver; then
    echo "${package_sysname}-documentserver $RES_APP_INSTALLED"
    DOCUMENT_SERVER_INSTALLED="true"
elif [ "${UPDATE}" != "true" ] && netstat -lnp | awk '{print $4}' | grep -qE "${PORT_PATTERN}"; then
    echo "${package_sysname}-documentserver $RES_APP_CHECK_PORTS: ${PORT_LIST}"
    echo "$RES_CHECK_PORTS"
    exit
else
    DOCUMENT_SERVER_INSTALLED="false"
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
    if [ "$UPDATE" != "true" ]; then
        exit
    fi
fi
