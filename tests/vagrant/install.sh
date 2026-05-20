#!/bin/bash

set -e

while [ "$1" != "" ]; do
  case $1 in
    -ds  | --download-scripts  ) [ -n "$2" ] && DOWNLOAD_SCRIPTS="$2"      && shift ;;
    -arg | --arguments         ) [ -n "$2" ] && ARGUMENTS="$2"            && shift ;;
    -tr  | --test-repo         ) [ -n "$2" ] && TEST_REPO_ENABLE="$2"     && shift ;;
    -v   | --version           ) [ -n "$2" ] && VER="$2"                  && shift ;;
    -it  | --installation-type ) [ -n "$2" ] && INSTALLATION_TYPE="$2"    && shift ;;
  esac
  shift
done

export TERM=xterm-256color

get_colors() {
  export LINE_SEPARATOR="-----------------------------------------"
  export COLOR_BLUE=$'\e[34m' COLOR_GREEN=$'\e[32m' COLOR_RED=$'\e[31m' COLOR_RESET=$'\e[0m' COLOR_YELLOW=$'\e[33m'
}

check_hw() {
  echo "${COLOR_RED}$(free -h)${COLOR_RESET}"
  echo "${COLOR_RED}$(nproc)${COLOR_RESET}"
}

prepare_vm() {
  if ! command -v curl >/dev/null 2>&1; then
    (command -v apt-get >/dev/null 2>&1 && apt-get update -y && apt-get install -y curl) || (command -v dnf >/dev/null 2>&1 && dnf install -y curl)
  fi

  if grep -qi 'debian\|ubuntu' /etc/os-release; then
    . /etc/os-release
    if [ "$VERSION_CODENAME" = buster ]; then
      find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \) -exec sed -Ei \
        -e 's|http://deb\.debian\.org/debian/?|http://archive.debian.org/debian/|g' \
        -e 's|http://security\.debian\.org/debian-security/?|http://archive.debian.org/debian-security/|g' \
        -e 's|http://ftp\.uk\.debian\.org/debian/?|http://archive.debian.org/debian/|g' {} +
      echo "${COLOR_GREEN}[OK] PREPARE_VM: Debian 10 sources switched to archive.debian.org${COLOR_RESET}"
    fi

    if [ "${TEST_REPO_ENABLE:-}" = 'true' ]; then
      echo "deb [trusted=yes] https://s3.eu-west-1.amazonaws.com/repo-doc-onlyoffice-com/repo/debian stable ${VER}" | sudo tee /etc/apt/sources.list.d/onlyoffice-dev.list
    fi

    if grep -qi '^ID=debian' /etc/os-release && dpkg -s postfix &>/dev/null; then
      apt-get remove postfix -y && echo "${COLOR_GREEN}[OK] PREPARE_VM: Postfix was removed${COLOR_RESET}"
    fi
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
    fi

    if [ "$REV" = "8" ]; then
      if grep -qi 'centos' /etc/redhat-release 2>/dev/null; then
        sudo sed -i 's|^mirrorlist=|#&|; s|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' /etc/yum.repos.d/CentOS-*
      else
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

  rm -rf /home/vagrant/*
  if [ -d /tmp/docs ]; then
    mv /tmp/docs/* /home/vagrant
  fi

  echo '127.0.0.1 host4test' | sudo tee -a /etc/hosts
  echo "${COLOR_GREEN}[OK] PREPARE_VM: Hostname was setting up${COLOR_RESET}"
}

install_docs() {
  if [ "${DOWNLOAD_SCRIPTS}" == 'true' ]; then
    echo "${COLOR_BLUE}Downloading docs-install.sh...${COLOR_RESET}"
    curl -fsSLO https://download.onlyoffice.com/docs/docs-install.sh
  fi

  local IT_FLAG="${INSTALLATION_TYPE:+--installationtype ${INSTALLATION_TYPE}}"
  printf "N\nY\nY\nY" | bash docs-install.sh ${ARGUMENTS} ${IT_FLAG} || { echo "Exit code non-zero. Exit with 1."; exit 1; }
}

main() {
  get_colors

  echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
  echo "${COLOR_BLUE}STEP 1: Preparing VM environment${COLOR_RESET}"
  echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
  prepare_vm

  echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
  echo "${COLOR_BLUE}STEP 2: Checking hardware${COLOR_RESET}"
  echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
  check_hw

  echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
  echo "${COLOR_BLUE}STEP 3: Installing${COLOR_RESET}"
  echo "${COLOR_BLUE}${LINE_SEPARATOR}${COLOR_RESET}"
  install_docs

  install -m 755 -D /tmp/post-install.sh /home/vagrant/tests/vagrant/post-install.sh 2>/dev/null || true
}

main
