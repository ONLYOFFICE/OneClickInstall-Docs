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

read_unsupported_installation () {
	read -p "$RES_CHOICE_INSTALLATION " CHOICE_INSTALLATION
	case "$CHOICE_INSTALLATION" in
		y|Y ) yum -y install $DIST*-release
		;;

		n|N ) exit 0;
		;;

		* ) echo $RES_CHOICE;
			read_unsupported_installation
		;;
	esac
}

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
#rpm -ivh https://rpms.remirepo.net/enterprise/remi-release-$REV.rpm || true

if [[ $REV = "9" ]]; then
	#Install packages from repo for Centos 8
	REV="8"
	curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8 "https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8"
	cat << EOF > /etc/yum.repos.d/epel-centos-8.repo
[epel-centos-8]
name=Extra Packages for Enterprise Linux 8 - \$basearch
baseurl=https://dl.fedoraproject.org/pub/epel/8/Everything/\$basearch/
enabled=1
gpgcheck=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8
EOF
fi

if [ "$REV" = "8" ]; then
rabbitmq_version="-3.8.12"

cat > /etc/yum.repos.d/rabbitmq-server.repo <<END
[rabbitmq-server]
name=rabbitmq-server
baseurl=https://packagecloud.io/rabbitmq/rabbitmq-server/el/7/\$basearch
repo_gpgcheck=1
gpgcheck=0
enabled=1
gpgkey=https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
sslverify=0
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
END

fi

# add nginx repo
#cat > /etc/yum.repos.d/nginx.repo <<END
#[nginx-stable]
#name=nginx stable repo
#baseurl=https://nginx.org/packages/centos/$REV/\$basearch/
#gpgcheck=1
#enabled=1
#gpgkey=https://nginx.org/keys/nginx_signing.key
#module_hotfixes=true
#END

yum -y install policycoreutils-python

yum -y install epel-release \
			expect \
			nano \
			postgresql \
			postgresql-server \
			rabbitmq-server$rabbitmq_version \
			redis
	
if [[ $PSQLExitCode -eq $UPDATE_AVAILABLE_CODE ]]; then
	yum -y install postgresql-upgrade
	postgresql-setup --upgrade || true
fi

yum -y install supervisor || true
if [[ -z $(rpm -qa supervisor) ]]; then
	yum localinstall -y https://download-ib01.fedoraproject.org/pub/fedora/linux/releases/34/Everything/x86_64/os/Packages/s/supervisor-4.2.1-2.fc34.noarch.rpm
fi

if [ "$REV" = "7" ]; then
	if ! rpm -q msttcore-fonts-installer; then
		yum install -y xorg-x11-font-utils \
					fontconfig \
					cabextract

	curl -O -L https://sourceforge.net/projects/mscorefonts2/files/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm

	rpm -ivh msttcore-fonts-installer-2.6-1.noarch.rpm
	rm msttcore-fonts-installer-2.6-1.noarch.rpm
	fi
fi

postgresql-setup initdb	|| true

semanage permissive -a httpd_t

package_services="rabbitmq-server postgresql redis supervisord"
