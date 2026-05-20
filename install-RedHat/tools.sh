#!/bin/bash

 #
 # Copyright (C) Ascensio System SIA, 2009-2026
 #
 # This program is a free software product. You can redistribute it and/or
 # modify it under the terms of the GNU Affero General Public License (AGPL)
 # version 3 as published by the Free Software Foundation, together with the
 # additional terms provided in the LICENSE file.
 #
 # This program is distributed WITHOUT ANY WARRANTY; without even the implied
 # warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. For
 # details, see the GNU AGPL at: https://www.gnu.org/licenses/agpl-3.0.html
 #
 # You can contact Ascensio System SIA by email at info@onlyoffice.com
 # or by postal mail at 20A-6 Ernesta Birznieka-Upisha Street, Riga,
 # LV-1050, Latvia, European Union.
 #
 # The interactive user interfaces in modified versions of the Program
 # are required to display Appropriate Legal Notices in accordance with
 # Section 5 of the GNU AGPL version 3.
 #
 # No trademark rights are granted under this License.
 #
 # All non-code elements of the Product, including illustrations,
 # icon sets, and technical writing content, are licensed under the
 # Creative Commons Attribution-ShareAlike 4.0 International License:
 # https://creativecommons.org/licenses/by-sa/4.0/legalcode
 #
 # This license applies only to such non-code elements and does not
 # modify or replace the licensing terms applicable to the Program's
 # source code, which remains licensed under the GNU Affero General
 # Public License v3.
 #
 # SPDX-License-Identifier: AGPL-3.0-only
 #

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

# On EL8 the repo contains EL9-built xorg packages (GLIBC_2.34+) that break `yum update`.
[ "$REV" = "8" ] && echo "excludepkgs=xorg-x11-server-Xvfb,xorg-x11-server-common" >> /etc/yum.repos.d/onlyoffice.repo || true
