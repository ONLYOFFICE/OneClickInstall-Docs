#!/bin/bash

set -e

cat<<EOF

#######################################
#  INSTALL APP
#######################################

EOF

if [ "$INSTALLATION_TYPE" = "COMMUNITY" ]; then
    ds_pkg_name="${package_sysname}-documentserver"
elif [ "$INSTALLATION_TYPE" = "ENTERPRISE" ]; then
    ds_pkg_name="${package_sysname}-documentserver-ee"
elif [ "$INSTALLATION_TYPE" = "DEVELOPER" ]; then
    ds_pkg_name="${package_sysname}-documentserver-de"
fi

apt-get -y update

if [ "$UPDATE" = "true" ] && [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
    ds_pkg_installed_name=$(dpkg -l | grep ${package_sysname}-documentserver | tail -n1 | awk '{print $2}')

    if [ ${ds_pkg_installed_name} != ${ds_pkg_name} ]; then
        apt-get remove -yq ${ds_pkg_installed_name}
        DOCUMENT_SERVER_INSTALLED="false"
    else
        apt-get install -y --only-upgrade ${ds_pkg_installed_name}
    fi
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "false" ]; then
    DS_PORT=${DS_PORT:-80}

    DS_DB_HOST=localhost
    DS_DB_NAME=$DS_COMMON_NAME
    DS_DB_USER=$DS_COMMON_NAME
    DS_DB_PWD=$DS_COMMON_NAME

    DS_JWT_ENABLED=${DS_JWT_ENABLED:-true}
    DS_JWT_SECRET=${DS_JWT_SECRET:-$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)}
    DS_JWT_HEADER=${DS_JWT_HEADER:-AuthorizationJwt}

    if ! su - postgres -s /bin/bash -c "psql -lqt" | cut -d \| -f 1 | grep -q ${DS_DB_NAME}; then
        su - postgres -s /bin/bash -c "psql -c \"CREATE USER ${DS_DB_USER} WITH password '${DS_DB_PWD}';\""
        su - postgres -s /bin/bash -c "psql -c \"CREATE DATABASE ${DS_DB_NAME} OWNER ${DS_DB_USER};\""
    fi

    echo ${package_sysname}-documentserver $DS_COMMON_NAME/ds-port select $DS_PORT | sudo debconf-set-selections
    echo ${package_sysname}-documentserver $DS_COMMON_NAME/db-pwd select $DS_DB_PWD | sudo debconf-set-selections
    echo ${package_sysname}-documentserver $DS_COMMON_NAME/db-user $DS_DB_USER | sudo debconf-set-selections
    echo ${package_sysname}-documentserver $DS_COMMON_NAME/db-name $DS_DB_NAME | sudo debconf-set-selections
    echo ${package_sysname}-documentserver-de $DS_COMMON_NAME/jwt-enabled select ${DS_JWT_ENABLED} | sudo debconf-set-selections
    echo ${package_sysname}-documentserver-de $DS_COMMON_NAME/jwt-secret select ${DS_JWT_SECRET} | sudo debconf-set-selections
    echo ${package_sysname}-documentserver-de $DS_COMMON_NAME/jwt-header select ${DS_JWT_HEADER} | sudo debconf-set-selections
    echo ${package_sysname}-documentserver-ee $DS_COMMON_NAME/jwt-enabled select ${DS_JWT_ENABLED} | sudo debconf-set-selections
    echo ${package_sysname}-documentserver-ee $DS_COMMON_NAME/jwt-secret select ${DS_JWT_SECRET} | sudo debconf-set-selections
    echo ${package_sysname}-documentserver-ee $DS_COMMON_NAME/jwt-header select ${DS_JWT_HEADER} | sudo debconf-set-selections

    apt-get install -yq ${ds_pkg_name}
fi

NGINX_ROOT_DIR="/etc/nginx"
NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-$(grep processor /proc/cpuinfo | wc -l)}
NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-$(ulimit -n)}

sed 's/^worker_processes.*/'"worker_processes ${NGINX_WORKER_PROCESSES};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf
sed 's/worker_connections.*/'"worker_connections ${NGINX_WORKER_CONNECTIONS};"'/' -i ${NGINX_ROOT_DIR}/nginx.conf

if ! id "nginx" &>/dev/null; then
    systemctl stop nginx

    rm -dfr /var/log/nginx/*
    rm -dfr /var/cache/nginx/*
    useradd -s /bin/false nginx

    systemctl start nginx
else
    systemctl reload nginx
fi

echo ""
echo "$RES_INSTALL_SUCCESS"
echo "$RES_QUESTIONS"
echo ""
