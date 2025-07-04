#!/bin/bash

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

res_unsupported_version () {
    RES_CHOICE="Please, enter Y or N"
    RES_CHOICE_INSTALLATION="Continue installation [Y/N]? "
    RES_UNSUPPORTED_VERSION="You have an unsupported version of $DIST installed"
    RES_SELECT_INSTALLATION="Select 'N' to cancel the ONLYOFFICE installation (recommended). Select 'Y' to continue installing ONLYOFFICE"
    RES_ERROR_REMINDER="Please note, that if you continue with the installation, there may be errors"
}

res_rabbitmq_update () {
    RES_RABBITMQ_VERSION="You have an old version of RabbitMQ installed. The update will cause the RabbitMQ database to be deleted."
    RES_RABBITMQ_REMINDER="If you use the database only in the ONLYOFFICE configuration, then the update will be safe for you."
    RES_RABBITMQ_INSTALLATION="Select 'Y' to install the new version of RabbitMQ (recommended). Select 'N' to keep the current version of RabbitMQ."
    RES_CHOICE_RABBITMQ="Install a new version of RabbitMQ [Y/N]?"
}

while [ "$1" != "" ]; do
    case $1 in

        -it | --installation_type )
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
            echo "      -it, --installation_type          installation type (COMMUNITY|ENTERPRISE|DEVELOPER)"
            echo "      -u, --update                      use to update existing components (true|false)"
            echo "      -skiphc, --skiphardwarecheck      use to skip hardware check (true|false)"
            echo "      -je, --jwtenabled                 specifies whether JWT validation is enabled (true|false)"
            echo "      -jh, --jwtheader                  defines the HTTP header that will be used to send the JWT"
            echo "      -js, --jwtsecret                  defines the secret key to validate the JWT in the request"
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

cat > /etc/yum.repos.d/onlyoffice.repo <<END
[onlyoffice]
name=onlyoffice repo
baseurl=http://download.onlyoffice.com/repo/centos/main/noarch/
gpgcheck=1
gpgkey=https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE
enabled=1
END

DOWNLOAD_URL_PREFIX="https://download.onlyoffice.com/docs/install-RedHat"
if [ "$LOCAL_SCRIPTS" == "true" ]; then
    source install-RedHat/tools.sh
    source install-RedHat/bootstrap.sh
    source install-RedHat/check-ports.sh
    [ -f /etc/amazon-linux-release ] && source install-RedHat/install-preq-amzn.sh || source install-RedHat/install-preq.sh
    source install-RedHat/install-app.sh
else
    source <(curl ${DOWNLOAD_URL_PREFIX}/tools.sh)
    source <(curl ${DOWNLOAD_URL_PREFIX}/bootstrap.sh)
    source <(curl ${DOWNLOAD_URL_PREFIX}/check-ports.sh)
    grep -qiE '^ID="?amzn' /etc/os-release && source <(curl ${DOWNLOAD_URL_PREFIX}/install-preq-amzn.sh) || source <(curl ${DOWNLOAD_URL_PREFIX}/install-preq.sh)
    source <(curl ${DOWNLOAD_URL_PREFIX}/install-app.sh)
fi
