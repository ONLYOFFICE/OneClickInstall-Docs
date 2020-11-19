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


REV=$(cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//);
REV_PARTS=(${REV//\./ });
REV=${REV_PARTS[0]};

if ! [[ "$REV" =~ ^[0-9]+$ ]]; then
	REV=7;
fi

# add epel repo
rpm -ivh https://dl.fedoraproject.org/pub/epel/epel-release-latest-$REV.noarch.rpm || true
rpm -ivh https://rpms.remirepo.net/enterprise/remi-release-$REV.rpm || true

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

curl -o cs.key "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x8320CA65CB2DE8E5"
echo "" >> cs.key
rpm --import cs.key || true
rm cs.key

if [ "$REV" = "8" ]; then

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

# add nodejs repo
curl -sL https://rpm.nodesource.com/setup_12.x | sudo bash - || true

yum -y install yum-plugin-versionlock
yum versionlock clear

yum -y install epel-release \
			python36 \
			expect \
			nano \
			htop \
			supervisor \
			postgresql \
			postgresql-server \
			rabbitmq-server \
			redis --enablerepo=remi \
			java-1.8.0-openjdk-headless \
			jq \
			redhat-rpm-config \
            ruby-devel \
			gcc \
			make \
            snapd

systemctl enable --now snapd.socket
ln -fs /var/lib/snapd/snap /snap 
systemctl start --now snapd.socket
snap wait system seed
snap install --classic certbot


if ! command -v god &> /dev/null; then
	gem install --bindir /usr/bin god
fi

yum localinstall -y --nogpgcheck https://download1.rpmfusion.org/free/el/rpmfusion-free-release-$REV.noarch.rpm
yum localinstall -y --nogpgcheck http://rpmfind.net/linux/epel/7/x86_64/Packages/s/SDL2-2.0.10-1.el7.x86_64.rpm

if rpm -q ffmpeg2; then
	yum -y remove ffmpeg2	
fi

yum -y install ffmpeg ffmpeg-devel
			
curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py || true
rm get-pip.py
			
postgresql-setup initdb	|| true

semanage permissive -a httpd_t

package_services="rabbitmq-server postgresql redis supervisord"