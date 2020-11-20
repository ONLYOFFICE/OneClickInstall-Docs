#!/bin/bash

# (c) Copyright Ascensio System Limited 2010-2016
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and limitations under the License.
# You can contact Ascensio System SIA by email at sales@onlyoffice.com

DISK_REQUIREMENTS=40960;
MEMORY_REQUIREMENTS=5500;
CORE_REQUIREMENTS=2;

PRODUCT="onlyoffice";
BASE_DIR="/app/$PRODUCT";
NETWORK="$PRODUCT";
SWAPFILE="/${PRODUCT}_swapfile";
MACHINEKEY_PARAM=$(echo "${PRODUCT}_CORE_MACHINEKEY" | awk '{print toupper($0)}');

DOCUMENT_CONTAINER_NAME="onlyoffice-document-server";
DOCUMENT_IMAGE_NAME="onlyoffice/documentserver-ee";
DOCUMENT_VERSION="";

DIST="";
REV="";
KERNEL="";

UPDATE="false";

HUB="";
USERNAME="";
PASSWORD="";

INSTALL_DOCUMENT_SERVER="true";

USE_AS_EXTERNAL_SERVER="false";

INSTALLATION_TYPE="ENTERPRISE";

MAKESWAP="true";

ACTIVATE_COMMUNITY_SERVER_TRIAL="false";

HELP_TARGET="install.sh";

JWT_SECRET="";
CORE_MACHINEKEY="";

SKIP_HARDWARE_CHECK="false";
SKIP_VERSION_CHECK="false";
SKIP_DOMAIN_CHECK="false";

COMMUNITY_PORT=80;

while [ "$1" != "" ]; do
	case $1 in

		-di | --documentimage )
			if [ "$2" != "" ]; then
				DOCUMENT_IMAGE_NAME=$2
				shift
			fi
		;;

		-dip | --documentserverip  )
			if [ "$2" != "" ]; then
				DOCUMENT_SERVER_HOST=$2
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

		-hub | --hub )
			if [ "$2" != "" ]; then
				HUB=$2
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

		-es | --useasexternalserver )
			if [ "$2" != "" ]; then
				USE_AS_EXTERNAL_SERVER=$2
				shift
			fi
		;;

		-it | --installation_type )
			if [ "$2" != "" ]; then
				INSTALLATION_TYPE=$(echo "$2" | awk '{print toupper($0)}');
				shift
			fi
		;;

		-ms | --makeswap )
			if [ "$2" != "" ]; then
				MAKESWAP=$2
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

		-skipdc | --skipdomaincheck )
			if [ "$2" != "" ]; then
				SKIP_DOMAIN_CHECK=$2
				shift
			fi
		;;

		-cp | --communityport )
			if [ "$2" != "" ]; then
				COMMUNITY_PORT=$2
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
			echo "  Usage: bash $HELP_TARGET [PARAMETER] [[PARAMETER], ...]"
			echo
			echo "    Parameters:"
			echo "      -di, --documentimage              document image name or .tar.gz file path"
			echo "      -dv, --documentversion            document version"
			echo "      -dip, --documentserverip          document server ip"
			echo "      -u, --update                      use to update existing components (true|false)"
			echo "      -hub, --hub                       dockerhub name"
			echo "      -un, --username                   dockerhub username"
			echo "      -p, --password                    dockerhub password"
			echo "      -es, --useasexternalserver        use as external server (true|false)"
			echo "      -pdf, --partnerdatafile           partner data file"
			echo "      -it, --installation_type          installation type (COMMUNITY|ENTERPRISE|DEVELOPER)"
			echo "      -ms, --makeswap                   make swap file (true|false)"
			echo "      -skiphc, --skiphardwarecheck      skip hardware check (true|false)"
			echo "      -skipvc, --skipversioncheck       skip version check while update (true|false)"
			echo "      -skipdc, --skipdomaincheck        skip domain check when installing mail server (true|false)"
			echo "      -cp, --communityport              community port (default value 80)"
			echo "      -ls, --local_scripts              use 'true' to run local scripts (true|false)"
			echo "      -?, -h, --help                    this help"
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
	if [ ! $( id -u ) -eq 0 ]; then
		echo "To perform this action you must be logged in with root rights"
		exit 1;
	fi
}

command_exists () {
    type "$1" &> /dev/null;
}

