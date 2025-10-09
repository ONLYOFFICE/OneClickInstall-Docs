#!/bin/bash

set -e 

while [ "$1" != "" ]; do
	case $1 in
    -ds  | --download-scripts  ) [ -n "$2" ] && DOWNLOAD_SCRIPTS="$2"      && shift ;;
    -arg | --arguments         ) [ -n "$2" ] && ARGUMENTS="$2"             && shift ;;
    -tr  | --test-repo         ) [ -n "$2" ] && TEST_REPO_ENABLE="$2"      && shift ;;
    -v   | --version           ) [ -n "$2" ] && VER="$2"                   && shift ;;
  esac
  shift
done

export TERM=xterm-256color

SERVICES_SYSTEMD=("ds-converter.service" "ds-docservice.service" "ds-metrics.service")

get_colors() {
  COLOR_BLUE=$'\e[34m'
  COLOR_GREEN=$'\e[32m'
  COLOR_RED=$'\e[31m'
  COLOR_RESET=$'\e[0m'
  COLOR_YELLOW=$'\e[33m'
}

check_hw() {
  echo "${COLOR_RED}$(free -h)${COLOR_RESET}"
  echo "${COLOR_RED}$(nproc)${COLOR_RESET}"
}

prepare_vm() {
  if grep -qi 'debian\|ubuntu' /etc/os-release; then
    if [ "${TEST_REPO_ENABLE:-}" = 'true' ]; then
      echo "deb [trusted=yes] https://s3.eu-west-1.amazonaws.com/repo-doc-onlyoffice-com/repo/debian stable ${VER}" | sudo tee /etc/apt/sources.list.d/onlyoffice-dev.list
    fi

    grep -qi '^ID=debian' /etc/os-release && { apt-get remove postfix -y; echo "${COLOR_GREEN}[OK] PREPARE_VM: Postfix was removed${COLOR_RESET}"; }
  fi

  if [ -f /etc/redhat-release ] || [ -f /etc/amazon-linux-release ]; then
    local REV
    if [ -f /etc/redhat-release ]; then
      REV=$(sed -E 's/[^0-9]+([0-9]+).*/\1/' /etc/redhat-release)
    else
      REV=$(sed -E 's/[^0-9]+([0-9]+).*/\1/' /etc/amazon-linux-release)
    fi

    if [[ "$REV" =~ ^9 ]]; then
      update-crypto-policies --set LEGACY || true
      echo "${COLOR_GREEN}[OK] PREPARE_VM: sha1 gpg key check enabled${COLOR_RESET}"
      cat <<'EOF' | sudo tee /etc/yum.repos.d/centos-stream-9.repo >/dev/null
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
      if grep -qi 'centos' /etc/redhat-release 2>/dev/null; then
        sudo sed -i 's|^mirrorlist=|#&|; s|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' /etc/yum.repos.d/CentOS-*
      elif [ "$REV" = "8" ]; then
        cat <<'EOF' | sudo tee /etc/yum.repos.d/CentOS-Vault.repo >/dev/null
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

    if [ "${TEST_REPO_ENABLE:-}" = 'true' ]; then
      yum-config-manager --add-repo "https://s3.eu-west-1.amazonaws.com/repo-doc-onlyoffice-com/repo/centos/onlyoffice-dev-${VER}.repo"
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

install_docs() {
  if ! command -v curl >/dev/null 2>&1; then
    (command -v apt-get >/dev/null 2>&1 && apt-get update -y && apt-get install -y curl) || (command -v dnf >/dev/null 2>&1 && dnf install -y curl)
  fi

	if [ "${DOWNLOAD_SCRIPTS}" == 'true' ]; then
    echo "${COLOR_BLUE}Downloading docs-install.sh...${COLOR_RESET}"
    curl -fsSLO https://download.onlyoffice.com/docs/docs-install.sh
  fi

	printf "N\nY\nY\nY" | bash docs-install.sh ${ARGUMENTS}
}

healthcheck_systemd_services() {
  for service in ${SERVICES_SYSTEMD[@]}; do
    if systemctl is-active --quiet ${service}; then
      echo "${COLOR_GREEN}[OK] Service ${service} is running${COLOR_RESET}"
    else 
      echo "${COLOR_RED}[FAILED] Service ${service} is not running${COLOR_RESET}"
      SYSTEMD_SVC_FAILED="true"
    fi
  done

  if [ ! -z "${SYSTEMD_SVC_FAILED}" ]; then
    echo "${COLOR_YELLOW}[WARNING] ATTENTION: Some services is not running${COLOR_RESET}"
    exit 1
  fi
}

services_logs() {
  for service in "${SERVICES_SYSTEMD[@]}"; do
    echo -----------------------------------------
    echo "${COLOR_GREEN}Check logs for systemd service: $service${COLOR_RESET}"
    echo -----------------------------------------
    journalctl -u "$service" --no-pager || true
  done

  local MAIN_LOGS_DIR="/var/log/onlyoffice"
  local DOCS_LOGS_DIR="${MAIN_LOGS_DIR}/documentserver"
  local DOCSERVICE_LOGS_DIR="${DOCS_LOGS_DIR}/docservice"
  local CONVERTER_LOGS_DIR="${DOCS_LOGS_DIR}/converter"
  local METRICS_LOGS_DIR="${DOCS_LOGS_DIR}/metrics"

  shopt -s nullglob

  echo "-----------------------------------"
  echo "${COLOR_YELLOW} Check logs for Docservice ${COLOR_RESET}"
  echo "-----------------------------------"
  for file in "${DOCSERVICE_LOGS_DIR}"/*; do
    echo ---------------------------------------
    echo "${COLOR_GREEN}logs from file: $(basename "$file")${COLOR_RESET}"
    echo ---------------------------------------
    cat "$file" || true
  done

  echo "-----------------------------------"
  echo "${COLOR_YELLOW} Check logs for Converter ${COLOR_RESET}"
  echo "-----------------------------------"
  for file in "${CONVERTER_LOGS_DIR}"/*; do
    echo ---------------------------------------
    echo "${COLOR_GREEN}logs from file $(basename "$file")${COLOR_RESET}"
    echo ---------------------------------------
    cat "$file" || true
  done

  echo "-----------------------------------"
  echo "${COLOR_YELLOW} Start logs for Metrics ${COLOR_RESET}"
  echo "-----------------------------------"
  for file in "${METRICS_LOGS_DIR}"/*; do
    echo ---------------------------------------
    echo "${COLOR_GREEN}logs from file $(basename "$file")${COLOR_RESET}"
    echo ---------------------------------------
    cat "$file" || true
  done

  shopt -u nullglob
}

healthcheck_curl () {
  url=${url:-"http://localhost"}
  healthcheck_res=$(curl -fsSk "${url}/healthcheck" || true)
  if [[ $healthcheck_res == "true" ]]; then
    echo "Healthcheck passed."
  else
    echo "Healthcheck failed!"
    exit 1
  fi
}

main() {
  get_colors
  prepare_vm
  check_hw
  install_docs
  sleep 120
  healthcheck_curl
  services_logs
  healthcheck_systemd_services
}

main
