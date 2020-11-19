#!/bin/bash

set -e

cat<<EOF

#######################################
#  INSTALL APP 
#######################################

EOF
function make_swap () {
	local DISK_REQUIREMENTS=6144; #6Gb free space
	local MEMORY_REQUIREMENTS=11000; #RAM ~12Gb

	local AVAILABLE_DISK_SPACE=$(df -m /  | tail -1 | awk '{ print $4 }');
	local TOTAL_MEMORY=$(free -m | grep -oP '\d+' | head -n 1);
	local EXIST=$(swapon -s | awk '{ print $1 }' | { grep -x '/app_swapfile' || true; });

	if [[ -z $EXIST ]] && [ ${TOTAL_MEMORY} -lt ${MEMORY_REQUIREMENTS} ] && [ ${AVAILABLE_DISK_SPACE} -gt ${DISK_REQUIREMENTS} ]; then
		dd if=/dev/zero of=/app_swapfile count=6144 bs=1MiB
		chmod 600 /app_swapfile
		mkswap /app_swapfile
		swapon /app_swapfile
		echo "/app_swapfile none swap sw 0 0" >> /etc/fstab
	fi
}

if [ -e /etc/redis.conf ]; then
 sed -i "s/bind .*/bind 127.0.0.1/g" /etc/redis.conf
 sed -r "/^save\s[0-9]+/d" -i /etc/redis.conf
 
 systemctl restart redis
fi

sed "/host\s*all\s*all\s*127\.0\.0\.1\/32\s*ident$/s|ident$|trust|" -i /var/lib/pgsql/data/pg_hba.conf
sed "/host\s*all\s*all\s*::1\/128\s*ident$/s|ident$|trust|" -i /var/lib/pgsql/data/pg_hba.conf

for SVC in $package_services; do
		systemctl start $SVC	
		systemctl enable $SVC
done

if [ "$UPDATE" = "true" ] && [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
        if [ "$INSTALLATION_TYPE" = "COMMUNITY" ]; then
                if rpm -q ${package_sysname}-documentserver-ee; then
                        ${package_manager} -y remove ${package_sysname}-documentserver-ee

                        DOCUMENT_SERVER_INSTALLED="false"
                else
                        ${package_manager} -y update ${package_sysname}-documentserver
                fi
        fi

        if [ "$INSTALLATION_TYPE" = "ENTERPRISE" ]; then
                if rpm -q ${package_sysname}-documentserver; then
                        ${package_manager} -y remove ${package_sysname}-documentserver

                        DOCUMENT_SERVER_INSTALLED="false"
                else
                        ${package_manager} -y update ${package_sysname}-documentserver-ee
                fi
        fi

        if [ "$INSTALLATION_TYPE" = "DEVELOPER" ]; then
               if rpm -q ${package_sysname}-documentserver; then
                        ${package_manager} -y remove ${package_sysname}-documentserver

                        DOCUMENT_SERVER_INSTALLED="false"
                else
                        ${package_manager} -y update ${package_sysname}-documentserver-de
                fi
        fi
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "false" ]; then
	declare -x DS_PORT=8083

	DS_RABBITMQ_HOST=localhost;
	DS_RABBITMQ_USER=guest;
	DS_RABBITMQ_PWD=guest;
	
	DS_REDIS_HOST=localhost;
	
	DS_COMMON_NAME=${DS_COMMON_NAME:-"ds"};

	DS_DB_HOST=localhost;
	DS_DB_NAME=$DS_COMMON_NAME;
	DS_DB_USER=$DS_COMMON_NAME;
	DS_DB_PWD=$DS_COMMON_NAME;
	
	declare -x JWT_ENABLED=true;
	declare -x JWT_SECRET="$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)";
	declare -x JWT_HEADER="AuthorizationJwt";
		
	if ! su - postgres -s /bin/bash -c "psql -lqt" | cut -d \| -f 1 | grep -q ${DS_DB_NAME}; then
		su - postgres -s /bin/bash -c "psql -c \"CREATE DATABASE ${DS_DB_NAME};\""
		su - postgres -s /bin/bash -c "psql -c \"CREATE USER ${DS_DB_USER} WITH password '${DS_DB_PWD}';\""
		su - postgres -s /bin/bash -c "psql -c \"GRANT ALL privileges ON DATABASE ${DS_DB_NAME} TO ${DS_DB_USER};\""
	fi
	
	if [ "$INSTALLATION_TYPE" = "COMMUNITY" ]; then	
		${package_manager} -y install ${package_sysname}-documentserver
	elif [ "$INSTALLATION_TYPE" = "DEVELOPER" ]; then
		${package_manager} -y install ${package_sysname}-documentserver-de
	else
		${package_manager} -y install ${package_sysname}-documentserver-ee
	fi

	systemctl restart supervisord
	
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
	
	if { "${INSTALLATION_TYPE}" == "ENTERPRISE" } {
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
	systemctl enable supervisord
	systemctl enable nginx

	DOCUMENT_SERVER_INSTALLED="true";
fi
NGINX_ROOT_DIR="/etc/nginx"

NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-$(grep processor /proc/cpuinfo | wc -l)};
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$(ulimit -n)};

sed 's/^worker_processes.*/'"worker_processes ${NGINX_WORKER_PROCESSES};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf
sed 's/worker_connections.*/'"worker_connections ${NGINX_WORKER_CONNECTIONS};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf

make_swap

if rpm -q "firewalld"; then
	firewall-cmd --permanent --zone=public --add-service=http
	firewall-cmd --permanent --zone=public --add-service=https
	systemctl restart firewalld.service
fi

systemctl restart nginx

echo ""
echo "$RES_INSTALL_SUCCESS"
echo "$RES_PROPOSAL"
echo "$RES_QUESTIONS"
echo ""