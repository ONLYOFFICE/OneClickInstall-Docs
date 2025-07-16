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

DISK_REQUIREMENTS=10240
MEMORY_REQUIREMENTS=4096
CORE_REQUIREMENTS=2

PRODUCT="onlyoffice"
BASE_DIR="/app/$PRODUCT"
NETWORK="$PRODUCT"

DOCUMENT_CONTAINER_NAME="onlyoffice-document-server"
DOCUMENT_IMAGE_NAME="onlyoffice/documentserver-ee"
DOCUMENT_VERSION=""

DIST=""
REV=""
KERNEL=""

UPDATE="false"

USERNAME=""
PASSWORD=""

INSTALL_DOCUMENT_SERVER="true"

USE_AS_EXTERNAL_SERVER="true"

INSTALLATION_TYPE="ENTERPRISE"

HELP_TARGET="install.sh"

JWT_ENABLED=""
JWT_SECRET=""

SKIP_HARDWARE_CHECK="false"
SKIP_VERSION_CHECK="false"

DOCS_PORT=80;

while [ "$1" != "" ]; do
    case $1 in

        -di | --documentimage )
            if [ "$2" != "" ]; then
                DOCUMENT_IMAGE_NAME=$2
                shift
            fi
        ;;

        -dv | --documentversion )
            if [ "$2" != "" ]; then
                DOCUMENT_VERSION=$2
                shift
            fi
        ;;

        -u | --update )
            if [ "$2" != "" ]; then
                UPDATE=$2
                shift
            fi
        ;;

        -reg | --registry )
            if [ "$2" != "" ]; then
                REGISTRY_URL=$2
                shift
            fi
        ;;

        -un | --username )
            if [ "$2" != "" ]; then
                USERNAME=$2
                shift
            fi
        ;;

        -p | --password )
            if [ "$2" != "" ]; then
                PASSWORD=$2
                shift
            fi
        ;;

        -es | --externalserver | --useasexternalserver )
            if [ "$2" != "" ]; then
                USE_AS_EXTERNAL_SERVER=$2
                shift
            fi
        ;;

        -it | --installationtype | --installation_type )
            if [ "$2" != "" ]; then
                INSTALLATION_TYPE=$(echo "$2" | awk '{print toupper($0)}');
                shift
            fi
        ;;

        -ht | --helptarget )
            if [ "$2" != "" ]; then
                HELP_TARGET=$2
                shift
            fi
        ;;

        -skiphc | --skiphardwarecheck )
            if [ "$2" != "" ]; then
                SKIP_HARDWARE_CHECK=$2
                shift
            fi
        ;;

        -skipvc | --skipversioncheck )
            if [ "$2" != "" ]; then
                SKIP_VERSION_CHECK=$2
                shift
            fi
        ;;

        -dp | --docsport )
            if [ "$2" != "" ]; then
                DOCS_PORT=$2
                shift
            fi
        ;;

        -ls | --localscripts )
            if [ "$2" != "" ]; then
                LOCAL_SCRIPTS=$2
                shift
            fi
        ;;

        -ids | --installdocs | --installdocumentserver )
            if [ "$2" != "" ]; then
                INSTALL_DOCUMENT_SERVER=$2
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

        -led | --letsencryptdomain )
            if [ "$2" != "" ]; then
                LETS_ENCRYPT_DOMAIN=$2
                shift
            fi
        ;;

        -lem | --letsencryptmail )
            if [ "$2" != "" ]; then
                LETS_ENCRYPT_MAIL=$2
                shift
            fi
        ;;

        -? | -h | --help )
            echo
            echo "  Usage: bash $HELP_TARGET [PARAMETER] [[PARAMETER], ...]"
            echo

            echo "DOCKER REGISTRY AUTH:"
            echo "--registry               <URL>              Docker registry URL (e.g., https://myregistry.com:5000)"
            echo "--username               <USERNAME>         Docker registry login"
            echo "--password               <PASSWORD>         Docker registry password"
            echo
            echo "INSTALLATION MODE:"
            echo "--installationtype       <EDITION>          Installation type: COMMUNITY | ENTERPRISE | DEVELOPER"
            echo "--update                 <true|false>       Update existing components"
            echo "--localscripts           <true|false>       Use local scripts"
            echo
            echo "DOCUMENT SERVER OPTIONS:"
            echo "--documentimage          <name|path>        Document image name or .tar.gz file path"
            echo "--documentversion        <VERSION_TAG>      Document version tag"
            echo "--installdocs            <true|false|pull>  Install or update Document Server"
            echo "--docsport               <PORT>             Port for ONLYOFFICE Docs (default: $DOCS_PORT)"
            echo "--externalserver         <true|false>       Expose Docs externally (default: true)"
            echo
            echo "JWT AUTHENTICATION:"
            echo "--jwtenabled             <true|false>       Enable JWT validation"
            echo "--jwtheader              <HEADER_NAME>      HTTP header for JWT (default: AuthorizationJwt)"
            echo "--jwtsecret              <JWT_SECRET>       Secret key to validate JWT"
            echo
            echo "ADVANCED OPTIONS:"
            echo "--skiphardwarecheck      <true|false>       Skip hardware check"
            echo "--skipversioncheck       <true|false>       Skip version check during update"
            echo "--letsencryptdomain      <DOMAIN>           Domain for Let's Encrypt certificate (e.g., docs.example.com)"
            echo "--letsencryptmail        <EMAIL>            Admin email for Let's Encrypt (e.g., admin@example.com)"
            echo
            echo "EXAMPLES:"
            echo "  # 1. Quick install on non-default port 8080 (default is 80)"
            echo "  sudo bash $HELP_TARGET --docsport 8080"
            echo
            echo "  # 2. Update and skipping hardware checks"
            echo "  sudo bash $HELP_TARGET --update true --skiphardwarecheck true"
            echo
            echo "  # 3. Install from private registry"
            echo "  sudo bash $HELP_TARGET --registry https://reg.example.com:5000 --username USER --password PASS"
            echo
            echo "  # 4. Install specific Document Server image & version"
            echo "  sudo bash $HELP_TARGET --documentimage onlyoffice/documentserver --documentversion 8.3.3"
            echo
            echo "  # 5. Enable JWT with custom header/secret"
            echo "  sudo bash $HELP_TARGET --jwtenabled true --jwtheader \"AuthorizationJwt\" --jwtsecret \"SecretString\""
            echo
            echo "  # 6. Pull images only"
            echo "  sudo bash $HELP_TARGET --installdocs pull --documentimage onlyoffice/documentserver --documentversion 8.0.0"
            echo
            echo "  # 7. Install with free HTTPS via Let's Encrypt"
            echo "  sudo bash $HELP_TARGET --letsencryptdomain docs.example.com --letsencryptmail admin@example.com"
            echo
            exit 0
        ;;

        * )
            echo "Unknown parameter $1" 1>&2
            exit 1
        ;;
    esac
    shift
