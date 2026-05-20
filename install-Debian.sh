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

package_sysname="onlyoffice"
DS_COMMON_NAME="onlyoffice"
RES_APP_INSTALLED="is already installed"
RES_APP_CHECK_PORTS="Application uses the following ports"
RES_CHECK_PORTS="Please make sure that the ports are free."
RES_INSTALL_SUCCESS="Thank you for installing ONLYOFFICE Docs."
RES_QUESTIONS="In case you have any questions contact us via http://support.onlyoffice.com or visit our forum at http://forum.onlyoffice.com"

while [ "$1" != "" ]; do
    case $1 in

        -it | --installationtype | --installation_type )
            if [ "$2" != "" ]; then
                INSTALLATION_TYPE=$(echo "$2" | awk '{print toupper($0)}')
                shift
            fi
        ;;

        -skiphc | --skiphardwarecheck )
            if [ "$2" != "" ]; then
                SKIP_HARDWARE_CHECK=$2
                shift
            fi
        ;;

        -u | --update )
            if [ "$2" != "" ]; then
                UPDATE=$2
                shift
            fi
        ;;

        -uni | --uninstall )
            if [ "$2" != "" ]; then
                UNINSTALL=$2
                shift
            fi
        ;;

        -je | --jwtenabled )
            if [ "$2" != "" ]; then
                DS_JWT_ENABLED=$2
                shift
            fi
        ;;

        -jh | --jwtheader )
            if [ "$2" != "" ]; then
                DS_JWT_HEADER=$2
                shift
            fi
        ;;

        -js | --jwtsecret )
            if [ "$2" != "" ]; then
                DS_JWT_SECRET=$2
                shift
            fi
        ;;

        -we | --wopienabled )
            if [ "$2" != "" ]; then
                WOPI_ENABLED=$2
                shift
            fi
        ;;

        -gb | --gitbranch )
            if [ "$2" != "" ]; then
                GIT_BRANCH=$2
                shift
            fi
        ;;

        -ls | --localscripts )
            if [ "$2" != "" ]; then
                LOCAL_SCRIPTS=$2
                shift
            fi
        ;;

        -dp | --docsport )
            if [ "$2" != "" ]; then
                DS_PORT=$2
                shift
            fi
        ;;

        -? | -h | --help )
            echo "  Usage $0 [PARAMETER] [[PARAMETER], ...]"
            echo "    Parameters:"
            echo "      -it, --installationtype           installation type (COMMUNITY|ENTERPRISE|DEVELOPER)"
            echo "      -u, --update                      use to update existing components (true|false)"
            echo "      -uni, --uninstall                 uninstall ONLYOFFICE Docs (true|false)"
            echo "      -skiphc, --skiphardwarecheck      use to skip hardware check (true|false)"
            echo "      -je, --jwtenabled                 specifies whether JWT validation is enabled (true|false)"
            echo "      -jh, --jwtheader                  defines the HTTP header that will be used to send the JWT"
            echo "      -js, --jwtsecret                  defines the secret key to validate the JWT in the request"
            echo "      -we, --wopienabled                specifies whether WOPI protocol is enabled (true|false)"
            echo "      -ls, --localscripts               use 'true' to run local scripts (true|false)"
            echo "      -dp, --docsport                   docs port (default value 80)"
            echo "      -?, -h, --help                    this help"
            echo
            exit 0
        ;;

    esac
    shift
done

if [ -z "${INSTALLATION_TYPE}" ]; then
    INSTALLATION_TYPE=${INSTALLATION_TYPE:-ENTERPRISE}
fi

if [ -z "${UPDATE}" ]; then
    UPDATE="false"
fi

if [ -z "${SKIP_HARDWARE_CHECK}" ]; then
    SKIP_HARDWARE_CHECK="false"
fi

if [ -z "${LOCAL_SCRIPTS}" ]; then
    LOCAL_SCRIPTS="false"
fi

if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    apt-get install -yq curl
fi

DOWNLOAD_URL_PREFIX="https://download.onlyoffice.com/docs/install-Debian"
[ -n "${GIT_BRANCH}" ] && DOWNLOAD_URL_PREFIX="https://raw.githubusercontent.com/ONLYOFFICE/OneClickInstall-Docs/${GIT_BRANCH}/install-Debian"

if [ "${UNINSTALL}" = "true" ]; then
    if [ "${LOCAL_SCRIPTS}" == "true" ]; then
        source install-Debian/uninstall.sh
    else
        source <(curl ${DOWNLOAD_URL_PREFIX}/uninstall.sh)
    fi
    exit 0
fi

timeout 60s bash -c 'while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done' || { echo "Error: Lock not released"; exit 1; }

apt-get -y update
apt-get install -yq sudo dirmngr

# add onlyoffice repo
mkdir -p -m 700 $HOME/.gnupg
echo "deb [signed-by=/usr/share/keyrings/onlyoffice.gpg] http://download.onlyoffice.com/repo/debian squeeze main" | tee /etc/apt/sources.list.d/onlyoffice.list
curl -fsSL https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/onlyoffice.gpg --import
chmod 644 /usr/share/keyrings/onlyoffice.gpg

declare -x LANG="en_US.UTF-8"
declare -x LANGUAGE="en_US:en"
declare -x LC_ALL="en_US.UTF-8"

if [ "${LOCAL_SCRIPTS}" == "true" ]; then
    source install-Debian/tools.sh
    source install-Debian/check-ports.sh
    source install-Debian/install-preq.sh
    source install-Debian/install-app.sh
else
    source <(curl ${DOWNLOAD_URL_PREFIX}/tools.sh)
    source <(curl ${DOWNLOAD_URL_PREFIX}/check-ports.sh)
    source <(curl ${DOWNLOAD_URL_PREFIX}/install-preq.sh)
    source <(curl ${DOWNLOAD_URL_PREFIX}/install-app.sh)
fi
