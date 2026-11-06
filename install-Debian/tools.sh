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

    AVAILABLE_DISK_SPACE=$(df -Pm / | awk 'NR == 2 { print $4 }')
    TOTAL_MEMORY=$(free --mega | awk '/^Mem:/ { print $2 }')
    CPU_CORES_NUMBER=$(nproc --all)

    REQUIREMENTS_NOT_MET=""

    if [ "${AVAILABLE_DISK_SPACE}" -lt ${DISK_REQUIREMENTS} ]; then
        REQUIREMENTS_NOT_MET="${REQUIREMENTS_NOT_MET}\n  - at least $DISK_REQUIREMENTS MB of free HDD space (available: ${AVAILABLE_DISK_SPACE} MB)"
    fi

    if [ "${TOTAL_MEMORY}" -lt ${MEMORY_REQUIREMENTS} ]; then
        REQUIREMENTS_NOT_MET="${REQUIREMENTS_NOT_MET}\n  - at least $MEMORY_REQUIREMENTS MB of RAM (available: ${TOTAL_MEMORY} MB)"
    fi

    if [ "${CPU_CORES_NUMBER}" -lt ${CORE_REQUIREMENTS} ]; then
        REQUIREMENTS_NOT_MET="${REQUIREMENTS_NOT_MET}\n  - a CPU with at least $CORE_REQUIREMENTS cores (available: ${CPU_CORES_NUMBER})"
    fi

    if [ -n "${REQUIREMENTS_NOT_MET}" ]; then
        printf "Minimal requirements are not met, your system needs:%b\n\n" "${REQUIREMENTS_NOT_MET}"

        # Without a terminal there is nobody to ask
        if [ ! -t 0 ]; then
            echo "To skip this check, use the --skiphardwarecheck true parameter"
            exit 1
        fi

        read -r -p "Continue installation anyway? (y/N): " CONTINUE_CHOICE
        [[ "${CONTINUE_CHOICE,,}" =~ ^(y|yes)$ ]] || exit 1
    fi
}

if [ "$SKIP_HARDWARE_CHECK" != "true" ]; then
    check_hardware
fi

ARCH="$(dpkg --print-architecture)"
if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
    echo "ONLYOFFICE Docs doesn't support architecture '$ARCH'"
    exit 1
fi

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

if [ "$ARCH" = "arm64" ] && [[ "$DIST" != "ubuntu" && "$DIST" != "debian" ]]; then
    echo "ONLYOFFICE Docs on architecture '$ARCH' is supported only on Debian and Ubuntu (detected '${DIST}'). Please use a Docker installation."
    exit 1
fi

# openKylin reports its own version numbers, so the end-of-life check does not apply to it.
OS_VERSION_MAJOR=$( . /etc/os-release 2>/dev/null; echo "${VERSION_ID%%.*}" ) || true
if [[ "$OS_VERSION_MAJOR" =~ ^[0-9]+$ ]] && ! grep -qi "openkylin" /etc/os-release; then
    if [[ ( "$DIST" == "ubuntu" && "$OS_VERSION_MAJOR" -lt 20 ) || ( "$DIST" == "debian" && "$OS_VERSION_MAJOR" -lt 11 ) ]]; then
        echo "Your ${DIST} ${OS_VERSION_MAJOR} operating system has reached the end of its service life."
        echo "Please consider upgrading your operating system or using a Docker installation."
        exit 1
    fi
fi