done

root_checking () {
    [[ ${EUID} -eq 0 ]] || { echo "To perform this action you must be logged in with root rights"; exit 1; }
}

command_exists () {
    type "$1" &> /dev/null
}

file_exists () {
    [[ -z "$1" ]] && { echo "file path is empty"; exit 1; }
    [[ -f "$1" ]]
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
        exit 1
    fi
}

install_jq () {
    if command_exists apt-get; then
        apt-get -y update
        apt-get -y -q install jq
    elif command_exists yum; then
        rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-$REV.noarch.rpm || true
        yum -y install jq
    fi

    if ! command_exists jq; then
        echo "command jq not found"
        exit 1
    fi
}

install_netstat () {
    if command_exists apt-get; then
        apt-get -y -q install net-tools
    elif command_exists yum; then
        yum -y install net-tools
    fi

    if ! command_exists netstat; then
        echo "command netstat not found"
        exit 1
    fi
}

get_os_info () {
    OS=$(uname | tr '[:upper:]' '[:lower:]')

    case "${OS}" in
        windowsnt|darwin|sunos|aix)
            echo "Not supported OS"
            exit 1
            ;;
        linux)
            MACH=$(uname -m)

            if [[ "${MACH}" != "x86_64" && "${MACH}" != "aarch64" && "${MACH}" != "arm64" ]]; then
                echo "Currently only supports 64bit OS's"
                exit 1
            fi

            KERNEL=$(uname -r)

            if [ -f /etc/redhat-release ]; then
                DIST=$(sed 's/ release.*//' /etc/redhat-release)
                REV=$(grep -oP '(?<=release )\d+' /etc/redhat-release || awk -F= '/VERSION_ID/{gsub(/"/,"");print $2}' /etc/os-release)
            elif [ -f /etc/SuSE-release ]; then
                DIST="SuSe"
                REV=$(awk -F= '/^VERSION_ID/{gsub(/"/,"");print $2}' /etc/os-release)
            elif [ -f /etc/debian_version ]; then
                DIST="Debian"
                REV=$(cat /etc/debian_version)
                [ -f /etc/lsb-release ] && {
                    DIST=$(awk -F= '/^DISTRIB_ID/{print $2}' /etc/lsb-release)
                    REV=$(awk -F= '/^DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
                }
            elif [ -f /etc/os-release ]; then
                DIST=$(awk -F= '/^ID/{gsub(/"/,"");print $2}' /etc/os-release)
                REV=$(awk -F= '/^VERSION_ID/{gsub(/"/,"");print $2}' /etc/os-release)
            fi
            ;;
    esac

    DIST=$(echo "${DIST}" | xargs)
    REV=$(echo "${REV}" | xargs)
}

