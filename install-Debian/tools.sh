#!/bin/bash

set -e

vercomp () {
    if [[ $1 == $2 ]]
    then
        echo 0
		return
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            echo 1
			return			
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            echo 2			
			return
        fi
    done
    echo 0
}

command_exists () {
	type "$1" &> /dev/null;
}

ARCH="$(dpkg --print-architecture)"
if [ "$ARCH" != "amd64" ]; then
    echo "Onlyoffice Docs doesn't support architecture '$ARCH'"
    exit;
fi

REV=`cat /etc/debian_version`
DIST='Debian'
if [ -f /etc/lsb-release ] ; then
        DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
        REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
        DISTRIB_CODENAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
        DISTRIB_RELEASE=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
elif [ -f /etc/lsb_release ] || [ -f /usr/bin/lsb_release ] ; then
        DIST=`lsb_release -a 2>&1 | grep 'Distributor ID:' | awk -F ":" '{print $2 }'`
        REV=`lsb_release -a 2>&1 | grep 'Release:' | awk -F ":" '{print $2 }'`
        DISTRIB_CODENAME=`lsb_release -a 2>&1 | grep 'Codename:' | awk -F ":" '{print $2 }'`
        DISTRIB_RELEASE=`lsb_release -a 2>&1 | grep 'Release:' | awk -F ":" '{print $2 }'`
elif [ -f /etc/os-release ] ; then
        DISTRIB_CODENAME=$(grep "VERSION=" /etc/os-release |awk -F= {' print $2'}|sed s/\"//g |sed s/[0-9]//g | sed s/\)$//g |sed s/\(//g | tr -d '[:space:]')
        DISTRIB_RELEASE=$(grep "VERSION_ID=" /etc/os-release |awk -F= {' print $2'}|sed s/\"//g |sed s/[0-9]//g | sed s/\)$//g |sed s/\(//g | tr -d '[:space:]')
fi

DIST=`echo "$DIST" | tr '[:upper:]' '[:lower:]' | xargs`;
DISTRIB_CODENAME=`echo "$DISTRIB_CODENAME" | tr '[:upper:]' '[:lower:]' | xargs`;
