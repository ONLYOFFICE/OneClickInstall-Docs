#!/bin/bash

set -e

cat<<EOF

#######################################
#  CHECK PORTS
#######################################

EOF

if ! rpm -q net-tools &>/dev/null; then
    yum -y install net-tools
fi

[ "${INSTALLATION_TYPE}" != "COMMUNITY" ] && _ee=1 || _ee=
PORT_PATTERN="${_ee:+:5432$|:5672$|}:6379$|:8000$|:${DS_PORT:-80}$"
PORT_LIST="${_ee:+5432, 5672, }6379, 8000, ${DS_PORT:-80}"

if rpm -qa | grep ${package_sysname}-documentserver; then
    echo "${package_sysname}-documentserver $RES_APP_INSTALLED"
    DOCUMENT_SERVER_INSTALLED="true"
elif [ "${UPDATE}" != "true" ] && netstat -lnp | awk '{print $4}' | grep -qE "${PORT_PATTERN}"; then
    echo "${package_sysname}-documentserver $RES_APP_CHECK_PORTS: ${PORT_LIST}"
    echo "$RES_CHECK_PORTS"
    exit
else
    DOCUMENT_SERVER_INSTALLED="false"
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
    if [ "$UPDATE" != "true" ]; then
        exit
    fi
fi