check_os_info () {
    if [[ -z ${KERNEL} || -z ${DIST} || -z ${REV} ]]; then
        echo "$KERNEL, $DIST, $REV"
        echo "Not supported OS"
        exit 1
    fi
}

check_kernel () {
    MIN_NUM_ARR=(3 10 0)
    CUR_NUM_ARR=()

    CUR_STR_ARR=$(echo $KERNEL | grep -Po "[0-9]+\.[0-9]+\.[0-9]+" | tr "." " ")
    for CUR_STR_ITEM in $CUR_STR_ARR
    do
        CUR_NUM_ARR=(${CUR_NUM_ARR[@]} $CUR_STR_ITEM)
    done

    INDEX=0

    while [[ $INDEX -lt 3 ]]; do
        if [ ${CUR_NUM_ARR[INDEX]} -lt ${MIN_NUM_ARR[INDEX]} ]; then
            echo "Not supported OS Kernel"
            exit 1
        elif [ ${CUR_NUM_ARR[INDEX]} -gt ${MIN_NUM_ARR[INDEX]} ]; then
            INDEX=3
        fi
        (( INDEX++ ))
    done
}

check_hardware () {
    AVAILABLE_DISK_SPACE=$(df -m /  | tail -1 | awk '{ print $4 }')

    if [ ${AVAILABLE_DISK_SPACE} -lt ${DISK_REQUIREMENTS} ]; then
        echo "Minimal requirements are not met: need at least $DISK_REQUIREMENTS MB of free HDD space"
        exit 1
    fi

    TOTAL_MEMORY=$(free --mega | grep -oP '\d+' | head -n 1)

    if [ ${TOTAL_MEMORY} -lt ${MEMORY_REQUIREMENTS} ]; then
        echo "Minimal requirements are not met: need at least $MEMORY_REQUIREMENTS MB of RAM"
        exit 1
    fi

    CPU_CORES_NUMBER=$(grep -c '^processor' /proc/cpuinfo)

    if [ ${CPU_CORES_NUMBER} -lt ${CORE_REQUIREMENTS} ]; then
        echo "The system does not meet the minimal hardware requirements. CPU with at least $CORE_REQUIREMENTS cores is required"
        exit 1
    fi
}

check_ports () {
    RESERVED_PORTS=()
    ARRAY_PORTS=()
    USED_PORTS=""

    if ! command_exists netstat; then
        install_netstat
    fi

    if [[ ! -z "${LETS_ENCRYPT_DOMAIN}" ]]; then
        RESERVED_PORTS+=(443) && ARRAY_PORTS+=(443)
    fi

    if [ "${DOCS_PORT//[0-9]}" = "" ]; then
        for RESERVED_PORT in "${RESERVED_PORTS[@]}"
        do
            if [ "$RESERVED_PORT" -eq "$DOCS_PORT" ] ; then
                echo "Docs port $DOCS_PORT is reserved. Select another port"
                exit 1
            fi
        done
    else
        echo "Invalid Docs port $DOCS_PORT"
        exit 1
    fi

    if [ "${USE_AS_EXTERNAL_SERVER}" == "true" ]; then
        ARRAY_PORTS=(${ARRAY_PORTS[@]} "$DOCS_PORT")
    fi

    for PORT in "${ARRAY_PORTS[@]}"
    do
        REGEXP=":$PORT$"
        CHECK_RESULT=$(netstat -lnt | awk '{print $4}' | { grep $REGEXP || true; })

        if [[ $CHECK_RESULT != "" ]]; then
            if [[ $USED_PORTS != "" ]]; then
                USED_PORTS="$USED_PORTS, $PORT"
            else
                USED_PORTS="$PORT"
            fi
        fi
    done

    if [[ $USED_PORTS != "" ]]; then
        echo "The following TCP Ports must be available: $USED_PORTS"
        exit 1
    fi
}