file_exists () {
	if [ -z "$1" ]; then
		echo "file path is empty"
		exit 1;
	fi

	if [ -f "$1" ]; then
		return 0; #true
	else
		return 1; #false
	fi
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

install_jq () {
	curl -s -o jq http://stedolan.github.io/jq/download/linux64/jq
	chmod +x jq
	cp jq /usr/bin
	rm jq

	if ! command_exists jq; then
		echo "command jq not found"
		exit 1;
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
		exit 1;
	fi
}

to_lowercase () {
	echo "$1" | awk '{print tolower($0)}'
}

trim () {
	echo -e "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

get_os_info () {
	OS=`to_lowercase \`uname\``

	if [ "${OS}" == "windowsnt" ]; then
		echo "Not supported OS";
		exit 1;
	elif [ "${OS}" == "darwin" ]; then
		echo "Not supported OS";
		exit 1;
	else
		OS=`uname`

		if [ "${OS}" == "SunOS" ] ; then
			echo "Not supported OS";
			exit 1;
		elif [ "${OS}" == "AIX" ] ; then
			echo "Not supported OS";
			exit 1;
		elif [ "${OS}" == "Linux" ] ; then
			MACH=`uname -m`

			if [ "${MACH}" != "x86_64" ]; then
				echo "Currently only supports 64bit OS's";
				exit 1;
			fi

			KERNEL=`uname -r`

			if [ -f /etc/redhat-release ] ; then
				CONTAINS=$(cat /etc/redhat-release | { grep -sw release || true; });
				if [[ -n ${CONTAINS} ]]; then
					DIST=`cat /etc/redhat-release |sed s/\ release.*//`
					REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
				else
					DIST=`cat /etc/os-release | grep -sw 'ID' | awk -F=  '{ print $2 }' | sed -e 's/^"//' -e 's/"$//'`
					REV=`cat /etc/os-release | grep -sw 'VERSION_ID' | awk -F=  '{ print $2 }' | sed -e 's/^"//' -e 's/"$//'`
				fi
			elif [ -f /etc/SuSE-release ] ; then
				REV=`cat /etc/os-release  | grep '^VERSION_ID' | awk -F=  '{ print $2 }' |  sed -e 's/^"//'  -e 's/"$//'`
				DIST='SuSe'
			elif [ -f /etc/debian_version ] ; then
				REV=`cat /etc/debian_version`
				DIST='Debian'
				if [ -f /etc/lsb-release ] ; then
					DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
					REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
				elif [ -f /etc/lsb_release ] || [ -f /usr/bin/lsb_release ] ; then
					DIST=`lsb_release -a 2>&1 | grep 'Distributor ID:' | awk -F ":" '{print $2 }'`
					REV=`lsb_release -a 2>&1 | grep 'Release:' | awk -F ":" '{print $2 }'`
				fi
			elif [ -f /etc/os-release ] ; then
				DIST=`cat /etc/os-release | grep -sw 'ID' | awk -F=  '{ print $2 }' | sed -e 's/^"//' -e 's/"$//'`
				REV=`cat /etc/os-release | grep -sw 'VERSION_ID' | awk -F=  '{ print $2 }' | sed -e 's/^"//' -e 's/"$//'`
			fi
		fi

		DIST=$(trim $DIST);
		REV=$(trim $REV);
	fi
}

check_os_info () {
	if [[ -z ${KERNEL} || -z ${DIST} || -z ${REV} ]]; then
		echo "$KERNEL, $DIST, $REV";
		echo "Not supported OS";
		exit 1;
	fi
}

check_kernel () {
	MIN_NUM_ARR=(3 10 0);
	CUR_NUM_ARR=();

	CUR_STR_ARR=$(echo $KERNEL | grep -Po "[0-9]+\.[0-9]+\.[0-9]+" | tr "." " ");
	for CUR_STR_ITEM in $CUR_STR_ARR
	do
		CUR_NUM_ARR=(${CUR_NUM_ARR[@]} $CUR_STR_ITEM)
	done

	INDEX=0;

	while [[ $INDEX -lt 3 ]]; do
		if [ ${CUR_NUM_ARR[INDEX]} -lt ${MIN_NUM_ARR[INDEX]} ]; then
			echo "Not supported OS Kernel"
			exit 1;
		elif [ ${CUR_NUM_ARR[INDEX]} -gt ${MIN_NUM_ARR[INDEX]} ]; then
			INDEX=3
		fi
		(( INDEX++ ))
	done
}

check_hardware () {
	AVAILABLE_DISK_SPACE=$(df -m /  | tail -1 | awk '{ print $4 }');

	if [ ${AVAILABLE_DISK_SPACE} -lt ${DISK_REQUIREMENTS} ]; then
		echo "Minimal requirements are not met: need at least $DISK_REQUIREMENTS MB of free HDD space"
		exit 1;
	fi

	TOTAL_MEMORY=$(free -m | grep -oP '\d+' | head -n 1);

	if [ ${TOTAL_MEMORY} -lt ${MEMORY_REQUIREMENTS} ]; then
		echo "Minimal requirements are not met: need at least $MEMORY_REQUIREMENTS MB of RAM"
		exit 1;
	fi

	CPU_CORES_NUMBER=$(cat /proc/cpuinfo | grep processor | wc -l);

	if [ ${CPU_CORES_NUMBER} -lt ${CORE_REQUIREMENTS} ]; then
		echo "The system does not meet the minimal hardware requirements. CPU with at least $CORE_REQUIREMENTS cores is required"
		exit 1;
	fi
}

make_swap () {
	DISK_REQUIREMENTS=6144; #6Gb free space
	MEMORY_REQUIREMENTS=11000; #RAM ~12Gb

	AVAILABLE_DISK_SPACE=$(df -m /  | tail -1 | awk '{ print $4 }');
	TOTAL_MEMORY=$(free -m | grep -oP '\d+' | head -n 1);
	EXIST=$(swapon -s | awk '{ print $1 }' | { grep -x ${SWAPFILE} || true; });

	if [[ -z $EXIST ]] && [ ${TOTAL_MEMORY} -lt ${MEMORY_REQUIREMENTS} ] && [ ${AVAILABLE_DISK_SPACE} -gt ${DISK_REQUIREMENTS} ]; then

		if [ "${DIST}" == "Ubuntu" ] || [ "${DIST}" == "Debian" ]; then
			fallocate -l 6G ${SWAPFILE}
		else
			dd if=/dev/zero of=${SWAPFILE} count=6144 bs=1MiB
		fi

		chmod 600 ${SWAPFILE}
		mkswap ${SWAPFILE}
		swapon ${SWAPFILE}
		echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
	fi
}

check_ports () {
	RESERVED_PORTS=(443);
	ARRAY_PORTS=();
	USED_PORTS="";

	if ! command_exists netstat; then
		install_netstat
	fi

	if [ "${COMMUNITY_PORT//[0-9]}" = "" ]; then
		for RESERVED_PORT in "${RESERVED_PORTS[@]}"
		do
			if [ "$RESERVED_PORT" -eq "$COMMUNITY_PORT" ] ; then
				echo "Community port $COMMUNITY_PORT is reserved. Select another port"
				exit 1;
			fi
		done
	else
		echo "Invalid community port $COMMUNITY_PORT"
		exit 1;
	fi

	if [ "${USE_AS_EXTERNAL_SERVER}" == "true" ]; then
		ARRAY_PORTS=(${ARRAY_PORTS[@]} "$COMMUNITY_PORT" "443");
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
		exit 1;
	fi
}

check_docker_version () {
	CUR_FULL_VERSION=$(docker -v | cut -d ' ' -f3 | cut -d ',' -f1);
	CUR_VERSION=$(echo $CUR_FULL_VERSION | cut -d '-' -f1);
	CUR_EDITION=$(echo $CUR_FULL_VERSION | cut -d '-' -f2);

	if [ "${CUR_EDITION}" == "ce" ] || [ "${CUR_EDITION}" == "ee" ]; then
		return 0;
	fi

	if [ "${CUR_VERSION}" != "${CUR_EDITION}" ]; then
		echo "Unspecific docker version"
		exit 1;
	fi

	MIN_NUM_ARR=(1 10 0);
	CUR_NUM_ARR=();

	CUR_STR_ARR=$(echo $CUR_VERSION | grep -Po "[0-9]+\.[0-9]+\.[0-9]+" | tr "." " ");

	for CUR_STR_ITEM in $CUR_STR_ARR
	do
		CUR_NUM_ARR=(${CUR_NUM_ARR[@]} $CUR_STR_ITEM)
	done

	INDEX=0;

	while [[ $INDEX -lt 3 ]]; do
		if [ ${CUR_NUM_ARR[INDEX]} -lt ${MIN_NUM_ARR[INDEX]} ]; then
			echo "The outdated Docker version has been found. Please update to the latest version."
			exit 1;
		elif [ ${CUR_NUM_ARR[INDEX]} -gt ${MIN_NUM_ARR[INDEX]} ]; then
			return 0;
		fi
		(( INDEX++ ))
	done
}

install_docker_using_script () {
	if ! command_exists curl ; then
		install_curl;
	fi

	curl -fsSL https://get.docker.com -o get-docker.sh
	sh get-docker.sh
	rm get-docker.sh
}

install_docker () {

	if [ "${DIST}" == "Ubuntu" ] || [ "${DIST}" == "Debian" ] || [[ "${DIST}" == CentOS* ]] || [ "${DIST}" == "Fedora" ]; then

		install_docker_using_script
		systemctl start docker
		systemctl enable docker

	elif [ "${DIST}" == "Red Hat Enterprise Linux Server" ]; then

		echo ""
		echo "Your operating system does not allow Docker CE installation."
		echo "You can install Docker EE using the manual here - https://docs.docker.com/engine/installation/linux/rhel/"
		echo ""
		exit 1;

	elif [ "${DIST}" == "SuSe" ]; then

		echo ""
		echo "Your operating system does not allow Docker CE installation."
		echo "You can install Docker EE using the manual here - https://docs.docker.com/engine/installation/linux/suse/"
		echo ""
		exit 1;

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
		exit 1;

	fi

	if ! command_exists docker ; then
		echo "error while installing docker"
		exit 1;
	fi
}

docker_login () {
	if [[ -n ${USERNAME} && -n ${PASSWORD}  ]]; then
		docker login ${HUB} --username ${USERNAME} --password ${PASSWORD}
	fi
}

make_directories () {
	mkdir -p "$BASE_DIR/DocumentServer/data";
	mkdir -p "$BASE_DIR/DocumentServer/logs";
	mkdir -p "$BASE_DIR/DocumentServer/fonts";
	mkdir -p "$BASE_DIR/DocumentServer/forgotten";
	mkdir -p "$BASE_DIR/CommunityServer/data";
}

get_available_version () {
	if [[ -z "$1" ]]; then
		echo "image name is empty";
		exit 1;
	fi

	if ! command_exists curl ; then
		install_curl;
	fi

	if ! command_exists jq ; then
		install_jq
	fi

	CREDENTIALS="";
	AUTH_HEADER="";
	TAGS_RESP="";

	if [[ -n ${HUB} ]]; then
		DOCKER_CONFIG="$HOME/.docker/config.json";

		if [[ -f "$DOCKER_CONFIG" ]]; then
			CREDENTIALS=$(jq -r '.auths."'$HUB'".auth' < "$DOCKER_CONFIG");
			if [ "$CREDENTIALS" == "null" ]; then
				CREDENTIALS="";
			fi
		fi

		if [[ -z ${CREDENTIALS} && -n ${USERNAME} && -n ${PASSWORD} ]]; then
			CREDENTIALS=$(echo -n "$USERNAME:$PASSWORD" | base64);
		fi

		if [[ -n ${CREDENTIALS} ]]; then
			AUTH_HEADER="Authorization: Basic $CREDENTIALS";
		fi

		REPO=$(echo $1 | sed "s/$HUB\///g");
		TAGS_RESP=$(curl -s -H "$AUTH_HEADER" -X GET https://$HUB/v2/$REPO/tags/list);
		TAGS_RESP=$(echo $TAGS_RESP | jq -r '.tags')
	else
		if [[ -n ${USERNAME} && -n ${PASSWORD} ]]; then
			CREDENTIALS="{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}";
		fi

		if [[ -n ${CREDENTIALS} ]]; then
			LOGIN_RESP=$(curl -s -H "Content-Type: application/json" -X POST -d "$CREDENTIALS" https://hub.docker.com/v2/users/login/);
			TOKEN=$(echo $LOGIN_RESP | jq -r '.token');
			AUTH_HEADER="Authorization: JWT $TOKEN";
			sleep 1;
		fi

		TAGS_RESP=$(curl -s -H "$AUTH_HEADER" -X GET https://hub.docker.com/v2/repositories/$1/tags/);
		TAGS_RESP=$(echo $TAGS_RESP | jq -r '.results[].name')
	fi

	VERSION_REGEX_1="[0-9]+\.[0-9]+\.[0-9]+"
	VERSION_REGEX_2="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"
	TAG_LIST=""

	for item in $TAGS_RESP
	do
		if [[ $item =~ $VERSION_REGEX_1 ]] || [[ $item =~ $VERSION_REGEX_2 ]]; then
			TAG_LIST="$item,$TAG_LIST"
		fi
	done

	LATEST_TAG=$(echo $TAG_LIST | tr ',' '\n' | sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n | awk '/./{line=$0} END{print line}');

	echo "$LATEST_TAG" | sed "s/\"//g"
}

get_current_image_name () {
	if [[ -z "$1" ]]; then
		echo "container name is empty";
		exit 1;
	fi

	CONTAINER_IMAGE=$(docker inspect --format='{{.Config.Image}}' $1)

	CONTAINER_IMAGE_PARTS=($(echo $CONTAINER_IMAGE | tr ":" "\n"))

	echo ${CONTAINER_IMAGE_PARTS[0]}
}

get_current_image_version () {
	if [[ -z "$1" ]]; then
		echo "container name is empty";
		exit 1;
	fi

	CONTAINER_IMAGE=$(docker inspect --format='{{.Config.Image}}' $1)

	CONTAINER_IMAGE_PARTS=($(echo $CONTAINER_IMAGE | tr ":" "\n"))

	echo ${CONTAINER_IMAGE_PARTS[1]}
}

check_bindings () {
	if [[ -z "$1" ]]; then
		echo "container id is empty";
		exit 1;
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
		exit 1;
	fi
}

install_document_server () {
	DOCUMENT_SERVER_ID=$(get_container_id "$DOCUMENT_CONTAINER_NAME");

	RUN_DOCUMENT_SERVER="true";
	
	if [[ -n ${DOCUMENT_SERVER_ID} ]]; then
		if [ "$UPDATE" == "true" ]; then
			CURRENT_IMAGE_NAME=$(get_current_image_name "$DOCUMENT_CONTAINER_NAME");
			CURRENT_IMAGE_VERSION=$(get_current_image_version "$DOCUMENT_CONTAINER_NAME");

			if [ "$CURRENT_IMAGE_NAME" == "onlyoffice/documentserver" ]; then
				ACTIVATE_COMMUNITY_SERVER_TRIAL="true";
			fi

			if [ "$CURRENT_IMAGE_NAME" != "$DOCUMENT_IMAGE_NAME" ] || ([ "$CURRENT_IMAGE_VERSION" != "$DOCUMENT_VERSION" ] || [ "$SKIP_VERSION_CHECK" == "true" ]); then
				check_bindings $DOCUMENT_SERVER_ID "/etc/$PRODUCT,/var/lib/$PRODUCT,/var/lib/postgresql,/usr/share/fonts/truetype/custom,/var/lib/rabbitmq,/var/lib/redis";
				docker exec ${DOCUMENT_CONTAINER_NAME} bash /usr/bin/documentserver-prepare4shutdown.sh
				remove_container ${DOCUMENT_CONTAINER_NAME}
			else
				RUN_DOCUMENT_SERVER="false";
				echo "The latest version of ONLYOFFICE DOCUMENT SERVER is already installed."
				docker start ${DOCUMENT_SERVER_ID};
			fi
		else
			RUN_DOCUMENT_SERVER="false";
			echo "ONLYOFFICE DOCUMENT SERVER is already installed."
			docker start ${DOCUMENT_SERVER_ID};
		fi
	fi

	if [ "$RUN_DOCUMENT_SERVER" == "true" ]; then
		args=();
		args+=(--name "$DOCUMENT_CONTAINER_NAME");

		if [ "${USE_AS_EXTERNAL_SERVER}" == "true" ]; then
			args+=(-p 80:80);
			args+=(-p 443:443);
		fi

		if [[ -n ${JWT_SECRET} ]]; then
			args+=(-e "JWT_ENABLED=true");
			args+=(-e "JWT_HEADER=AuthorizationJwt");
			args+=(-e "JWT_SECRET=$JWT_SECRET");
		fi

		args+=(-v "$BASE_DIR/DocumentServer/data:/var/www/$PRODUCT/Data");
		args+=(-v "$BASE_DIR/DocumentServer/logs:/var/log/$PRODUCT");
		args+=(-v "$BASE_DIR/DocumentServer/fonts:/usr/share/fonts/truetype/custom");
		args+=(-v "$BASE_DIR/DocumentServer/forgotten:/var/lib/$PRODUCT/documentserver/App_Data/cache/files/forgotten");
		args+=("$DOCUMENT_IMAGE_NAME:$DOCUMENT_VERSION");

		docker run --net ${NETWORK} -i -t -d --restart=always "${args[@]}";

		DOCUMENT_SERVER_ID=$(get_container_id "$DOCUMENT_CONTAINER_NAME");

		if [[ -z ${DOCUMENT_SERVER_ID} ]]; then
			echo "ONLYOFFICE DOCUMENT SERVER not installed."
			exit 1;
		fi
	fi
}

get_container_id () {
	CONTAINER_NAME=$1;

	if [[ -z ${CONTAINER_NAME} ]]; then
		echo "Empty container name"
		exit 1;
	fi

	CONTAINER_ID="";

	CONTAINER_EXIST=$(docker ps -aqf "name=$CONTAINER_NAME");

	if [[ -n ${CONTAINER_EXIST} ]]; then
		CONTAINER_ID=$(docker inspect --format='{{.Id}}' ${CONTAINER_NAME});
	fi

	echo "$CONTAINER_ID"
}

get_container_ip () {
	CONTAINER_NAME=$1;

	if [[ -z ${CONTAINER_NAME} ]]; then
		echo "Empty container name"
		exit 1;
	fi

	CONTAINER_IP="";

	CONTAINER_EXIST=$(docker ps -aqf "name=$CONTAINER_NAME");

	if [[ -n ${CONTAINER_EXIST} ]]; then
		CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_NAME});
	fi

	echo "$CONTAINER_IP"
}

get_random_str () {
	LENGTH=$1;

	if [[ -z ${LENGTH} ]]; then
		LENGTH=12;
	fi

	VALUE=$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c ${LENGTH});
	echo "$VALUE"
}

set_jwt_secret () {
	CURRENT_JWT_SECRET="";

	if [[ -z ${JWT_SECRET} ]]; then
		CURRENT_JWT_SECRET=$(get_container_env_parameter "$DOCUMENT_CONTAINER_NAME" "JWT_SECRET");

		if [[ -n ${CURRENT_JWT_SECRET} ]]; then
			JWT_SECRET="$CURRENT_JWT_SECRET";
		fi
	fi

	if [[ -z ${JWT_SECRET} ]] && [[ "$UPDATE" != "true" ]] && [[ "$USE_AS_EXTERNAL_SERVER" != "true" ]]; then
		JWT_SECRET=$(get_random_str 12);
	fi
}

set_core_machinekey () {
	CURRENT_CORE_MACHINEKEY="";

	if [[ -z ${CORE_MACHINEKEY} ]]; then
		if file_exists ${BASE_DIR}/CommunityServer/data/.private/machinekey; then
			CURRENT_CORE_MACHINEKEY=$(cat ${BASE_DIR}/CommunityServer/data/.private/machinekey);

			if [[ -n ${CURRENT_CORE_MACHINEKEY} ]]; then
				CORE_MACHINEKEY="$CURRENT_CORE_MACHINEKEY";
			fi
		fi
	fi

	if [[ -z ${CORE_MACHINEKEY} ]]; then
		CURRENT_CORE_MACHINEKEY=$(get_container_env_parameter "$CONTROLPANEL_CONTAINER_NAME" "$MACHINEKEY_PARAM");

		if [[ -n ${CURRENT_CORE_MACHINEKEY} ]]; then
			CORE_MACHINEKEY="$CURRENT_CORE_MACHINEKEY";
		fi
	fi

	if [[ -z ${CORE_MACHINEKEY} ]]; then
		CURRENT_CORE_MACHINEKEY=$(get_container_env_parameter "$COMMUNITY_CONTAINER_NAME" "$MACHINEKEY_PARAM");

		if [[ -n ${CURRENT_CORE_MACHINEKEY} ]]; then
			CORE_MACHINEKEY="$CURRENT_CORE_MACHINEKEY";
		fi
	fi

	if [[ -z ${CORE_MACHINEKEY} ]] && [[ "$UPDATE" != "true" ]] && [[ "$USE_AS_EXTERNAL_SERVER" != "true" ]]; then
		CORE_MACHINEKEY=$(get_random_str 12);
	fi
}

get_container_env_parameter () {
	CONTAINER_NAME=$1;
	PARAMETER_NAME=$2;
	VALUE="";

	if [[ -z ${CONTAINER_NAME} ]]; then
		echo "Empty container name"
		exit 1;
	fi

	if [[ -z ${PARAMETER_NAME} ]]; then
		echo "Empty parameter name"
		exit 1;
	fi

	if command_exists docker ; then
		CONTAINER_EXIST=$(docker ps -aqf "name=$CONTAINER_NAME");

		if [[ -n ${CONTAINER_EXIST} ]]; then
			VALUE=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' ${CONTAINER_NAME} | grep "${PARAMETER_NAME}=" | sed 's/^.*=//');
		fi
	fi

	echo "$VALUE"
}

remove_container () {
	CONTAINER_NAME=$1;

	if [[ -z ${CONTAINER_NAME} ]]; then
		echo "Empty container name"
		exit 1;
	fi

	echo "stop container:"
	docker stop ${CONTAINER_NAME};
	echo "remove container:"
	docker rm -f ${CONTAINER_NAME};

	sleep 10 #Hack for SuSe: exception "Error response from daemon: devmapper: Unknown device xxx"

	echo "check removed container: $CONTAINER_NAME"
	CONTAINER_ID=$(get_container_id "$CONTAINER_NAME");

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
			DOCUMENT_VERSION=$(get_available_version "$DOCUMENT_IMAGE_NAME");
		fi

		pull_image ${DOCUMENT_IMAGE_NAME} ${DOCUMENT_VERSION}
	fi
}

pull_image () {
	IMAGE_NAME=$1;
	IMAGE_VERSION=$2;

	if [[ -z ${IMAGE_NAME} || -z ${IMAGE_VERSION} ]]; then
		echo "Docker pull argument exception: repository=$IMAGE_NAME, tag=$IMAGE_VERSION"
		exit 1;
	fi

	EXIST=$(docker images | grep "$IMAGE_NAME" | awk '{print $2;}' | { grep -x "$IMAGE_VERSION" || true; });
	COUNT=1;

	while [[ -z $EXIST && $COUNT -le 3 ]]; do
		docker pull ${IMAGE_NAME}:${IMAGE_VERSION}
		EXIST=$(docker images | grep "$IMAGE_NAME" | awk '{print $2;}' | { grep -x "$IMAGE_VERSION" || true; });
		(( COUNT++ ))
	done

	if [[ -z $EXIST ]]; then
		echo "Docker image $IMAGE_NAME:$IMAGE_VERSION not found"
		exit 1;
	fi
}

create_network () {
	EXIST=$(docker network ls | awk '{print $2;}' | { grep -x ${NETWORK} || true; });

	if [[ -z ${EXIST} ]]; then
		docker network create --driver bridge ${NETWORK}
	fi
}

set_installation_type_data () {
	if [ "$INSTALLATION_TYPE" == "COMMUNITY" ]; then
		set_opensource_data
	elif [ "$INSTALLATION_TYPE" == "DEVELOPER" ]; then
		DOCUMENT_IMAGE_NAME="onlyoffice/documentserver-de"
	fi
}

set_opensource_data () {
	DOCUMENT_IMAGE_NAME="onlyoffice/documentserver";

	HUB="";
	USERNAME="";
	PASSWORD="";
}

start_installation () {
	root_checking

	set_installation_type_data

	set_jwt_secret

	set_core_machinekey

	get_os_info

	check_os_info

	check_kernel

	if [ "$SKIP_HARDWARE_CHECK" != "true" ]; then
		check_hardware
	fi

	if [ "$UPDATE" != "true" ]; then
		check_ports
	fi

	if [ "$MAKESWAP" == "true" ]; then
		make_swap
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

	echo ""
	echo "Thank you for installing ONLYOFFICE Docs."
	echo "In case you have any questions contact us via http://support.onlyoffice.com or visit our forum at http://dev.onlyoffice.org"
	echo ""

	exit 0;
}

start_installation
