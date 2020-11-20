#!/bin/bash

set -e

package_sysname="onlyoffice";
DS_COMMON_NAME="onlyoffice";
RES_APP_INSTALLED="is already installed";
RES_APP_CHECK_PORTS="uses ports"
RES_CHECK_PORTS="please, make sure that the ports are free.";
RES_INSTALL_SUCCESS="Thank you for installing ONLYOFFICE Docs.";
RES_QUESTIONS="In case you have any questions contact us via http://support.onlyoffice.com or visit our forum at http://dev.onlyoffice.org"

while [ "$1" != "" ]; do
	case $1 in

		-it | --installation_type )
			if [ "$2" != "" ]; then
				INSTALLATION_TYPE=$(echo "$2" | awk '{print toupper($0)}');
				shift
			fi
		;;

		-u | --update )
			if [ "$2" != "" ]; then
				UPDATE=$2
				shift
			fi
		;;

		-ls | --local_scripts )
			if [ "$2" != "" ]; then
				LOCAL_SCRIPTS=$2
				shift
			fi
		;;

		-? | -h | --help )
			echo "  Usage $0 [PARAMETER] [[PARAMETER], ...]"
			echo "    Parameters:"
			echo "      -it, --installation_type          installation type (COMMUNITY|ENTERPRISE|DEVELOPER)"
			echo "      -u, --update                      use to update existing components (true|false)"
			echo "      -ls, --local_scripts			  use 'true' to run local scripts (true|false)"
			echo "      -?, -h, --help                    this help"
			echo
			exit 0
		;;

	esac
	shift
done

if [ -z "${INSTALLATION_TYPE}" ]; then
   INSTALLATION_TYPE="ENTERPRISE";
fi

if [ -z "${UPDATE}" ]; then
   UPDATE="false";
fi

if [ -z "${LOCAL_SCRIPTS}" ]; then
   LOCAL_SCRIPTS="false";
fi

if [ $(dpkg-query -W -f='${Status}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
  apt-get update;
  apt-get install -yq curl;
fi

DOWNLOAD_URL_PREFIX="https://download.onlyoffice.com/install/install-Debian"
if [ "${LOCAL_SCRIPTS}" == "true" ]; then
	source install-Debian/bootstrap.sh
else
	### source <(curl ${DOWNLOAD_URL_PREFIX}/bootstrap.sh)
fi

# add onlyoffice repo
echo "deb http://download.onlyoffice.com/repo/debian squeeze main" | tee /etc/apt/sources.list.d/onlyoffice.list
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5

declare -x LANG="en_US.UTF-8"
declare -x LANGUAGE="en_US:en"
declare -x LC_ALL="en_US.UTF-8"

if [ "${LOCAL_SCRIPTS}" == "true" ]; then
	source install-Debian/tools.sh
	source install-Debian/check-ports.sh
	source install-Debian/install-preq.sh
	source install-Debian/install-app.sh
else
	### source <(curl ${DOWNLOAD_URL_PREFIX}/tools.sh)
	### source <(curl ${DOWNLOAD_URL_PREFIX}/check-ports.sh)
	### source <(curl ${DOWNLOAD_URL_PREFIX}/install-preq.sh)
	### source <(curl ${DOWNLOAD_URL_PREFIX}/install-app.sh)
fi