check_docker_version () {
    CUR_FULL_VERSION=$(docker -v | cut -d ' ' -f3 | cut -d ',' -f1)
    CUR_VERSION=$(echo $CUR_FULL_VERSION | cut -d '-' -f1)
    CUR_EDITION=$(echo $CUR_FULL_VERSION | cut -d '-' -f2)

    if [ "${CUR_EDITION}" == "ce" ] || [ "${CUR_EDITION}" == "ee" ]; then
        return 0
    fi

    if [ "${CUR_VERSION}" != "${CUR_EDITION}" ]; then
        echo "Unspecific docker version"
        exit 1
    fi

    MIN_NUM_ARR=(1 10 0)
    CUR_NUM_ARR=()

    CUR_STR_ARR=$(echo $CUR_VERSION | grep -Po "[0-9]+\.[0-9]+\.[0-9]+" | tr "." " ")

    for CUR_STR_ITEM in $CUR_STR_ARR
    do
        CUR_NUM_ARR=(${CUR_NUM_ARR[@]} $CUR_STR_ITEM)
    done

    INDEX=0

    while [[ $INDEX -lt 3 ]]; do
        if [ ${CUR_NUM_ARR[INDEX]} -lt ${MIN_NUM_ARR[INDEX]} ]; then
            echo "The outdated Docker version has been found. Please update to the latest version."
            exit 1
        elif [ ${CUR_NUM_ARR[INDEX]} -gt ${MIN_NUM_ARR[INDEX]} ]; then
            return 0
        fi
        (( INDEX++ ))
    done
}

install_docker_using_script () {
    if ! command_exists curl ; then
        install_curl
    fi

    curl -fsSL https://get.docker.com | sh
}

install_docker () {

    if [ "${DIST}" == "Ubuntu" ] || [ "${DIST}" == "Debian" ] || [[ "${DIST}" == CentOS* ]] || [ "${DIST}" == "Fedora" ]; then

        install_docker_using_script
        systemctl start docker
        systemctl enable docker

	elif [[ "${DIST}" == Red\ Hat\ Enterprise\ Linux* ]]; then

		if [[ "${REV}" -gt "7" ]]; then
			yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine podman runc > null
			yum install -y yum-utils
			yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
			yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
			systemctl start docker
			systemctl enable docker
		else
			echo ""
			echo "Your operating system does not allow Docker CE installation."
			echo "You can install Docker EE using the manual here - https://docs.docker.com/engine/installation/linux/rhel/"
			echo ""
			exit 1
		fi

    elif [ "${DIST}" == "SuSe" ]; then

        echo ""
        echo "Your operating system does not allow Docker CE installation."
        echo "You can install Docker EE using the manual here - https://docs.docker.com/engine/installation/linux/suse/"
        echo ""
        exit 1

    elif [ "${DIST}" == "altlinux" ]; then

        apt-get -y install docker-io
        chkconfig docker on
        service docker start
        systemctl enable docker

    else

        echo ""
        echo "Docker could not be installed automatically."
        echo "Please use this official instruction https://docs.docker.com/engine/installation/linux/other/ for its manual installation."
        echo ""
        exit 1

    fi

    if ! command_exists docker ; then
        echo "error while installing docker"
        exit 1
    fi
}

docker_login () {
    if [[ -n ${USERNAME} && -n ${PASSWORD}  ]]; then
        docker login ${REGISTRY_URL} --username ${USERNAME} --password ${PASSWORD}
    fi
}

