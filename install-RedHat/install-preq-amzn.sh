#!/bin/bash

set -e

cat<<EOF

#######################################
#  INSTALL PREREQUISITES
#######################################

EOF

# clean yum cache
yum clean all
yum -y install yum-utils
{ yum check-update $DIST*-release; exitCode=$?; } || true #Checking for distribution update

UPDATE_AVAILABLE_CODE=100
if [[ $exitCode -eq $UPDATE_AVAILABLE_CODE ]]; then
    res_unsupported_version
    echo $RES_UNSUPPORTED_VERSION
    echo $RES_SELECT_INSTALLATION
    echo $RES_ERROR_REMINDER
    echo $RES_QUESTIONS
    read_unsupported_installation
fi

#add rabbitmq repo
curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | os=el dist=9 bash

if rpm -q rabbitmq-server; then
    if [ "$(yum list installed rabbitmq-server | awk 'NR>1 {gsub(/^@/, "", $NF); print $NF}')" != "$(repoquery rabbitmq-server --qf='%{ui_from_repo}')" ]; then
        res_rabbitmq_update
        echo $RES_RABBITMQ_VERSION
        echo $RES_RABBITMQ_REMINDER
        echo $RES_RABBITMQ_INSTALLATION
        read_rabbitmq_update
    fi
fi

#add erlang repo
#or download the RPM package for the latest erlang release
if [[ "$(uname -m)" =~ (arm|aarch) ]]; then
    ERLANG_LATEST_URL=$(curl -s https://api.github.com/repos/rabbitmq/erlang-rpm/releases | \
        jq -r '.[] | .assets[]? | select(.name | test("erlang-[0-9\\.]+-1\\.el" + 9 + "\\.aarch64\\.rpm$")) | .browser_download_url' | head -n1)
    yum install -y "${ERLANG_LATEST_URL}"
else
    curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | os=el dist=9 bash
fi

PSQL_INSTALLED_VERSION=$(rpm -qa | grep -Eo '^postgresql[0-9]+' | sed 's/^postgresql//' | sort -nr | head -1)
PSQL_AVAILABLE_VERSION=$(yum list postgresql\*-server --available | awk '/^postgresql[0-9]+-server/ {gsub("postgresql|-server.*","",$1); print $1}' | sort -nr | head -1)
PSQL_VERSION=${PSQL_INSTALLED_VERSION:-$PSQL_AVAILABLE_VERSION}
{ yum check-update postgresql${PSQL_VERSION}; PSQLExitCode=$?; } || true

yum -y install expect \
               nano \
               postgresql${PSQL_VERSION} \
               postgresql${PSQL_VERSION}-server \
               rabbitmq-server \
               valkey \
               policycoreutils-python*

if [[ ${PSQLExitCode} -eq ${UPDATE_AVAILABLE_CODE} ]]; then
    yum -y install postgresql${PSQL_INSTALLED_VERSION}-upgrade
    postgresql-setup --upgrade || true
fi
postgresql-setup initdb	|| true
sed -E -i "s/(host\s+(all|replication)\s+all\s+(127\.0\.0\.1\/32|\:\:1\/128)\s+)(ident|trust|md5)/\1scram-sha-256/" /var/lib/pgsql/data/pg_hba.conf
sed -i "s/^#\?password_encryption = .*/password_encryption = 'scram-sha-256'/" /var/lib/pgsql/data/postgresql.conf

semanage permissive -a httpd_t

if [ -e /etc/valkey.conf ]; then
    sed -i "s/bind .*/bind 127.0.0.1/g" /etc/valkey.conf
    sed -r "/^save\s[0-9]+/d" -i /etc/valkey.conf
fi

package_services="rabbitmq-server postgresql valkey"
