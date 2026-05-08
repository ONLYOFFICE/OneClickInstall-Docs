#!/bin/bash

set -e

cat<<EOF

#######################################
#  INSTALL PREREQUISITES
#######################################

EOF

yum clean all
yum -y install expect nano policycoreutils-python*
semanage permissive -a httpd_t
package_services=""

if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
    # setup RabbitMQ repo
    curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | os=el dist=9 bash

    # setup Erlang repo
    if [[ "$(uname -m)" =~ (arm|aarch) ]]; then
        ERLANG_LATEST_URL=$(curl -s https://api.github.com/repos/rabbitmq/erlang-rpm/releases | \
            jq -r '.[] | .assets[]? | select(.name | test("erlang-[0-9\\.]+-1\\.el9\\.aarch64\\.rpm$")) | .browser_download_url' | head -n1)
        yum install -y "${ERLANG_LATEST_URL}"
    else
        curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | os=el dist=9 bash
    fi

    PSQL_AVAILABLE_VERSION=$(yum list postgresql\*-server --available 2>/dev/null | awk '/^postgresql[0-9]+-server/ {gsub("postgresql|-server.*","",$1); print $1}' | sort -nr | head -1)
    PSQL_AVAILABLE_VERSION=${PSQL_AVAILABLE_VERSION:-""}

    yum -y install valkey \
                   postgresql${PSQL_AVAILABLE_VERSION} \
                   postgresql${PSQL_AVAILABLE_VERSION}-server \
                   rabbitmq-server

    # configure Valkey
    if [ -e /etc/valkey.conf ]; then
        sed -i "s/bind .*/bind 127.0.0.1/g" /etc/valkey.conf
        sed -r "/^save\s[0-9]+/d" -i /etc/valkey.conf
    fi

    # configure PostgreSQL
    postgresql-setup initdb || true
    sed -E -i "s/(host\s+(all|replication)\s+all\s+(127\.0\.0\.1\/32|\:\:1\/128)\s+)(ident|trust|md5)/\1scram-sha-256/" /var/lib/pgsql/data/pg_hba.conf
    sed -i "s/^#\?password_encryption = .*/password_encryption = 'scram-sha-256'/" /var/lib/pgsql/data/postgresql.conf

    package_services="valkey rabbitmq-server postgresql"
fi
