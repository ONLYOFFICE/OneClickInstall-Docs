#!/bin/bash

set -e

cat<<EOF

#######################################
#  INSTALL PREREQUISITES
#######################################

EOF

yum clean all
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$REV.noarch.rpm || true
[ "$REV" = "9" ] && update-crypto-policies --set DEFAULT:SHA1
yum -y install yum-utils expect nano policycoreutils-python*

semanage permissive -a httpd_t

package_services=""

if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
    # setup RabbitMQ repo
    _rabbit_dist=$( [[ "$REV" == "10" ]] && echo "el" || echo "$DIST" )
    _rabbit_ver=$( [[ "$REV" == "10" ]] && echo "9" || echo "$REV" )
    curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | os=${_rabbit_dist} dist="${_rabbit_ver}" bash

    if rpm -q rabbitmq-server; then
        if [ "$(repoquery --installed rabbitmq-server --qf '%{ui_from_repo}' | sed 's/@//')" != "$(repoquery rabbitmq-server --qf='%{ui_from_repo}')" ]; then
            res_rabbitmq_update
            echo $RES_RABBITMQ_VERSION
            echo $RES_RABBITMQ_REMINDER
            echo $RES_RABBITMQ_INSTALLATION
            read_rabbitmq_update
        fi
    fi

    # setup Erlang repo
    if [[ "$(uname -m)" =~ (arm|aarch) ]]; then
        ERLANG_LATEST_URL=$(curl -s https://api.github.com/repos/rabbitmq/erlang-rpm/releases | jq -r --arg rev "$REV" \
            --arg major "$(repoquery --disablerepo='*' --enablerepo='rabbitmq_rabbitmq-server' --latest-limit=1 --requires rabbitmq-server | sed -n 's/^erlang >= \([0-9][0-9]*\)\..*/\1/p' | head -n1)" \
            '.[] | .assets[]? | select(.name | test("^erlang-" + $major + "\\.[0-9.]+-1\\.el" + $rev + "\\.aarch64\\.rpm$")) | .browser_download_url' | head -n1)
        yum install -y "${ERLANG_LATEST_URL}"
    else
        curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | os="${_rabbit_dist}" dist="${_rabbit_ver}" bash
    fi

    yum -y install ${REDIS_PACKAGE} \
                   postgresql \
                   postgresql-server \
                   rabbitmq-server

    # configure Redis
    if [ -e /etc/redis.conf ]; then
        sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis.conf
        sed -r "/^save\s[0-9]+/d" -i /etc/redis.conf
    fi

    # configure PostgreSQL
    postgresql-setup initdb || true
    sed -E -i "s/(host\s+(all|replication)\s+all\s+(127\.0\.0\.1\/32|\:\:1\/128)\s+)(ident|trust|md5)/\1scram-sha-256/" /var/lib/pgsql/data/pg_hba.conf
    sed -i "s/^#\?password_encryption = .*/password_encryption = 'scram-sha-256'/" /var/lib/pgsql/data/postgresql.conf

    package_services="${REDIS_PACKAGE} rabbitmq-server postgresql"
fi
