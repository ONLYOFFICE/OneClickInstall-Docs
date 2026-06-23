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

PARAMETERS="-it COMMUNITY $PARAMETERS"
DOCKER=""
LOCAL_SCRIPTS="false"
HELP="false"

while [ "$1" != "" ]; do
    case $1 in
        -ls | --localscripts )
            if [ "$2" == "true" ] || [ "$2" == "false" ]; then
                PARAMETERS="$PARAMETERS ${1}"
                LOCAL_SCRIPTS=$2
                shift
            fi
        ;;

        -uni | --uninstall )
            if [ "$2" == "true" ] || [ "$2" == "false" ]; then
                PARAMETERS="$PARAMETERS ${1}"
                UNINSTALL=$2
                shift
            fi
        ;;

        -gb | --gitbranch )
            if [ "$2" != "" ]; then
                GIT_BRANCH=$2
                shift 2
                continue
            fi
        ;;

        "-?" | -h | --help )
            HELP="true"
            DOCKER="true"
            PARAMETERS="$PARAMETERS -ht $(basename "$0")"
        ;;
    esac
    PARAMETERS="$PARAMETERS ${1}"
    shift
done

root_checking () {
	[[ $EUID -eq 0 ]] || { echo "To perform this action you must be logged in with root rights"; exit 1; }
}

is_command_exists () {
    type "$1" &> /dev/null
}

install_curl () {
	if is_command_exists apt-get; then
		apt-get -y update
		apt-get -y -q install curl
	elif is_command_exists yum; then
		yum -y install curl
	fi

	is_command_exists curl || { echo "Command curl not found."; exit 1; }
}

read_installation_method() {
    echo "Select 'Y' to install ONLYOFFICE Docs using Docker (recommended)."
    echo "Select 'N' to install it using RPM/DEB packages."
    while true; do
        read -p "Install with Docker [Y/N/C]? " choice
        case "$choice" in
            [yY]) DOCKER="true"; break ;;
            [nN]) DOCKER="false"; break ;;
            [cC]) exit 0 ;;
            *) echo "Please, enter Y, N, or C to cancel." ;;
        esac
    done
}

root_checking

is_command_exists curl || install_curl

if [ "$UNINSTALL" = "true" ] && is_command_exists docker && docker ps -a --format '{{.Names}}' | grep -qx 'onlyoffice-document-server'; then
    DOCKER="true"
fi

[ "$HELP" == "false" ] && [ "$UNINSTALL" != "true" ] && [ -z "$DOCKER" ] && read_installation_method

if [ "$DOCKER" = "true" ]; then
    SCRIPT="install.sh"
elif [ -f /etc/redhat-release ] || [ -f /etc/amazon-linux-release ]; then
    SCRIPT="install-RedHat.sh"
elif [ -f /etc/debian_version ] || grep -qi "openkylin" /etc/os-release; then
    SCRIPT="install-Debian.sh"
else
    echo "Not supported OS" >&2
    exit 1
fi

DOWNLOAD_URL_PREFIX="http://download.onlyoffice.com/docs"
[ -n "$GIT_BRANCH" ] && DOWNLOAD_URL_PREFIX="https://raw.githubusercontent.com/ONLYOFFICE/OneClickInstall-Docs/${GIT_BRANCH}"
[ "$LOCAL_SCRIPTS" != "true" ] && curl -s -O "${DOWNLOAD_URL_PREFIX}/${SCRIPT}"
bash ${SCRIPT} ${PARAMETERS} || EXIT_CODE=$?
[ "${LOCAL_SCRIPTS}" != "true" ] && rm -f "${SCRIPT}"
exit ${EXIT_CODE:-0}
