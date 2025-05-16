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

DIST=$(rpm -q --whatprovides redhat-release || rpm -q --whatprovides centos-release)
DIST=$(echo $DIST | sed -n '/-.*/s///p')
REV=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//)
REV_PARTS=(${REV//\./ })
REV=${REV_PARTS[0]}

{ yum check-update postgresql; PSQLExitCode=$?; } || true 
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

[ "$REV" = "9" ] && update-crypto-policies --set DEFAULT:SHA1 && yum -y install xorg-x11-font-utils

#Add repo EPEL
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$REV.noarch.rpm || true

#add rabbitmq repo
curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | bash

if rpm -q rabbitmq-server; then
    if [ "$(repoquery --installed rabbitmq-server --qf '%{ui_from_repo}' | sed 's/@//')" != "$(repoquery rabbitmq-server --qf='%{ui_from_repo}')" ]; then
        res_rabbitmq_update
        echo $RES_RABBITMQ_VERSION
        echo $RES_RABBITMQ_REMINDER
        echo $RES_RABBITMQ_INSTALLATION
        read_rabbitmq_update
    fi
fi

#add erlang repo
#or download the RPM package for the latest erlang release
if [[ "$(uname -m)" =~ (arm|aarch) ]] && [[ $REV -gt 7 ]]; then
    ERLANG_LATEST_URL=$(curl -s https://api.github.com/repos/rabbitmq/erlang-rpm/releases | jq -r --arg rev "$REV" \
        '.[] | .assets[]? | select(.name | test("erlang-[0-9\\.]+-1\\.el" + $rev + "\\.aarch64\\.rpm$")) | .browser_download_url' | head -n1)
    yum install -y "${ERLANG_LATEST_URL}"
else
    curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | bash
fi

# add nginx repo
cat > /etc/yum.repos.d/nginx.repo <<END
[nginx-stable]
name=nginx stable repo
baseurl=https://nginx.org/packages/centos/$REV/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
END

yum -y install epel-release \
            expect \
            nano \
            postgresql \
            postgresql-server \
            rabbitmq-server \
            redis \
            policycoreutils-python*

if [[ $PSQLExitCode -eq $UPDATE_AVAILABLE_CODE ]]; then
    yum -y install postgresql-upgrade
    postgresql-setup --upgrade || true
fi

postgresql-setup initdb	|| true

sed -E -i "s/(host\s+(all|replication)\s+all\s+(127\.0\.0\.1\/32|\:\:1\/128)\s+)(ident|trust|md5)/\1scram-sha-256/" /var/lib/pgsql/data/pg_hba.conf
sed -i "s/^#\?password_encryption = .*/password_encryption = 'scram-sha-256'/" /var/lib/pgsql/data/postgresql.conf

semanage permissive -a httpd_t

package_services="rabbitmq-server postgresql redis"
