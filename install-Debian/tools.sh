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

command_exists() { type "$1" &>/dev/null; }

check_hardware () {
    DISK_REQUIREMENTS=10240
    MEMORY_REQUIREMENTS=2048
    CORE_REQUIREMENTS=2

    AVAILABLE_DISK_SPACE=$(df -m / | tail -1 | awk '{ print $4 }')
    TOTAL_MEMORY=$(free --mega | grep -oP '\d+' | head -n 1)
    CPU_CORES_NUMBER=$(grep -c "processor" /proc/cpuinfo)

    if [ "${AVAILABLE_DISK_SPACE}" -lt ${DISK_REQUIREMENTS} ]; then
        echo "Minimal requirements are not met: need at least $DISK_REQUIREMENTS MB of free HDD space"
        exit 1
    fi

    if [ "${TOTAL_MEMORY}" -lt ${MEMORY_REQUIREMENTS} ]; then
        echo "Minimal requirements are not met: need at least $MEMORY_REQUIREMENTS MB of RAM"
        exit 1
    fi

    if [ "${CPU_CORES_NUMBER}" -lt ${CORE_REQUIREMENTS} ]; then
        echo "The system does not meet the minimal hardware requirements. CPU with at least $CORE_REQUIREMENTS cores is required"
        exit 1
    fi
}

[ "$SKIP_HARDWARE_CHECK" != "true" ] && check_hardware

DIST='Debian'
DISTRIB_CODENAME='bullseye'
if [ -f /etc/lsb-release ]; then
    DIST=$(grep '^DISTRIB_ID=' /etc/lsb-release | awk -F= '{print $2}')
    DISTRIB_CODENAME=$(grep '^DISTRIB_CODENAME=' /etc/lsb-release | awk -F= '{print $2}')
elif [ -f /etc/lsb_release ] || command_exists lsb_release; then
    DIST=$(lsb_release -a 2>&1 | awk -F ":" '/Distributor ID:/ {print $2}' | xargs)
    DISTRIB_CODENAME=$(lsb_release -a 2>&1 | awk -F ":" '/Codename:/ {print $2}' | xargs)
elif [ -f /etc/os-release ]; then
    DISTRIB_CODENAME=$(grep "VERSION=" /etc/os-release | awk -F= '{print $2}' | sed 's/["0-9()]//g' | tr -d '[:space:]')
fi

if grep -qi "openkylin" /etc/os-release; then
    DIST="Debian"
    DISTRIB_CODENAME="bullseye"
fi

DIST=$(echo "$DIST" | tr '[:upper:]' '[:lower:]' | xargs)
DISTRIB_CODENAME=$(echo "$DISTRIB_CODENAME" | tr '[:upper:]' '[:lower:]' | xargs)