make_directories () {
    mkdir -p "$BASE_DIR/DocumentServer/data/certs"
    mkdir -p "$BASE_DIR/DocumentServer/logs"
    mkdir -p "$BASE_DIR/DocumentServer/fonts"
    mkdir -p "$BASE_DIR/DocumentServer/forgotten"
}

get_tag_from_registry() {
    if [[ -n ${REGISTRY_URL} ]]; then
        if [[ -n ${USERNAME} && -n ${PASSWORD} ]]; then
            CREDENTIALS=$(echo -n "$USERNAME:$PASSWORD" | base64)
        elif [[ -f "$HOME/.docker/config.json" ]]; then
            CREDENTIALS=$(jq -r --arg registry "${REGISTRY_URL}" '.auths | to_entries[] | select(.key | contains($registry)).value.auth // empty' "$HOME/.docker/config.json")
        fi
        AUTH_HEADER=${CREDENTIALS:+Authorization: Basic $CREDENTIALS}
        REGISTRY_TAGS_URL="${REGISTRY_URL%/}/v2/${IMAGE}/tags/list"
        JQ_FILTER='.tags[]?'
    else
        if [[ -n ${USERNAME} && -n ${PASSWORD} ]]; then
            CREDENTIALS=${USERNAME:+${PASSWORD:+-u ${USERNAME}:${PASSWORD}}}
        fi
        TOKEN=$(curl -fs ${CREDENTIALS} "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE}:pull" | jq -r .token)
        AUTH_HEADER="Authorization: Bearer $TOKEN"
        REGISTRY_TAGS_URL="https://registry-1.docker.io/v2/${IMAGE}/tags/list"
        JQ_FILTER='.tags | map(select( test("^99\\.") | not )) | .[-100:] | .[]'
    fi

    mapfile -t TAGS_RESP < <(curl -s ${AUTH_HEADER:+-H "$AUTH_HEADER"} "$REGISTRY_TAGS_URL" | jq -r "$JQ_FILTER")
}

get_available_version() {
    local IMAGE="$1"
    if [[ -z "$1" ]]; then
        echo "image name is empty"
        exit 1
    fi

    if ! command_exists curl; then install_curl >/dev/null 2>&1; fi
    if ! command_exists jq; then install_jq >/dev/null 2>&1; fi

    get_tag_from_registry "$IMAGE"

    VERSION_REGEX='^[0-9]+(\.[0-9]+){2,3}$'
    echo $(printf "%s\n" "${TAGS_RESP[@]}" | grep -E "$VERSION_REGEX" | sort -V | tail -n 1)

}

get_current_image_name () {
    if [[ -z "$1" ]]; then
        echo "container name is empty"
        exit 1
    fi

    CONTAINER_IMAGE=$(docker inspect --format='{{.Config.Image}}' $1)

    CONTAINER_IMAGE_PARTS=($(echo $CONTAINER_IMAGE | tr ":" "\n"))

    echo ${CONTAINER_IMAGE_PARTS[0]}
}

get_current_image_version () {
    if [[ -z "$1" ]]; then
        echo "container name is empty"
        exit 1
    fi

    CONTAINER_IMAGE=$(docker inspect --format='{{.Config.Image}}' $1)

    CONTAINER_IMAGE_PARTS=($(echo $CONTAINER_IMAGE | tr ":" "\n"))

    echo ${CONTAINER_IMAGE_PARTS[1]}
}

check_bindings () {
    if [[ -z "$1" ]]; then
        echo "container id is empty"
        exit 1
    fi

    binds=$(docker inspect --format='{{range $p,$conf:=.HostConfig.Binds}}{{$conf}};{{end}}' $1)
    volumes=$(docker inspect --format='{{range $p,$conf:=.Config.Volumes}}{{$p}};{{end}}' $1)
    arrBinds=$(echo $binds | tr ";" "\n")
    arrVolumes=$(echo $volumes | tr ";" "\n")
    bindsCorrect=1

    if [[ -n "$2" ]]; then
        exceptions=$(echo $2 | tr "," "\n")
        for ex in ${exceptions[@]}
        do
            arrVolumes=(${arrVolumes[@]/$ex})
        done
    fi

    for volume in $arrVolumes
    do
        bindExist=0
        for bind in $arrBinds
        do
            bind=($(echo $bind | tr ":" " "))
            if [ "${bind[1]}" == "${volume}" ]; then
                bindExist=1
            fi
        done
        if [ "$bindExist" == "0" ]; then
            bindsCorrect=0
            echo "${volume} not binded"
        fi
    done

    if [ "$bindsCorrect" == "0" ]; then
        exit 1
    fi
}

