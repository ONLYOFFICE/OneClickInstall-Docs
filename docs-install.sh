#!/bin/bash

 #
 # (c) Copyright Ascensio System SIA 2021
 #
 # This program is a free software product. You can redistribute it and/or
 # modify it under the terms of the GNU Affero General Public License (AGPL)
 # version 3 as published by the Free Software Foundation. In accordance with
 # Section 7(a) of the GNU AGPL its Section 15 shall be amended to the effect
 # that Ascensio System SIA expressly excludes the warranty of non-infringement
 # of any third-party rights.
 #
 # This program is distributed WITHOUT ANY WARRANTY; without even the implied
 # warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR  PURPOSE. For
 # details, see the GNU AGPL at: http://www.gnu.org/licenses/agpl-3.0.html
 #
 # You can contact Ascensio System SIA at 20A-12 Ernesta Birznieka-Upisha
 # street, Riga, Latvia, EU, LV-1050.
 #
 # The  interactive user interfaces in modified source and object code versions
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

PARAMETERS="";
DOCKER="";
LOCAL_SCRIPTS="false"
HELP="false";

while [ "$1" != "" ]; do
	case $1 in
		-ls | --localscripts )
			if [ "$2" == "true" ] || [ "$2" == "false" ]; then
				PARAMETERS="$PARAMETERS ${1}";
				LOCAL_SCRIPTS=$2
				shift
			fi
		;;

		"-?" | -h | --help )
			HELP="true";
			DOCKER="true";
			PARAMETERS="$PARAMETERS -ht docs-install.sh";
		;;
	esac
	PARAMETERS="$PARAMETERS ${1}";
	shift
done

PARAMETERS="-it COMMUNITY $PARAMETERS";

root_checking () {
	if [ ! $( id -u ) -eq 0 ]; then
		echo "To perform this action you must be logged in with root rights"
		exit 1;
	fi
}

command_exists () {
	type "$1" &> /dev/null;
}

install_curl () {
	if command_exists apt-get; then
		apt-get -y update
		apt-get -y -q install curl
	elif command_exists yum; then
		yum -y install curl
	fi

	if ! command_exists curl; then
		echo "command curl not found"
		exit 1;
	fi
}

read_installation_method () {
	echo "Select 'Y' to install ONLYOFFICE Docs using Docker (recommended). Select 'N' to install it using RPM/DEB packages.";
	read -p "Install with Docker [Y/N/C]? " choice
	case "$choice" in
		y|Y )
			DOCKER="true";
		;;

		n|N )
			DOCKER="false";
		;;

		c|C )
			exit 0;
		;;

		* )
			echo "Please, enter Y, N or C to cancel";
		;;
	esac

	if [ "$DOCKER" == "" ]; then
		read_installation_method;
	fi
}

root_checking

if ! command_exists curl ; then
	install_curl;
fi

if [ "$HELP" == "false" ]; then
	read_installation_method;
fi

if [ "$DOCKER" == "true" ]; then
	if [ "$LOCAL_SCRIPTS" == "true" ]; then
		bash install.sh ${PARAMETERS}
	else
		curl -s -O http://download.onlyoffice.com/docs/install.sh
		bash install.sh ${PARAMETERS}
		rm install.sh
	fi
else
	if [ -f /etc/redhat-release ] ; then
		DIST=$(cat /etc/redhat-release |sed s/\ release.*//);
		REV=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//);

		REV_PARTS=(${REV//\./ });
		REV=${REV_PARTS[0]};

		if [[ "${DIST}" == CentOS* ]] && [ ${REV} -lt 7 ]; then
			echo "CentOS 7 or later is required";
			exit 1;
		fi

		if [ "$LOCAL_SCRIPTS" == "true" ]; then
			bash install-RedHat.sh ${PARAMETERS}
		else
			curl -s -O http://download.onlyoffice.com/docs/install-RedHat.sh
			bash install-RedHat.sh ${PARAMETERS}
			rm install-RedHat.sh
		fi
	elif [ -f /etc/debian_version ] ; then
		if [ "$LOCAL_SCRIPTS" == "true" ]; then
			bash install-Debian.sh ${PARAMETERS}
		else
			curl -s -O http://download.onlyoffice.com/docs/install-Debian.sh
			bash install-Debian.sh ${PARAMETERS}
			rm install-Debian.sh
		fi
	else
		echo "Not supported OS";
		exit 1;
	fi
fi
