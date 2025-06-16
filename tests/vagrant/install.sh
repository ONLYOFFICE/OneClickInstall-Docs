#!/bin/bash

set -e 

while [ "$1" != "" ]; do
	case $1 in

		-ds | --download-scripts )
                        if [ "$2" != "" ]; then
                                DOWNLOAD_SCRIPTS=$2
                                shift
                        fi
                ;;

                -arg | --arguments )
                        if [ "$2" != "" ]; then
                                ARGUMENTS=$2
                                shift
                        fi
                ;;


	        -pi | --production-install )
			if [ "$2" != "" ]; then
				PRODUCTION_INSTALL=$2
				shift
			fi
		;;

		-li | --local-install )
                        if [ "$2" != "" ]; then
                                LOCAL_INSTALL=$2
                                shift
                        fi
                ;;

		-lu | --local-update )
                        if [ "$2" != "" ]; then
                                LOCAL_UPDATE=$2
                                shift
                        fi
                ;;

	        -tr | --test-repo )
			if [ "$2" != "" ]; then
				TEST_REPO_ENABLE=$2
				shift
		        fi
		;;

		-v | --version )
	                if [ "$2" != "" ]; then
				VER=$2
				shift
		        fi
		;;

        esac
	shift
done

export TERM=xterm-256color

SERVICES_SYSTEMD=(
        "ds-converter.service"
        "ds-docservice.service"
        "ds-metrics.service")      

function common::get_colors() {
    COLOR_BLUE=$'\e[34m'
    COLOR_GREEN=$'\e[32m'
    COLOR_RED=$'\e[31m'
    COLOR_RESET=$'\e[0m'
    COLOR_YELLOW=$'\e[33m'
    export COLOR_BLUE
    export COLOR_GREEN
    export COLOR_RED
    export COLOR_RESET
    export COLOR_YELLOW
}

#############################################################################################
# Checking available resources for a virtual machine
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   None
#############################################################################################
function check_hw() {
        local FREE_RAM=$(free -h)
	local FREE_CPU=$(nproc)
	echo "${COLOR_RED} ${FREE_RAM} ${COLOR_RESET}"
        echo "${COLOR_RED} ${FREE_CPU} ${COLOR_RESET}"
}


