#!/bin/bash

set -e

cat<<EOF

#######################################
#  INSTALL APP 
#######################################

EOF

if [ -e /etc/redis.conf ]; then
 sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis.conf
 sed -r "/^save\s[0-9]+/d" -i /etc/redis.conf
 
 systemctl restart redis
fi

for SVC in $package_services; do
		systemctl start $SVC	
		systemctl enable $SVC
done

if [ "$INSTALLATION_TYPE" = "COMMUNITY" ]; then
	ds_pkg_name="${package_sysname}-documentserver";
elif [ "$INSTALLATION_TYPE" = "ENTERPRISE" ]; then
	ds_pkg_name="${package_sysname}-documentserver-ee";
elif [ "$INSTALLATION_TYPE" = "DEVELOPER" ]; then
	ds_pkg_name="${package_sysname}-documentserver-de";
fi

if [ "$UPDATE" = "true" ] && [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
	ds_pkg_installed_name=$(rpm -qa --qf '%{NAME}\n' | grep ${package_sysname}-documentserver);
	if [ ${ds_pkg_installed_name} != ${ds_pkg_name} ]; then
		${package_manager} -y remove ${ds_pkg_installed_name}
		DOCUMENT_SERVER_INSTALLED="false"
	else
		${package_manager} -y update ${ds_pkg_installed_name}
	fi
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "false" ]; then
	declare -x DS_PORT=${DS_PORT:-80}

	DS_RABBITMQ_HOST=localhost;
	DS_RABBITMQ_USER=guest;
	DS_RABBITMQ_PWD=guest;
	
	DS_REDIS_HOST=localhost;
	
	DS_COMMON_NAME=${DS_COMMON_NAME:-"ds"};

	DS_DB_HOST=localhost;
	DS_DB_NAME=$DS_COMMON_NAME;
	DS_DB_USER=$DS_COMMON_NAME;
	DS_DB_PWD=$DS_COMMON_NAME;
	
	declare -x JWT_ENABLED=${JWT_ENABLED:-true};
	declare -x JWT_SECRET=${JWT_SECRET:-$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)};
	declare -x JWT_HEADER=${JWT_HEADER:-AuthorizationJwt};
		
	if ! su - postgres -s /bin/bash -c "psql -lqt" | cut -d \| -f 1 | grep -q ${DS_DB_NAME}; then
		su - postgres -s /bin/bash -c "psql -c \"CREATE USER ${DS_DB_USER} WITH password '${DS_DB_PWD}';\""
		su - postgres -s /bin/bash -c "psql -c \"CREATE DATABASE ${DS_DB_NAME} OWNER ${DS_DB_USER};\""
	fi
	
	${package_manager} -y install ${ds_pkg_name}
	
expect << EOF
	
	set timeout -1
	log_user 1
	
	spawn documentserver-configure.sh
	
	expect "Configuring database access..."
	
	expect -re "Host"
	send "\025$DS_DB_HOST\r"
	
	expect -re "Database name"
	send "\025$DS_DB_NAME\r"
	
	expect -re "User"
	send "\025$DS_DB_USER\r"
	
	expect -re "Password"
	send "\025$DS_DB_PWD\r"
	
	if { "${INSTALLATION_TYPE}" == "ENTERPRISE" || "${INSTALLATION_TYPE}" == "DEVELOPER" } {
		expect "Configuring redis access..."
		send "\025$DS_REDIS_HOST\r"
	}
	
	expect "Configuring AMQP access... "
	expect -re "Host"
	send "\025$DS_RABBITMQ_HOST\r"
	
	expect -re "User"
	send "\025$DS_RABBITMQ_USER\r"
	
	expect -re "Password"
	send "\025$DS_RABBITMQ_PWD\r"
	
	expect eof
	
EOF
	systemctl restart nginx
	systemctl enable nginx

	DOCUMENT_SERVER_INSTALLED="true";
fi

NGINX_ROOT_DIR="/etc/nginx"
NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-$(grep processor /proc/cpuinfo | wc -l)};
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$(ulimit -n)};

sed 's/^worker_processes.*/'"worker_processes ${NGINX_WORKER_PROCESSES};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf
sed 's/worker_connections.*/'"worker_connections ${NGINX_WORKER_CONNECTIONS};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf

if systemctl is-active --quiet firewalld; then
	firewall-cmd --permanent --zone=public --add-service=http
	firewall-cmd --permanent --zone=public --add-service=https
	firewall-cmd --permanent --zone=public --add-port=${DS_PORT:-80}/tcp
	firewall-cmd --reload
fi

systemctl restart nginx

echo ""
echo "$RES_INSTALL_SUCCESS"
echo "$RES_QUESTIONS"
echo ""