install_document_server () {
    DOCUMENT_SERVER_ID=$(get_container_id "$DOCUMENT_CONTAINER_NAME")

    RUN_DOCUMENT_SERVER="true"

    if [[ -n ${DOCUMENT_SERVER_ID} ]]; then
        if [ "$UPDATE" == "true" ]; then
            CURRENT_IMAGE_NAME=$(get_current_image_name "$DOCUMENT_CONTAINER_NAME")
            CURRENT_IMAGE_VERSION=$(get_current_image_version "$DOCUMENT_CONTAINER_NAME")

            if [ "$CURRENT_IMAGE_NAME" != "$DOCUMENT_IMAGE_NAME" ] || ([ "$CURRENT_IMAGE_VERSION" != "$DOCUMENT_VERSION" ] || [ "$SKIP_VERSION_CHECK" == "true" ]); then
                PARAMETER_VALUE=$(get_container_env_parameter "$DOCUMENT_CONTAINER_NAME" "LETS_ENCRYPT_DOMAIN")
                if [[ -n ${PARAMETER_VALUE} ]]; then
                    LETS_ENCRYPT_DOMAIN="${LETS_ENCRYPT_DOMAIN:-$PARAMETER_VALUE}"
                fi

                PARAMETER_VALUE=$(get_container_env_parameter "$DOCUMENT_CONTAINER_NAME" "LETS_ENCRYPT_MAIL")
                if [[ -n ${PARAMETER_VALUE} ]]; then
                    LETS_ENCRYPT_MAIL="${LETS_ENCRYPT_MAIL:-$PARAMETER_VALUE}"
                fi

                check_bindings $DOCUMENT_SERVER_ID "/etc/$PRODUCT,/var/lib/$PRODUCT,/var/lib/postgresql,/usr/share/fonts/truetype/custom,/var/lib/rabbitmq,/var/lib/redis";
                docker exec ${DOCUMENT_CONTAINER_NAME} bash /usr/bin/documentserver-prepare4shutdown.sh
                remove_container ${DOCUMENT_CONTAINER_NAME}
            else
                RUN_DOCUMENT_SERVER="false"
                echo "The latest version of ONLYOFFICE DOCUMENT SERVER is already installed."
                docker start ${DOCUMENT_SERVER_ID}
            fi
        else
            RUN_DOCUMENT_SERVER="false"
            echo "ONLYOFFICE DOCUMENT SERVER is already installed."
            docker start ${DOCUMENT_SERVER_ID}
        fi
    fi

    if [ "$RUN_DOCUMENT_SERVER" == "true" ]; then
        args=()
        args+=(--name "$DOCUMENT_CONTAINER_NAME")

        if [ "${USE_AS_EXTERNAL_SERVER}" == "true" ]; then
            args+=(-p $DOCS_PORT:80)
        fi

        if [[ -n ${JWT_SECRET} ]]; then
            args+=(-e "JWT_ENABLED=$JWT_ENABLED")
            args+=(-e "JWT_HEADER=$JWT_HEADER")
            args+=(-e "JWT_SECRET=$JWT_SECRET")
        else
            args+=(-e "JWT_ENABLED=false")
        fi

        if [[ -n ${LETS_ENCRYPT_DOMAIN} ]]; then
            args+=(-e "LETS_ENCRYPT_DOMAIN=$LETS_ENCRYPT_DOMAIN")
            args+=(-p 443:443)
        fi

        if [[ -n ${LETS_ENCRYPT_MAIL} ]]; then
            args+=(-e "LETS_ENCRYPT_MAIL=$LETS_ENCRYPT_MAIL")
        fi

        args+=(-v "$BASE_DIR/DocumentServer/data:/var/www/$PRODUCT/Data")
        args+=(-v "$BASE_DIR/DocumentServer/logs:/var/log/$PRODUCT")
        args+=(-v "$BASE_DIR/DocumentServer/fonts:/usr/share/fonts/truetype/custom")
        args+=(-v "$BASE_DIR/DocumentServer/forgotten:/var/lib/$PRODUCT/documentserver/App_Data/cache/files/forgotten")
        args+=("$DOCUMENT_IMAGE_NAME:$DOCUMENT_VERSION")

        docker run --net ${NETWORK} -i -t -d --restart=always "${args[@]}"

        DOCUMENT_SERVER_ID=$(get_container_id "$DOCUMENT_CONTAINER_NAME")

        if [[ -z ${DOCUMENT_SERVER_ID} ]]; then
            echo "ONLYOFFICE DOCUMENT SERVER not installed."
            exit 1
        fi
    fi
}

