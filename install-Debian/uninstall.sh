#!/bin/bash

set -e

echo "
#######################################
#  UNINSTALL
#######################################
"

read -r -p "Uninstall all dependencies (PostgreSQL, RabbitMQ and others)? (y/N): " DEP_CHOICE
DEP_CHOICE=${DEP_CHOICE,,}

DOCS_PACKAGE=$(dpkg-query -W -f='${Package}\n' | grep -E '^onlyoffice-documentserver(-ee|-de)?$' | head -n 1 || true)

if [[ "$DEP_CHOICE" =~ ^(y|yes)$ ]]; then
    mapfile -t DEP_PACKAGES < <(dpkg-query -W -f='${Package}\n' | grep -E '^(rabbitmq-server|redis-server|postgresql|postgresql-[0-9]+(-.*)?)$' || true)
fi

[ -n "$DOCS_PACKAGE" ] && apt-get purge -yq "$DOCS_PACKAGE"

if [[ "$DEP_CHOICE" =~ ^(y|yes)$ ]]; then
    systemctl stop postgresql rabbitmq-server redis-server >/dev/null 2>&1 || true
    [ ${#DEP_PACKAGES[@]} -gt 0 ] && apt-get remove -yq "${DEP_PACKAGES[@]}"
    apt-get autoremove -yq
    apt-get clean
fi

echo -e "\nUninstallation of ONLYOFFICE Docs \e[32mcompleted.\e[0m\n"

