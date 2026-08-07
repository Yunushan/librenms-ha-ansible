#!/usr/bin/env bash
set -euo pipefail

# This installs the package names used by the primary distro mappings. Full
# systemd and HA behavior is tested separately, but a renamed, retired, or
# unavailable package must fail this matrix.
# shellcheck disable=SC1091
. /etc/os-release

case "${ID}" in
    ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -q
        apt-get install -y --no-install-recommends \
            acl bash-completion ca-certificates chrony curl firewalld fping \
            git glusterfs-client glusterfs-server graphviz haproxy \
            imagemagick keepalived lsb-release mariadb-client mariadb-server \
            mtr-tiny nfs-common nginx-full nmap php-cli php-curl php-fpm \
            php-gd php-gmp php-json php-mbstring php-mysql php-snmp php-xml \
            php-zip python3 python3-command-runner python3-dotenv python3-pip \
            python3-psutil python3-pymysql python3-redis python3-setuptools \
            python3-systemd python3-venv redis-sentinel redis-server rrdcached \
            rrdtool rsync snmp snmpd traceroute unzip util-linux wget whois

        python3 -m venv --system-site-packages /tmp/librenms-platform-python
        /tmp/librenms-platform-python/bin/python -c \
            'import pymysql, redis, systemd'
        ;;
    rocky|almalinux)
        major="${VERSION_ID%%.*}"
        dnf -y install dnf-plugins-core

        if [ "${major}" = "8" ]; then
            dnf config-manager --set-enabled powertools
        else
            dnf config-manager --set-enabled crb
        fi
        dnf -y install epel-release

        if [ "${major}" -lt 10 ]; then
            dnf -y module reset php mariadb
            dnf -y module enable php:8.2 mariadb:10.11
            cache_packages=(redis python3-redis)
        else
            cache_packages=(valkey)
        fi

        if [ "${major}" -ge 9 ]; then
            curl_package="curl-minimal"
        else
            curl_package="curl"
        fi

        dnf -y --setopt=install_weak_deps=False install \
            acl bash-completion ca-certificates chrony cronie \
            "${curl_package}" firewalld \
            fping git graphviz haproxy ImageMagick iproute keepalived mariadb \
            mariadb-server mariadb-server-galera mtr net-snmp net-snmp-utils \
            nfs-utils nginx nmap php-cli php-common php-curl php-fpm php-gd \
            php-gmp php-mbstring php-mysqlnd php-opcache php-pecl-zip \
            php-process php-snmp php-xml policycoreutils-python-utils python3 \
            python3-pip python3-psutil python3-PyMySQL python3-systemd \
            rrdtool rsync traceroute unzip util-linux whois \
            "${cache_packages[@]}"

        command -v rrdcached >/dev/null
        test -f /usr/lib/systemd/system/rrdcached.service

        if [ "${major}" = "8" ]; then
            dnf -y install python3.11 python3.11-pip
            test -x /usr/libexec/platform-python
            /usr/libexec/platform-python -c 'import dnf, pymysql'
            python3.11 -m venv --system-site-packages \
                /tmp/librenms-platform-python
        else
            python3 -m venv --system-site-packages \
                /tmp/librenms-platform-python
        fi

        /tmp/librenms-platform-python/bin/python -m pip install \
            --disable-pip-version-check PyMySQL==1.1.2 redis==5.0.7
        /tmp/librenms-platform-python/bin/python -c 'import pymysql, redis'

        if [ "${major}" -ge 10 ]; then
            command -v valkey-server >/dev/null
            command -v valkey-cli >/dev/null
            command -v valkey-sentinel >/dev/null
            getent passwd valkey >/dev/null
            getent group valkey >/dev/null
            test -f /etc/valkey/valkey.conf
            test -f /etc/valkey/sentinel.conf
            test -f /usr/lib/systemd/system/valkey.service
            test -f /usr/lib/systemd/system/valkey-sentinel.service
            grep -Fxq 'User=valkey' /usr/lib/systemd/system/valkey.service
            grep -Fxq 'Group=valkey' /usr/lib/systemd/system/valkey.service
            grep -Fxq 'RuntimeDirectory=valkey' \
                /usr/lib/systemd/system/valkey.service
        else
            command -v redis-server >/dev/null
            command -v redis-cli >/dev/null
            getent passwd redis >/dev/null
            getent group redis >/dev/null
            test -f /usr/lib/systemd/system/redis.service
            test -f /usr/lib/systemd/system/redis-sentinel.service

            if [ "${major}" = "8" ]; then
                test -f /etc/redis.conf
                test -f /etc/redis-sentinel.conf
            else
                test -f /etc/redis/redis.conf
                test -f /etc/redis/sentinel.conf
            fi
        fi
        ;;
    *)
        printf 'Unsupported package-smoke image: %s\n' "${PRETTY_NAME:-${ID}}" >&2
        exit 1
        ;;
esac

printf 'Platform package smoke test passed for %s.\n' "${PRETTY_NAME}"