get_container_id () {
    CONTAINER_NAME=$1

    if [[ -z ${CONTAINER_NAME} ]]; then
        echo "Empty container name"
        exit 1
    fi

    CONTAINER_ID=""

    CONTAINER_EXIST=$(docker ps -aqf "name=$CONTAINER_NAME")

    if [[ -n ${CONTAINER_EXIST} ]]; then
        CONTAINER_ID=$(docker inspect --format='{{.Id}}' ${CONTAINER_NAME})
    fi

    echo "$CONTAINER_ID"
}

get_random_str () {
    LENGTH=$1

    if [[ -z ${LENGTH} ]]; then
        LENGTH=12
    fi

    VALUE=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c ${LENGTH})
    echo "$VALUE"
}

set_jwt_secret () {
    CURRENT_JWT_SECRET=""

    if [[ -z ${JWT_SECRET} ]]; then
        CURRENT_JWT_SECRET=$(get_container_env_parameter "$DOCUMENT_CONTAINER_NAME" "JWT_SECRET")

        if [[ -n ${CURRENT_JWT_SECRET} ]]; then
            JWT_SECRET="$CURRENT_JWT_SECRET"
        fi
    fi

    if [[ -z ${JWT_SECRET} ]] && [[ "$UPDATE" != "true" ]]; then
        JWT_SECRET=$(get_random_str 32)
        [ $JWT_ENABLED = "true" ] && JWT_MESSAGE='JWT is enabled by default. A random secret is generated automatically. Run the command "docker exec $(sudo docker ps -q) sudo documentserver-jwt-status.sh" to get information about JWT.'
    fi
}

set_jwt_enabled () {
    CURRENT_JWT_ENABLED=""

    if [[ -z ${JWT_ENABLED} ]]; then
        CURRENT_JWT_ENABLED=$(get_container_env_parameter "$DOCUMENT_CONTAINER_NAME" "JWT_ENABLED")

        if [[ -n ${CURRENT_JWT_ENABLED} ]]; then
            JWT_ENABLED="$CURRENT_JWT_ENABLED"
        fi
    fi

    if [[ -z ${JWT_ENABLED} ]]; then
        JWT_ENABLED="true"
    fi
}

set_jwt_header () {
    CURRENT_JWT_HEADER=""

    if [[ -z ${JWT_HEADER} ]]; then
        CURRENT_JWT_HEADER=$(get_container_env_parameter "$DOCUMENT_CONTAINER_NAME" "JWT_HEADER")

        if [[ -n ${CURRENT_JWT_HEADER} ]]; then
            JWT_HEADER="$CURRENT_JWT_HEADER"
        fi
    fi

    if [[ -z ${JWT_HEADER} ]]; then
        JWT_HEADER="AuthorizationJwt"
    fi
}

get_container_env_parameter () {
    CONTAINER_NAME=$1
    PARAMETER_NAME=$2
    VALUE=""

    if [[ -z ${CONTAINER_NAME} ]]; then
        echo "Empty container name"
        exit 1
    fi

    if [[ -z ${PARAMETER_NAME} ]]; then
        echo "Empty parameter name"
        exit 1
    fi

    if command_exists docker ; then
        CONTAINER_EXIST=$(docker ps -aqf "name=$CONTAINER_NAME")

        if [[ -n ${CONTAINER_EXIST} ]]; then
            VALUE=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' ${CONTAINER_NAME} | grep "${PARAMETER_NAME}=" | sed 's/^.*=//')
        fi
    fi

    echo "$VALUE"
}

