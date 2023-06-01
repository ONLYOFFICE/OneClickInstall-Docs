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

DIST=$(rpm -q --whatprovides redhat-release || rpm -q --whatprovides centos-release);
DIST=$(echo $DIST | sed -n '/-.*/s///p');
REV=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//);
REV_PARTS=(${REV//\./ });
REV=${REV_PARTS[0]};

if ! [[ "$REV" =~ ^[0-9]+$ ]]; then
	REV=7;
fi

MONOREV=$REV

{ yum check-update postgresql; PSQLExitCode=$?; } || true 
{ yum check-update $DIST*-release; exitCode=$?; } || true #Checking for distribution update

UPDATE_AVAILABLE_CODE=100
if [[ $exitCode -eq $UPDATE_AVAILABLE_CODE ]]; then
	res_unsupported_version
	echo $RES_UNSPPORTED_VERSION
	echo $RES_SELECT_INSTALLATION
	echo $RES_ERROR_REMINDER
	echo $RES_QUESTIONS
	read_unsupported_installation
fi

#Add repositories: EPEL, REMI
rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-$REV.noarch.rpm || true
rpm -ivh https://rpms.remirepo.net/enterprise/remi-release-$REV.rpm || true

if [ "$REV" = "9" ]; then
	MONOREV="8";
	yum localinstall -y --nogpgcheck https://vault.centos.org/centos/8/AppStream/x86_64/os/Packages/xorg-x11-font-utils-7.5-41.el8.x86_64.rpm
elif [ "$REV" = "7" ] && [ "$DIST" = "redhat" ]; then
	# add centos repo
cat > /etc/yum.repos.d/centos.repo <<END
[nginx-stable]
name=CentOS \$releasever – Base
baseurl=http://mirror.centos.org/centos/$REV/os/\$basearch/
gpgcheck=0
enabled=1
END
fi

#add rabbitmq & erlang repo
curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | os=centos dist=$MONOREV bash
curl -s https://packagecloud.io/install/repositories/rabbitmq/erlang/script.rpm.sh | os=centos dist=$MONOREV bash

if rpm -q rabbitmq-server; then
	if [ "$(repoquery --installed rabbitmq-server --qf '%{ui_from_repo}' | sed 's/@//')" != "$(repoquery rabbitmq-server --qf='%{ui_from_repo}')" ]; then
		res_rabbitmq_update
		echo $RES_RABBITMQ_VERSION
		echo $RES_RABBITMQ_REMINDER
		echo $RES_RABBITMQ_INSTALLATION
		read_rabbitmq_update
	fi
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
			redis --enablerepo=remi \
			policycoreutils-python*
	
if [[ $PSQLExitCode -eq $UPDATE_AVAILABLE_CODE ]]; then
	yum -y install postgresql-upgrade
	postgresql-setup --upgrade || true
fi

postgresql-setup initdb	|| true

semanage permissive -a httpd_t

package_services="rabbitmq-server postgresql redis"
