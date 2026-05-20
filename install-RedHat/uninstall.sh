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

echo "
#######################################
#  UNINSTALL
#######################################
"

read -r -p "Uninstall all dependencies (PostgreSQL, RabbitMQ, Redis and others)? (y/N): " DEP_CHOICE
DEP_CHOICE=${DEP_CHOICE,,}

DOCS_PACKAGE=$(rpm -qa --qf '%{NAME}\n' | grep -E '^onlyoffice-documentserver(-ee|-de)?$' | head -n 1 || true)

if [[ "$DEP_CHOICE" =~ ^(y|yes)$ ]]; then
    mapfile -t DEP_PACKAGES < <(rpm -qa --qf '%{NAME}\n' | grep -E '^(rabbitmq-server|redis|valkey|postgresql([0-9]+)?|postgresql([0-9]+)?-server)$' || true)
fi

[ -n "$DOCS_PACKAGE" ] && ${package_manager} -y remove "$DOCS_PACKAGE"

if [[ "$DEP_CHOICE" =~ ^(y|yes)$ ]]; then
    for svc in postgresql rabbitmq-server redis valkey; do
        systemctl stop "$svc" >/dev/null 2>&1 || true
    done
    [ ${#DEP_PACKAGES[@]} -gt 0 ] && ${package_manager} -y remove "${DEP_PACKAGES[@]}"
    ${package_manager} -y autoremove
    ${package_manager} clean all
fi

echo -e "\nUninstallation of ONLYOFFICE Docs \e[32mcompleted.\e[0m\n"

