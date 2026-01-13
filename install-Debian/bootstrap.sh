#!/bin/bash

set -e

cat<<EOF

#######################################
#  BOOTSTRAP
#######################################

EOF

timeout 60s bash -c 'while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done' || { echo "Error: Lock not released"; exit 1; }

. /etc/os-release && [ "$VERSION_CODENAME" = buster ] && find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \) -exec sed -Ei \
  -e 's|http://deb\.debian\.org/debian/?|http://archive.debian.org/debian/|g' \
  -e 's|http://security\.debian\.org/debian-security/?|http://archive.debian.org/debian-security/|g' \
  -e 's|http://ftp\.uk\.debian\.org/debian/?|http://archive.debian.org/debian/|g' {} +

apt-get -y update
apt-get install -yq sudo net-tools dirmngr

