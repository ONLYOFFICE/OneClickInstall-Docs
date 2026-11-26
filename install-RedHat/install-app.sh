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
#  INSTALL APP
#######################################

EOF

ds_pkg_name="${package_sysname}-documentserver"
case "${INSTALLATION_TYPE}" in
    "DEVELOPER") ds_pkg_name+="-de" ;;
    "ENTERPRISE") ds_pkg_name+="-ee" ;;
esac
ds_pkg_source="${DS_PACKAGE_PATH:-$ds_pkg_name}"

DS_COMMON_NAME=${DS_COMMON_NAME:-ds}

# Runs the SQL given on stdin as the postgres superuser, so no password shows up in a command line
run_postgres_sql () {
    su - postgres -s /bin/bash -c "psql -q -v ON_ERROR_STOP=1"
}

# Prints the database password of a Docs installed on this host before, if its config is still there
get_saved_db_password () {
    local CONFIG_FILE SAVED_PASSWORD
    for CONFIG_FILE in "/etc/${package_sysname}/documentserver/local.json" "/etc/${package_sysname}/documentserver/local.json.rpmsave"; do
        [ -f "${CONFIG_FILE}" ] || continue
        SAVED_PASSWORD=$(jq -r '.services.CoAuthoring.sql.dbPass // empty' "${CONFIG_FILE}" 2>/dev/null) || true
        if [ -n "${SAVED_PASSWORD}" ]; then
            printf '%s\n' "${SAVED_PASSWORD}"
            return 0
        fi
    done
}

setup_postgres_db () {
    local SQL_PASSWORD
    DS_DB_NAME=${DS_DB_NAME:-$DS_COMMON_NAME}
    DS_DB_USER=${DS_DB_USER:-$DS_COMMON_NAME}

    if ! su - postgres -s /bin/bash -c "psql -lqt" | cut -d \| -f 1 | grep -q "${DS_DB_NAME}"; then
        # A new Docs database gets its own password instead of the well-known default
        DS_DB_PWD=${DS_DB_PWD:-$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 24)}
        SQL_PASSWORD=${DS_DB_PWD//"'"/"''"}
        printf "CREATE USER %s WITH PASSWORD '%s';\nCREATE DATABASE %s OWNER %s;\n" "${DS_DB_USER}" "${SQL_PASSWORD}" "${DS_DB_NAME}" "${DS_DB_USER}" | run_postgres_sql
    elif [ -z "${DS_DB_PWD}" ]; then
        # A kept database keeps the password of the Docs that used it, so reinstalling or switching the edition does not rotate it
        DS_DB_PWD=$(get_saved_db_password)
        if [ -z "${DS_DB_PWD}" ] || ! PGPASSWORD="${DS_DB_PWD}" psql -h localhost -U "${DS_DB_USER}" -d "${DS_DB_NAME}" -w -c ';' >/dev/null 2>&1; then
            # Nothing else knows the password of a kept database without a working config, so the Docs installed now sets a new one
            DS_DB_PWD=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 24)
            printf "ALTER USER %s WITH PASSWORD '%s';\n" "${DS_DB_USER}" "${DS_DB_PWD}" | run_postgres_sql
        fi
    fi
}

# Packages before 10.0.3 needed httpd_t to be permissive; later ones label their ports and nginx logs, and those before Bug 85420 miss only the boolean that lets nginx connect to them
configure_selinux () {
    local DS_PACKAGE DS_PACKAGE_SCRIPTS
    command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled || return 0
    DS_PACKAGE=$(rpm -qa --qf '%{NAME}\n' | grep -E "^${package_sysname}-documentserver(-ee|-de)?$" | head -n 1)
    [ -n "${DS_PACKAGE}" ] || return 0
    DS_PACKAGE_SCRIPTS=$(rpm -q --scripts "${DS_PACKAGE}")
    if ! grep -q httpd_log_t <<< "${DS_PACKAGE_SCRIPTS}"; then
        semanage permissive -l | grep -qw httpd_t || semanage permissive -a httpd_t
    elif ! grep -q httpd_graceful_shutdown <<< "${DS_PACKAGE_SCRIPTS}" && ! getsebool httpd_graceful_shutdown 2>/dev/null | grep -q -- '--> on$'; then
        # The state file of the package records the boolean, so a package that knows it turns it off on uninstall
        if setsebool -P httpd_graceful_shutdown on; then
            echo "boolean httpd_graceful_shutdown" >> "/var/lib/${package_sysname}/documentserver.selinux-labels"
        else
            echo "Warning: could not enable the SELinux boolean httpd_graceful_shutdown, nginx may fail to reach ONLYOFFICE Docs (502)" >&2
        fi
    fi
}

