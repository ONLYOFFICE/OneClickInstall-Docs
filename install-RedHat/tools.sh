#!/bin/bash

set -e

check_hardware () {
    DISK_REQUIREMENTS=10240
    MEMORY_REQUIREMENTS=2048
    CORE_REQUIREMENTS=2

    AVAILABLE_DISK_SPACE=$(df -m / | tail -1 | awk '{ print $4 }')

    if [ ${AVAILABLE_DISK_SPACE} -lt ${DISK_REQUIREMENTS} ]; then
        echo "Minimal requirements are not met: need at least $DISK_REQUIREMENTS MB of free HDD space"
        exit 1
    fi

    TOTAL_MEMORY=$(free --mega | grep -oP '\d+' | head -n 1);

    if [ ${TOTAL_MEMORY} -lt ${MEMORY_REQUIREMENTS} ]; then
        echo "Minimal requirements are not met: need at least $MEMORY_REQUIREMENTS MB of RAM"
        exit 1
    fi

    CPU_CORES_NUMBER=$(grep -c ^processor /proc/cpuinfo)

    if [ ${CPU_CORES_NUMBER} -lt ${CORE_REQUIREMENTS} ]; then
        echo "The system does not meet the minimal hardware requirements. CPU with at least $CORE_REQUIREMENTS cores is required"
        exit 1
    fi
}

if [ "$SKIP_HARDWARE_CHECK" != "true" ]; then
	check_hardware
fi

read_unsupported_installation () {
    read -p "$RES_CHOICE_INSTALLATION " CHOICE_INSTALLATION
    case "$CHOICE_INSTALLATION" in
        y|Y )
            yum -y install $DIST*-release
        ;;

        n|N )
            exit 0
        ;;

        * )
            echo $RES_CHOICE
            read_unsupported_installation
        ;;
    esac
}

read_rabbitmq_update () {
    read -p "$RES_CHOICE_RABBITMQ " CHOICE_INSTALLATION
    case "$CHOICE_INSTALLATION" in
        y|Y )
            yum -y remove rabbitmq-server erlang*
            rm -rf /var/lib/rabbitmq/mnesia/*@localhost
        ;;

        n|N )
            rm -f /etc/yum.repos.d/rabbitmq_*
        ;;

        * )
            echo $RES_CHOICE
            read_rabbitmq_update
        ;;
    esac
}

DIST=$(rpm -qa --queryformat '%{NAME}\n' | grep -E 'centos-release|redhat-release|fedora-release' | awk -F '-' '{print $1}' | head -n 1)
REV=$(sed -n 's/.*release\ \([0-9]*\).*/\1/p' /etc/redhat-release) || true
DIST=${DIST:-$(awk -F= '/^ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)}
REV=${REV:-$(awk -F= '/^VERSION_ID=/ {gsub(/"/, "", $2); print tolower($2)}' /etc/os-release)}

REDIS_PACKAGE=$( [[ "$REV" == "10" ]] && echo "valkey" || echo "redis" )
RABBIT_DIST_NAME=$( [[ "$REV" == "10" ]] && echo "el" || echo "$DIST" )
RABBIT_DIST_VER=$( [[ "$REV" == "10" ]] && echo "9" || echo "$REV" )
ERLANG_DIST_NAME=$( [[ "$REV" == "10" ]] && echo "el" || echo "$DIST" )
ERLANG_DIST_VER=$( [[ "$REV" == "10" ]] && echo "9" || echo "$REV" )

# Temporary workaround for missing CentOS 10 repos
if [ "$REV" = "10" ]; then
  APPSTREAM_PKGS="https://mirror.stream.centos.org/9-stream/AppStream/x86_64/os/Packages"
  yum -y install  "$APPSTREAM_PKGS/$(curl -fsSL "$APPSTREAM_PKGS/" | grep -oE 'libXScrnSaver-[0-9][^"]+\.x86_64\.rpm' | sort -V | tail -1)" \
                  "$APPSTREAM_PKGS/$(curl -fsSL "$APPSTREAM_PKGS/" | grep -oE 'xorg-x11-server-common-[0-9][^"]+\.x86_64\.rpm' | sort -V | tail -1)" \
                  "$APPSTREAM_PKGS/$(curl -fsSL "$APPSTREAM_PKGS/" | grep -oE 'xorg-x11-server-Xvfb-[0-9][^"]+\.x86_64\.rpm' | sort -V | tail -1)"
fi
