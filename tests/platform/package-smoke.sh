#!/usr/bin/env bash
set -euo pipefail

# This installs the package names used by the primary distro mappings. Full
# systemd and HA behavior is tested separately, but a renamed, retired, or
# unavailable package must fail this matrix.
# shellcheck disable=SC1091
. /etc/os-release

managed_python_requirements=(
    'PyMySQL==1.1.2'
    'python-dotenv==1.0.1'
    'redis==5.0.7'
    'setuptools==75.9.1'
    'psutil==7.0.0'
    'command_runner==1.7.6'
)

check_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        printf 'Expected platform command is missing: %s\n' "${command_name}" >&2
        exit 1
    fi
}

check_unit() {
    local unit_name="$1"

    if [ ! -f "/usr/lib/systemd/system/${unit_name}" ] && \
        [ ! -f "/lib/systemd/system/${unit_name}" ]; then
        printf 'Expected systemd unit is missing: %s\n' "${unit_name}" >&2
        exit 1
    fi
}

check_any_path() {
    local path_name

    for path_name in "$@"; do
        if [ -e "${path_name}" ]; then
            return 0
        fi
    done

    printf 'None of the expected platform paths exist: %s\n' "$*" >&2
    exit 1
}

check_unit_or_init_script() {
    local unit_name="$1"
    local service_name="${unit_name%.service}"

    if [ -f "/usr/lib/systemd/system/${unit_name}" ] || \
        [ -f "/lib/systemd/system/${unit_name}" ] || \
        [ -f "/run/systemd/generator/${unit_name}" ] || \
        [ -f "/run/systemd/generator.late/${unit_name}" ] || \
        [ -f "/etc/init.d/${service_name}" ]; then
        return 0
    fi

    printf 'Expected systemd unit or init script is missing: %s\n' \
        "${unit_name}" >&2
    exit 1
}

get_mariadb_series() {
    local mariadb_client
    local version_output

    mariadb_client="$(command -v mariadb 2>/dev/null || command -v mysql 2>/dev/null || true)"
    if [ -z "${mariadb_client}" ]; then
        printf 'MariaDB client command is missing.\n' >&2
        return 1
    fi

    version_output="$(${mariadb_client} --version)"
    # MariaDB 10.x commonly reports "Distrib 10.11" while newer clients
    # report "mariadb from 11.8". Accept both formats.
    printf '%s\n' "${version_output}" |
        sed -nE 's/.*(Distrib|from)[[:space:]]+([0-9]+\.[0-9]+).*/\2/p' |
        head -n 1
}

dnf_retry() {
    local max_attempts="${DNF_RETRY_ATTEMPTS:-4}"
    local retry_delay="${DNF_RETRY_DELAY_SECONDS:-5}"
    local attempt

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        if dnf --setopt=retries=10 --setopt=timeout=30 "$@"; then
            return 0
        fi

        if ((attempt == max_attempts)); then
            printf 'DNF command failed after %s attempts: dnf %s\n' \
                "${max_attempts}" "$*" >&2
            return 1
        fi

        printf 'DNF command failed (attempt %s/%s); refreshing metadata and retrying in %ss.\n' \
            "${attempt}" "${max_attempts}" "${retry_delay}" >&2
        dnf clean expire-cache >/dev/null 2>&1 || true
        sleep "${retry_delay}"
    done
}