[ "$package_manager" = "dnf" ] && _nobest="--nobest"
if [ "$UPDATE" = "true" ] && [ "$DOCUMENT_SERVER_INSTALLED" = "true" ]; then
    ds_pkg_installed_name=$(rpm -qa --qf '%{NAME}\n' | grep "${package_sysname}-documentserver")
    if [ "${ds_pkg_installed_name}" != "${ds_pkg_name}" ]; then
        ${package_manager} -y remove "${ds_pkg_installed_name}"
        DOCUMENT_SERVER_INSTALLED="false"
    else
        if [ -n "${DS_PACKAGE_PATH}" ]; then
            ${package_manager} -y install "${ds_pkg_source}" ${_nobest}
        else
            ${package_manager} -y update "${ds_pkg_installed_name}" ${_nobest} # --nobest for rhel 8 compatibility
        fi
        configure_selinux
    fi
fi

if [ "$DOCUMENT_SERVER_INSTALLED" = "false" ]; then
    DS_PORT=${DS_PORT:-80}
    declare -x LISTEN_ADDRESS="0.0.0.0:${DS_PORT}"
    declare -x JWT_ENABLED=${JWT_ENABLED:-true}
    declare -x JWT_SECRET=${JWT_SECRET:-$(cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)}
    declare -x JWT_HEADER=${JWT_HEADER:-AuthorizationJwt}
    [ -n "${WOPI_ENABLED}" ] && declare -x WOPI_ENABLED

    if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
        DS_DB_HOST=${DS_DB_HOST:-localhost}
        setup_postgres_db
    fi
    
    ${package_manager} -y install "${ds_pkg_source}" ${_nobest}
    configure_selinux

    if [ "${DS_PORT}" = "80" ]; then
        [ -e /etc/nginx/nginx.conf ] && sed -i "s/ default_server//" /etc/nginx/nginx.conf && \
            echo "Note: removed default_server from /etc/nginx/nginx.conf to avoid conflict with ${ds_pkg_name}."
        [ -e /etc/nginx/conf.d/default.conf ] && \
            mv -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled && \
            echo "Note: nginx default site disabled to avoid conflict with ${ds_pkg_name}."
        systemctl stop nginx || true
    fi

    ds_configure_args=()
    if [ "$INSTALLATION_TYPE" != "COMMUNITY" ]; then
        ds_configure_args=(
            --redishost "${DS_REDIS_HOST:-localhost}"
            --amqphost "${DS_RABBITMQ_HOST:-localhost}"
            --amqpuser "${DS_RABBITMQ_USER:-guest}"
            --databasehost "${DS_DB_HOST:-localhost}"
            --databasename "$DS_DB_NAME"
            --databaseuser "$DS_DB_USER"
        )
    fi
    # documentserver-configure takes the passwords from DB_PWD and AMQP_SERVER_PWD, which keeps them off the command line
    (
        [ "$INSTALLATION_TYPE" = "COMMUNITY" ] || export DB_PWD="${DS_DB_PWD}" AMQP_SERVER_PWD="${DS_RABBITMQ_PWD:-guest}"
        documentserver-configure "${ds_configure_args[@]}"
    )
fi

# Only the port of a new installation is opened: the package serves plain HTTP on it, and an update keeps the firewall as it is
if [ "$DOCUMENT_SERVER_INSTALLED" = "false" ] && systemctl is-active --quiet firewalld && \
    ! firewall-cmd --permanent --zone=public --query-port="${DS_PORT}/tcp" >/dev/null 2>&1; then
    firewall-cmd --permanent --zone=public --add-port="${DS_PORT}/tcp"
    firewall-cmd --reload
fi

if [ -n "${DS_LICENSE_PATH:-}" ]; then
    install -m 644 "$DS_LICENSE_PATH" "/var/www/${package_sysname}/Data/license.lic"
    chown --reference="/var/www/${package_sysname}/Data" "/var/www/${package_sysname}/Data/license.lic"
    chmod 640 "/var/www/${package_sysname}/Data/license.lic"
    echo "[OK] License installed at /var/www/${package_sysname}/Data/license.lic"
fi

echo ""
echo "$RES_INSTALL_SUCCESS"
echo "$RES_QUESTIONS"
echo ""
