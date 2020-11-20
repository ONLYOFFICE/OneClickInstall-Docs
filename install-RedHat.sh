#!/bin/bash

set -e

package_manager="yum"
package_sysname="onlyoffice";

package_services="";
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
			echo "      -ls, --local_scripts              use 'true' to run local scripts (true|false)"
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

curl -o cs.key "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x8320CA65CB2DE8E5"
echo "" >> cs.key
rpm --import cs.key
rm cs.key

cat > /etc/yum.repos.d/onlyoffice.repo <<END
[onlyoffice]
name=onlyoffice repo
baseurl=http://download.onlyoffice.com/repo/centos/main/noarch/
gpgcheck=1
enabled=1
END

DOWNLOAD_URL_PREFIX="https://download.onlyoffice.com/install/install-RedHat"


if [ "$LOCAL_SCRIPTS" == "true" ]; then
	source install-RedHat/bootstrap.sh
	source install-RedHat/check-ports.sh
	source install-RedHat/install-preq.sh
	source install-RedHat/install-app.sh
else
	### source <(curl ${DOWNLOAD_URL_PREFIX}/bootstrap.sh)
	### source <(curl ${DOWNLOAD_URL_PREFIX}/check-ports.sh)
	### source <(curl ${DOWNLOAD_URL_PREFIX}/install-preq.sh)
	### source <(curl ${DOWNLOAD_URL_PREFIX}/install-app.sh)
fi