configure_ondrej_php_repository() {
    local key_url='https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xB8DC7E53946656EFBCE4C1DD71DAEAAB4AD4CAB6&options=mr'
    local keyring=/etc/apt/keyrings/ondrej-php.asc
    local expected_fingerprint=B8DC7E53946656EFBCE4C1DD71DAEAAB4AD4CAB6
    local actual_fingerprint

    apt-get install -y --no-install-recommends ca-certificates curl gnupg
    install -d -m 0755 /etc/apt/keyrings
    rm -f /etc/apt/sources.list.d/*ondrej*php* \
        /etc/apt/trusted.gpg.d/ondrej-ubuntu-php.gpg
    curl --fail --silent --show-error --location --retry 3 \
        "${key_url}" -o "${keyring}"
    actual_fingerprint="$(gpg --batch --show-keys --with-colons "${keyring}" |
        awk -F: '$1 == "fpr" { print toupper($10); exit }')"
    if [ "${actual_fingerprint}" != "${expected_fingerprint}" ]; then
        printf 'Ondrej PHP key fingerprint mismatch: expected %s, found %s.\n' \
            "${expected_fingerprint}" "${actual_fingerprint:-unavailable}" >&2
        exit 1
    fi
    cat >/etc/apt/sources.list.d/ondrej-php.sources <<EOF
Types: deb
URIs: https://ppa.launchpadcontent.net/ondrej/php/ubuntu
Suites: ${VERSION_CODENAME}
Components: main
Signed-By: ${keyring}
EOF
    apt-get update -q
}

validate_php_stream() {
    case "$1" in
        8.2|8.3|8.4|8.5) ;;
        *)
            printf 'Unsupported explicit PHP stream: %s\n' "$1" >&2
            exit 1
            ;;
    esac
}

case "${ID}" in
    ubuntu)
        case "${VERSION_ID}" in
            22.04|24.04|26.04) ;;
            *)
                printf 'Unsupported Ubuntu release for the primary package smoke test: %s\n' \
                    "${VERSION_ID}" >&2
                exit 1
                ;;
        esac

        export DEBIAN_FRONTEND=noninteractive
        apt-get update -q
        php_stream="${LIBRENMS_PHP_STREAM:-}"
        if [ -n "${php_stream}" ]; then
            validate_php_stream "${php_stream}"
        fi

        if [ "${VERSION_ID}" = "22.04" ]; then
            php_expected_stream="${php_stream:-8.3}"
            configure_ondrej_php_repository
        elif [ -n "${php_stream}" ]; then
            php_expected_stream="${php_stream}"
            configure_ondrej_php_repository
        else
            php_expected_stream=""
        fi

        if [ -n "${php_expected_stream}" ]; then
            php_package_prefix="php${php_expected_stream}-"
            php_packages=(
                "${php_package_prefix}cli" "${php_package_prefix}common"
                "${php_package_prefix}curl" "${php_package_prefix}fpm"
                "${php_package_prefix}gd" "${php_package_prefix}gmp"
                "${php_package_prefix}mbstring" "${php_package_prefix}mysql"
                "${php_package_prefix}snmp" "${php_package_prefix}xml"
                "${php_package_prefix}zip"
            )
        else
            php_packages=(
                php-cli php-curl php-fpm php-gd php-gmp php-json php-mbstring
                php-mysql php-snmp php-xml php-zip
            )
        fi
        apt-get install -y --no-install-recommends \
            acl bash-completion ca-certificates chrony curl firewalld fping \
            galera-4 git glusterfs-client glusterfs-server graphviz haproxy \
            imagemagick keepalived lsb-release mariadb-client mariadb-server \
            mtr-tiny nfs-common nginx-full nmap "${php_packages[@]}" \
            python3 python3-pip python3-systemd python3-venv \
            redis-sentinel redis-server rrdcached \
            rrdtool rsync snmp snmpd traceroute unzip util-linux wget whois

        if [ -n "${php_expected_stream}" ]; then
            update-alternatives --set php "/usr/bin/php${php_expected_stream}" >/dev/null
        fi
        php_runtime_stream="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')"
        validate_php_stream "${php_runtime_stream}"
        if [ -n "${php_expected_stream}" ] &&
            [ "${php_runtime_stream}" != "${php_expected_stream}" ]; then
            printf 'Expected PHP %s, found %s.\n' \
                "${php_expected_stream}" "${php_runtime_stream}" >&2
            exit 1
        fi

        python3 -m venv --system-site-packages /tmp/librenms-platform-python
        /tmp/librenms-platform-python/bin/python -m pip install \
            --disable-pip-version-check "${managed_python_requirements[@]}"
        /tmp/librenms-platform-python/bin/python -c \
            'import command_runner, dotenv, psutil, pymysql, redis, setuptools, systemd'

        for command_name in \
            galera_new_cluster galera_recovery wsrep_sst_rsync mariadb php nginx rrdtool rrdcached redis-server redis-cli \
            haproxy keepalived snmpd; do
            check_command "${command_name}"
        done
        mariadb_series="$(get_mariadb_series)"
        case "${VERSION_ID}" in
            22.04) expected_mariadb_series=10.6 ;;
            24.04) expected_mariadb_series=10.11 ;;
            26.04) expected_mariadb_series=11.8 ;;
        esac
        if [ "${mariadb_series}" != "${expected_mariadb_series}" ]; then
            printf 'Ubuntu %s expects MariaDB %s, found %s.\n' \
                "${VERSION_ID}" "${expected_mariadb_series}" "${mariadb_series:-unavailable}" >&2
            exit 1
        fi
        check_any_path /usr/sbin/php-fpm* /usr/bin/php-fpm*
        for unit_name in \
            mariadb.service nginx.service \
            redis-server.service redis-sentinel.service haproxy.service \
            keepalived.service; do
            check_unit "${unit_name}"
        done
        check_unit_or_init_script rrdcached.service
        check_any_path /etc/mysql/mariadb.conf.d /etc/mysql/conf.d
        check_any_path /etc/redis/redis.conf
        check_any_path /etc/redis/sentinel.conf
        ;;
    rocky|almalinux|rhel)
        major="${VERSION_ID%%.*}"

        case "${major}" in
            8) minimum_minor=10 ;;
            9) minimum_minor=4 ;;
            10) minimum_minor=0 ;;
            *)
                printf 'Unsupported EL major release: %s\n' "${VERSION_ID}" >&2
                exit 1
                ;;
        esac

        minor="${VERSION_ID#*.}"
        minor="${minor%%.*}"
        if ! [[ "${minor}" =~ ^[0-9]+$ ]] || ((10#${minor} < minimum_minor)); then
            printf 'EL %s requires version %s.%s or newer; found %s.\n' \
                "${major}" "${major}" "${minimum_minor}" "${VERSION_ID}" >&2
            exit 1
        fi

        dnf_retry -y install dnf-plugins-core

        if [ "${ID}" = "rhel" ]; then
            # Public CI cannot authenticate to Red Hat subscription services.
            # A subscribed RHEL target must already expose CodeReady Builder;
            # install EPEL from its signed upstream release package just as
            # the production role does.
            dnf_retry -y install \
                "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${major}.noarch.rpm"
            if ! dnf repolist --enabled | grep -Eqi 'codeready-builder|crb'; then
                printf 'RHEL %s requires an enabled CodeReady Builder repository.\n' \
                    "${major}" >&2
                exit 1
            fi
        else
            if [ "${major}" = "8" ]; then
                dnf_retry config-manager --set-enabled powertools
            else
                dnf_retry config-manager --set-enabled crb
            fi
            dnf_retry -y install epel-release
        fi

        if [ "${major}" -lt 10 ]; then
            dnf_retry -y module reset php mariadb
            dnf_retry -y module enable php:8.2 mariadb:10.11
            cache_packages=(redis python3-redis)
        else
            cache_packages=(valkey)
        fi

        if [ "${major}" -ge 9 ]; then
            curl_package="curl-minimal"
        else
            curl_package="curl"
        fi

        dnf_retry -y --setopt=install_weak_deps=False install \
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

        for command_name in \
            galera_new_cluster galera_recovery wsrep_sst_rsync mariadb php php-fpm nginx rrdtool rrdcached haproxy keepalived \
            snmpd; do
            check_command "${command_name}"
        done
        mariadb_series="$(get_mariadb_series)"
        if [ "${mariadb_series}" != "10.11" ]; then
            printf 'EL %s expects MariaDB 10.11, found %s.\n' \
                "${VERSION_ID}" "${mariadb_series:-unavailable}" >&2
            exit 1
        fi
        for unit_name in \
            mariadb.service nginx.service php-fpm.service rrdcached.service \
            haproxy.service keepalived.service; do
            check_unit "${unit_name}"
        done
        check_any_path /etc/my.cnf.d /etc/my.cnf
        check_any_path /etc/php.ini

        if [ "${major}" = "8" ]; then
            dnf_retry -y install python3.11 python3.11-pip
            test -x /usr/libexec/platform-python
            /usr/libexec/platform-python -c 'import dnf, pymysql'
            python3.11 -m venv --system-site-packages \
                /tmp/librenms-platform-python
        else
            python3 -m venv --system-site-packages \
                /tmp/librenms-platform-python
        fi

        /tmp/librenms-platform-python/bin/python -m pip install \
            --disable-pip-version-check "${managed_python_requirements[@]}"
        /tmp/librenms-platform-python/bin/python -c \
            'import command_runner, dotenv, psutil, pymysql, redis, setuptools'

        if [ "${major}" -ge 10 ]; then
            command -v valkey-server >/dev/null
            command -v valkey-cli >/dev/null
            command -v valkey-sentinel >/dev/null
            getent passwd valkey >/dev/null
            getent group valkey >/dev/null
            test -f /etc/valkey/valkey.conf
            test -f /etc/valkey/sentinel.conf
            test -f /usr/lib/systemd/system/valkey.service
            check_unit valkey.service
            # RHEL 10 standardizes on Valkey, but the package does not make a
            # Sentinel unit name part of this acceptance contract. The Ansible
            # role manages a project unit when valkey-sentinel.service is not
            # shipped by the installed package.
            if [ -f /usr/lib/systemd/system/valkey-sentinel.service ] || \
                [ -f /lib/systemd/system/valkey-sentinel.service ]; then
                check_unit valkey-sentinel.service
            fi
            grep -Fxq 'User=valkey' /usr/lib/systemd/system/valkey.service
            grep -Fxq 'Group=valkey' /usr/lib/systemd/system/valkey.service
            grep -Fxq 'RuntimeDirectory=valkey' \
                /usr/lib/systemd/system/valkey.service
        else
            command -v redis-server >/dev/null
            command -v redis-cli >/dev/null
            getent passwd redis >/dev/null
            getent group redis >/dev/null
            check_unit redis.service
            check_unit redis-sentinel.service

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
