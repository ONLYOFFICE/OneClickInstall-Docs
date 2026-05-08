#!/bin/bash

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