#############################################################################################
# Prepare vagrant boxes like: set hostname/remove postfix for DEB distributions
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   [OK] PREPARE_VM: **<prepare_message>**
#############################################################################################
function prepare_vm() {
  if grep -qi 'debian\|ubuntu' /etc/os-release; then
	if [ "${TEST_REPO_ENABLE}" == 'true' ]; then
	    echo "deb [trusted=yes] https://s3.eu-west-1.amazonaws.com/repo-doc-onlyoffice-com/repo/debian stable ${VER}" | sudo tee /etc/apt/sources.list.d/onlyoffice-dev.list
	fi

  	[ -f /etc/os-release ] && [ "$(awk -F= '/^ID=/ {print $2}' /etc/os-release | tr -d '"')" == "debian" ] &&
  	{ apt-get remove postfix -y; echo "${COLOR_GREEN}[OK] PREPARE_VM: Postfix was removed${COLOR_RESET}"; }
  fi

  if [ -f /etc/redhat-release ] || [ -f /etc/amazon-linux-release ]; then
	  local REV=$(sed -E 's/[^0-9]+([0-9]+).*/\1/' /etc/redhat-release)
	  if [[ "${REV}" =~ ^9 ]]; then
		  update-crypto-policies --set LEGACY
		  echo "${COLOR_GREEN}[OK] PREPARE_VM: sha1 gpg key check enabled${COLOR_RESET}"
      cat <<EOF | sudo tee /etc/yum.repos.d/centos-stream-9.repo
[centos9s-baseos]
name=CentOS Stream 9 - BaseOS
baseurl=http://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/
enabled=1
gpgcheck=0

[centos9s-appstream]
name=CentOS Stream 9 - AppStream
baseurl=http://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/
enabled=1
gpgcheck=0
EOF
    else
      if grep -qi 'centos' /etc/redhat-release; then
          sudo sed -i 's|^mirrorlist=|#&|; s|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' /etc/yum.repos.d/CentOS-*
      elif [ "$REV" == "8" ]; then
            cat <<EOF | sudo tee /etc/yum.repos.d/CentOS-Vault.repo
[BaseOS]
name=CentOS-8 - Base
baseurl=http://vault.centos.org/8.5.2111/BaseOS/x86_64/os/
gpgcheck=0
enabled=1
[AppStream]
name=CentOS-8 - AppStream
baseurl=http://vault.centos.org/8.5.2111/AppStream/x86_64/os/
gpgcheck=0
enabled=1
EOF
      fi
    fi
	  if [ "${TEST_REPO_ENABLE}" == 'true' ]; then
               yum-config-manager --add-repo https://s3.eu-west-1.amazonaws.com/repo-doc-onlyoffice-com/repo/centos/onlyoffice-dev-${VER}.repo
	  fi
  fi

  # Clean up home folder
  rm -rf /home/vagrant/*

  if [ -d /tmp/docs ]; then
          mv /tmp/docs/* /home/vagrant
  fi


  echo '127.0.0.1 host4test' | sudo tee -a /etc/hosts   
  echo "${COLOR_GREEN}[OK] PREPARE_VM: Hostname was setting up${COLOR_RESET}"   

}

#############################################################################################
# Install docs and then healthcheck
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   Script log
#############################################################################################
function install_docs() {
	if [ "${DOWNLOAD_SCRIPTS}" == 'true' ]; then
            wget https://download.onlyoffice.com/install/docs-install.sh
        fi
        
	printf "N\nY\nY\nY" | bash docs-install.sh ${ARGUMENTS}

	if [[ $? != 0 ]]; then
	    echo "Exit code non-zero. Exit with 1."
	    exit 1
	else
	    echo "Exit code 0. Continue..."
	fi
}

#############################################################################################
# Healthcheck function for systemd services
# Globals:
#   SERVICES_SYSTEMD
# Arguments:
#   None
# Outputs:
#   Message about service status 
#############################################################################################
function healthcheck_systemd_services() {
  for service in ${SERVICES_SYSTEMD[@]} 
  do 
    if systemctl is-active --quiet ${service}; then
      echo "${COLOR_GREEN}[OK] Service ${service} is running${COLOR_RESET}"
    else 
      echo "${COLOR_RED}[FAILED] Service ${service} is not running${COLOR_RESET}"
      SYSTEMD_SVC_FAILED="true"
    fi
  done
}

#############################################################################################
# Set output if some services failed
# Globals:
#   None
# Arguments:
#   None
# Outputs:
#   [WARNING] ATTENTION: Some services is not running
# Returns
# 0 if all services is start correctly, non-zero if some failed
#############################################################################################
function healthcheck_general_status() {
  if [ ! -z "${SYSTEMD_SVC_FAILED}" ]; then
    echo "${COLOR_YELLOW}[WARNING] ATTENTION: Some services is not running${COLOR_RESET}"
    exit 1
  fi
}

#############################################################################################
# Get logs for all services
# Globals:
#   $SERVICES_SYSTEMD
# Arguments:
#   None
# Outputs:
#   Logs for systemd services
# Returns:
#   none
# Commentaries:
# This function succeeds even if the file for cat was not found. For that use ${SKIP_EXIT} variable
#############################################################################################
function services_logs() {
  for service in ${SERVICES_SYSTEMD[@]}; do
    echo -----------------------------------------
    echo "${COLOR_GREEN}Check logs for systemd service: $service${COLOR_RESET}"
    echo -----------------------------------------
    EXIT_CODE=0
    journalctl -u $service || true
  done
  
  local MAIN_LOGS_DIR="/var/log/onlyoffice"
  local DOCS_LOGS_DIR="${MAIN_LOGS_DIR}/documentserver"
  local DOCSERVICE_LOGS_DIR="${DOCS_LOGS_DIR}/docservice"
  local CONVERTER_LOGS_DIR="${DOCS_LOGS_DIR}/converter"
  local METRICS_LOGS_DIR="${DOCS_LOGS_DIR}/metrics"
       
  ARRAY_DOCSERVICE_LOGS=($(ls ${DOCSERVICE_LOGS_DIR}))
  ARRAY_CONVERTER_LOGS=($(ls ${CONVERTER_LOGS_DIR}))
  ARRAY_METRICS_LOGS=($(ls ${METRICS_LOGS_DIR}))
  
  echo             "-----------------------------------"
  echo "${COLOR_YELLOW} Check logs for Docservice ${COLOR_RESET}"
  echo             "-----------------------------------"
  for file in ${ARRAY_DOCSERVICE_LOGS[@]}; do
    echo ---------------------------------------
    echo "${COLOR_GREEN}logs from file: ${file}${COLOR_RESET}"
    echo ---------------------------------------
    cat ${DOCSERVICE_LOGS_DIR}/${file} || true
  done
  
  echo             "-----------------------------------"
  echo "${COLOR_YELLOW} Check logs for Converter ${COLOR_RESET}"
  echo             "-----------------------------------"
  for file in ${ARRAY_CONVERTER_LOGS[@]}; do
    echo ---------------------------------------
    echo "${COLOR_GREEN}logs from file ${file}${COLOR_RESET}"
    echo ---------------------------------------
    cat ${CONVERTER_LOGS_DIR}/${file} || true
  done
  
  echo             "-----------------------------------"
  echo "${COLOR_YELLOW} Start logs for Metrics ${COLOR_RESET}"
  echo             "-----------------------------------"
  for file in ${ARRAY_METRICS_LOGS[@]}; do
    echo ---------------------------------------
    echo "${COLOR_GREEN}logs from file ${file}${COLOR_RESET}"
    echo ---------------------------------------
    cat ${METRICS_LOGS_DIR}/${file} || true
  done
}

function healthcheck_docker_installation() {
	exit 0
}

function healthcheck_curl {
  url=${url:-"http://localhost"}

  healthcheck_res=$(wget --no-check-certificate -qO - ${url}/healthcheck)

  if [[ $healthcheck_res == "true" ]]; then
    echo "Healthcheck passed."
  else
    echo "Healthcheck failed!"
    exit 1
  fi
}

main() {
  common::get_colors
  prepare_vm
  check_hw
  install_docs
  sleep 120
  healthcheck_curl
  services_logs
  healthcheck_systemd_services
  healthcheck_general_status
}

main
