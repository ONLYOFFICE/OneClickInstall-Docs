#!/bin/bash

set -e

cat<<EOF

#######################################
#  BOOTSTRAP
#######################################

EOF

if ! dpkg -l | grep -q "sudo"; then
	apt-get install -yq sudo
fi

if ! dpkg -l | grep -q "net-tools"; then
	apt-get install -yq net-tools
fi

if ! dpkg -l | grep -q "dirmngr"; then
	apt-get install -yq dirmngr
fi

timeout 60s bash -c 'while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done' || { echo "Error: Lock not released"; exit 1; }