remove_container () {
    CONTAINER_NAME=$1

    if [[ -z ${CONTAINER_NAME} ]]; then
        echo "Empty container name"
        exit 1
    fi

    echo "stop container:"
    docker stop ${CONTAINER_NAME}
    echo "remove container:"
    docker rm -f ${CONTAINER_NAME}

    sleep 10 #Hack for SuSe: exception "Error response from daemon: devmapper: Unknown device xxx"

    echo "check removed container: $CONTAINER_NAME"
    CONTAINER_ID=$(get_container_id "$CONTAINER_NAME")

    if [[ -n ${CONTAINER_ID} ]]; then
        echo "try again remove ${CONTAINER_NAME}"
        remove_container ${CONTAINER_NAME}
    fi
}

pull_document_server () {
    if file_exists "${DOCUMENT_IMAGE_NAME}"; then
        docker load -i ${DOCUMENT_IMAGE_NAME}

        FILE_NAME=$(basename $DOCUMENT_IMAGE_NAME)
        TMP_STRING=${FILE_NAME//.tar.gz/ }
        TMP_ARRAY=(${TMP_STRING//-/ })
        DOCUMENT_IMAGE_NAME="${TMP_ARRAY[0]}/${TMP_ARRAY[1]}"
        DOCUMENT_VERSION="${TMP_ARRAY[2]}"
    else
        if [[ -z ${DOCUMENT_VERSION} ]]; then
            DOCUMENT_VERSION=$(get_available_version "$DOCUMENT_IMAGE_NAME")
        fi

        pull_image ${DOCUMENT_IMAGE_NAME} ${DOCUMENT_VERSION}
    fi
}

pull_image () {
    IMAGE_NAME=$1
    IMAGE_VERSION=$2

    if [[ -z ${IMAGE_NAME} || -z ${IMAGE_VERSION} ]]; then
        echo "Docker pull argument exception: repository=$IMAGE_NAME, tag=$IMAGE_VERSION"
        exit 1
    fi

    EXIST=$(docker images | grep "$IMAGE_NAME" | awk '{print $2;}' | { grep -x "$IMAGE_VERSION" || true; })
    COUNT=1

    while [[ -z $EXIST && $COUNT -le 3 ]]; do
        docker pull ${IMAGE_NAME}:${IMAGE_VERSION}
        EXIST=$(docker images | grep "$IMAGE_NAME" | awk '{print $2;}' | { grep -x "$IMAGE_VERSION" || true; })
        (( COUNT++ ))
    done

    if [[ -z $EXIST ]]; then
        echo "Docker image $IMAGE_NAME:$IMAGE_VERSION not found"
        exit 1
    fi
}

create_network () {
    docker network inspect "${NETWORK}" &>/dev/null || docker network create --driver bridge "${NETWORK}"
}

set_installation_type_data () {
    if [ "$INSTALLATION_TYPE" == "COMMUNITY" ]; then
        DOCUMENT_IMAGE_NAME="onlyoffice/documentserver"
    elif [ "$INSTALLATION_TYPE" == "DEVELOPER" ]; then
        DOCUMENT_IMAGE_NAME="onlyoffice/documentserver-de"
    fi
}

start_installation () {
    root_checking

    set_installation_type_data

    set_jwt_enabled
    set_jwt_header
    set_jwt_secret

    get_os_info

    check_os_info

    check_kernel

    if [ "$SKIP_HARDWARE_CHECK" != "true" ]; then
        check_hardware
    fi

    if [ "$UPDATE" != "true" ]; then
        check_ports
    fi

    if command_exists docker ; then
        check_docker_version
        service docker start
    else
        install_docker
    fi

    docker_login

    make_directories

    create_network

    if [ "$INSTALL_DOCUMENT_SERVER" == "true" ]; then
        pull_document_server
        install_document_server
    elif [ "$INSTALL_DOCUMENT_SERVER" == "pull" ]; then
        pull_document_server
    fi

    [ -n "$JWT_MESSAGE" ] && [ -n "$DOCUMENT_SERVER_ID" ] && JWT_MESSAGE=$(echo "$JWT_MESSAGE" | sed 's/$(sudo docker ps -q)/'"${DOCUMENT_SERVER_ID::12}"'/') && echo -e "\n$JWT_MESSAGE"
    echo ""
    echo "Thank you for installing ONLYOFFICE Docs."
    echo "In case you have any questions contact us via http://support.onlyoffice.com or visit our forum at http://forum.onlyoffice.com"
    echo ""

    exit 0;
}

start_installation
