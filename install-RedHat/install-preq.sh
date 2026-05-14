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
