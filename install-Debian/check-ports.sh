#!/bin/bash

set -e

cat<<EOF

#######################################
#  CHECK PORTS
#######################################

EOF


if dpkg -l | grep -q "${package_sysname}-documentserver"; then
	echo "${package_sysname}-documentserver $RES_APP_INSTALLED"
	DOCUMENT_SERVER_INSTALLED="true";
elif [ $UPDATE != "true" ] && netstat -lnp | awk '{print $4}' | grep -qE ":8083$|:5432$|:5672$|:6379$|:8000$|:8080$|:80$"; then
	echo "${package_sysname}-documentserver $RES_APP_CHECK_PORTS: 8083, 5432, 5672, 6379, 8000, 8080, 80";
	echo "$RES_CHECK_PORTS"
	exit
else
	DOCUMENT_SERVER_INSTALLED="false";
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
	if [ "$UPDATE" != "true" ]; then
		exit;	
	fi
fi
