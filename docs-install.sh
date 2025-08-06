#!/bin/bash

 #
 # (c) Copyright Ascensio System SIA 2025
 #
 # This program is a free software product. You can redistribute it and/or
 # modify it under the terms of the GNU Affero General Public License (AGPL)
 # version 3 as published by the Free Software Foundation. In accordance with
 # Section 7(a) of the GNU AGPL its Section 15 shall be amended to the effect
 # that Ascensio System SIA expressly excludes the warranty of non-infringement
 # of any third-party rights.
 #
 # This program is distributed WITHOUT ANY WARRANTY; without even the implied
 # warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. For
 # details, see the GNU AGPL at: http://www.gnu.org/licenses/agpl-3.0.html
 #
 # You can contact Ascensio System SIA at 20A-12 Ernesta Birznieka-Upisha
 # street, Riga, Latvia, EU, LV-1050.
 #
 # The interactive user interfaces in modified source and object code versions
 # of the Program must display Appropriate Legal Notices, as required under
 # Section 5 of the GNU AGPL version 3.
 #
 # Pursuant to Section 7(b) of the License you must retain the original Product
 # logo when distributing the program. Pursuant to Section 7(e) we decline to
 # grant you any rights under trademark law for use of our trademarks.
 #
 # All the Product's GUI elements, including illustrations and icon sets, as
 # well as technical writing content are licensed under the terms of the
 # Creative Commons Attribution-ShareAlike 4.0 International. See the License
 # terms at http://creativecommons.org/licenses/by-sa/4.0/legalcode
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

[ "$HELP" == "false" ] && read_installation_method

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

[ "$LOCAL_SCRIPTS" != "true" ] && curl -s -O "http://download.onlyoffice.com/docs/${SCRIPT}"
bash ${SCRIPT} ${PARAMETERS} || EXIT_CODE=$?
[ "${LOCAL_SCRIPTS}" != "true" ] && rm -f "${SCRIPT}"
exit ${EXIT_CODE:-0}
