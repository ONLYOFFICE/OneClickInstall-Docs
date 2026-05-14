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

package_manager="yum"
package_sysname="onlyoffice"

package_services=""
DS_COMMON_NAME="onlyoffice"
RES_APP_INSTALLED="is already installed"
RES_APP_CHECK_PORTS="Application uses the following ports"
RES_CHECK_PORTS="Please make sure that the ports are free."
RES_INSTALL_SUCCESS="Thank you for installing ONLYOFFICE Docs."
RES_QUESTIONS="In case you have any questions contact us via http://support.onlyoffice.com or visit our forum at http://forum.onlyoffice.com"


res_rabbitmq_update () {
    RES_RABBITMQ_VERSION="You have an old version of RabbitMQ installed. The update will cause the RabbitMQ database to be deleted."
    RES_RABBITMQ_REMINDER="If you use the database only in the ONLYOFFICE configuration, then the update will be safe for you."
    RES_RABBITMQ_INSTALLATION="Select 'Y' to install the new version of RabbitMQ (recommended). Select 'N' to keep the current version of RabbitMQ."
    RES_CHOICE_RABBITMQ="Install a new version of RabbitMQ [Y/N]?"
}

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
                JWT_ENABLED=$2
                shift
            fi
        ;;

        -jh | --jwtheader )
            if [ "$2" != "" ]; then
                JWT_HEADER=$2
                shift
            fi
        ;;

        -js | --jwtsecret )
            if [ "$2" != "" ]; then
                JWT_SECRET=$2
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

DOWNLOAD_URL_PREFIX="https://download.onlyoffice.com/docs/install-RedHat"
[ -n "${GIT_BRANCH}" ] && DOWNLOAD_URL_PREFIX="https://raw.githubusercontent.com/ONLYOFFICE/OneClickInstall-Docs/${GIT_BRANCH}/install-RedHat"

if [ "${UNINSTALL}" = "true" ]; then
    if [ "${LOCAL_SCRIPTS}" == "true" ]; then
        source install-RedHat/uninstall.sh
    else
        source <(curl ${DOWNLOAD_URL_PREFIX}/uninstall.sh)
    fi
    exit 0
fi

cat > /etc/yum.repos.d/onlyoffice.repo <<END
[onlyoffice]
name=onlyoffice repo
baseurl=http://download.onlyoffice.com/repo/centos/main/noarch/
gpgcheck=1
gpgkey=https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE
enabled=1
END

if [ "$LOCAL_SCRIPTS" == "true" ]; then
    source install-RedHat/tools.sh
    source install-RedHat/check-ports.sh
    [ -f /etc/amazon-linux-release ] && source install-RedHat/install-preq-amzn.sh || source install-RedHat/install-preq.sh
    source install-RedHat/install-app.sh
else
    source <(curl ${DOWNLOAD_URL_PREFIX}/tools.sh)
    source <(curl ${DOWNLOAD_URL_PREFIX}/check-ports.sh)
    [ -f /etc/amazon-linux-release ] && source <(curl ${DOWNLOAD_URL_PREFIX}/install-preq-amzn.sh) || source <(curl ${DOWNLOAD_URL_PREFIX}/install-preq.sh)
    source <(curl ${DOWNLOAD_URL_PREFIX}/install-app.sh)
fi
