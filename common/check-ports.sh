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

DS_PORT=${DS_PORT:-80}
# Match at most five significant digits before decimal conversion to avoid overflow.
if [[ "$DS_PORT" =~ ^0*([1-9][0-9]{0,4})$ ]] && (( 10#${BASH_REMATCH[1]} <= 65535 )); then
    DS_PORT=$((10#${BASH_REMATCH[1]}))
else
    echo "Error: invalid TCP port '$DS_PORT'. Expected a number between 1 and 65535." >&2
    return 1
fi

PORTS=(8000)
[ "$INSTALLATION_TYPE" = COMMUNITY ] || PORTS+=(5432 5672 6379)
if [[ " ${PORTS[*]} " = *" $DS_PORT "* ]]; then
    echo "Docs port $DS_PORT is reserved. Select another port." >&2
    return 1
fi
PORTS=("$DS_PORT" "${PORTS[@]}")

package_installed() {
    if command -v dpkg-query >/dev/null 2>&1; then
        [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" = installed ]
    else
        rpm -q "$1" >/dev/null 2>&1
    fi
}

DOCUMENT_SERVER_INSTALLED=false
for SUFFIX in "" -de -ee; do
    PACKAGE_NAME="${package_sysname}-documentserver${SUFFIX}"
    if package_installed "$PACKAGE_NAME"; then
        DOCUMENT_SERVER_INSTALLED=true
        echo "$PACKAGE_NAME $RES_APP_INSTALLED"
        return 0
    fi
done

[ "$UPDATE" != true ] || return 0

if ! command -v ss >/dev/null 2>&1; then
    if command -v dpkg-query >/dev/null 2>&1; then
        apt-get install -yq iproute2 || return 1
    else
        ${package_manager} -y install iproute || return 1
    fi
fi

LISTENERS=$(ss -H -lnt) || { echo "Error: could not read listening TCP ports with ss." >&2; return 1; }
USED_PORTS=$(awk -v ports="${PORTS[*]}" '
    BEGIN { count = split(ports, required, " ") }
    $1 == "LISTEN" { sub(/^.*:/, "", $4); busy[$4] = 1 }
    END {
        for (i = 1; i <= count; i++)
            if (required[i] in busy) { printf "%s%s", separator, required[i]; separator = ", " }
    }
' <<< "$LISTENERS") || return 1

if [ -n "$USED_PORTS" ]; then
    echo "The following TCP ports are already in use: $USED_PORTS" >&2
    return 1
fi
return 0
